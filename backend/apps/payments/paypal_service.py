import paypalrestsdk
from django.conf import settings
from django.utils import timezone
from datetime import timedelta
from .models import SubscriptionPlan, PaymentTransaction
from apps.accounts.models import User

# Configure PayPal
paypalrestsdk.configure({
    "mode": settings.PAYPAL_MODE,  # sandbox or live
    "client_id": settings.PAYPAL_CLIENT_ID,
    "client_secret": settings.PAYPAL_CLIENT_SECRET
})


class PayPalService:
    """Service class for handling PayPal operations"""
    
    @staticmethod
    def get_or_create_customer(user: User):
        """Get existing customer or create new one"""
        if user.paypal_customer_id:
            try:
                # PayPal doesn't have a direct customer retrieval by ID in the same way
                # We'll just return the ID and verify existence if needed
                return user.paypal_customer_id
            except:
                return PayPalService.create_customer(user)
        else:
            return PayPalService.create_customer(user)
    
    @staticmethod
    def create_customer(user: User):
        """Create a reference for PayPal customer (store in our system)"""
        try:
            # For PayPal, we don't always need to create a customer upfront
            # We can just generate an internal customer ID reference
            customer_id = f"user_{user.id}_{user.username}"
            user.paypal_customer_id = customer_id
            user.save(update_fields=['paypal_customer_id'])
            return customer_id
        except Exception as e:
            print(f"Error creating customer reference: {e}")
            raise
    
    @staticmethod
    def start_trial(user: User) -> dict:
        """Start a 7-day free trial for the user"""
        trial_days = 7
        
        try:
            # Check if user already used trial
            if user.has_used_trial:
                return {
                    'success': False,
                    'error': 'Trial already used'
                }
            
            # Check if trial is already active
            if user.is_trial_active():
                return {
                    'success': False,
                    'error': 'Trial already active'
                }
            
            # Update user record with trial dates
            user.has_used_trial = True
            user.trial_start_date = timezone.now()
            user.trial_end_date = timezone.now() + timedelta(days=trial_days)
            user.save()
            
            print(f"✅ Trial started for user {user.email} - ends {user.trial_end_date}")
            
            return {
                'success': True,
                'has_trial': True,
                'trial_days': trial_days,
                'trial_end_date': user.trial_end_date.isoformat(),
                'message': f'{trial_days}-day free trial started'
            }
            
        except Exception as e:
            print(f"❌ Error starting trial: {e}")
            import traceback
            traceback.print_exc()
            return {
                'success': False,
                'error': str(e)
            }
    
    @staticmethod
    def create_subscription(user: User) -> dict:
        """Create paid subscription - allows early subscription during trial"""
        try:
            # Get the plan
            plan = SubscriptionPlan.objects.filter(is_active=True).first()
            if not plan or not plan.paypal_plan_id:
                return {
                    'success': False,
                    'error': 'No subscription plan found or plan not configured in PayPal'
                }
            
            # Get or create customer reference
            customer_id = PayPalService.get_or_create_customer(user)
            
            # If user is on trial and has an existing subscription, cancel it first
            if user.paypal_subscription_id:
                try:
                    subscription = paypalrestsdk.Subscription.find(user.paypal_subscription_id)
                    if subscription.status == 'ACTIVE':
                        subscription.cancel()
                        print(f"✅ Cancelled existing subscription for user {user.email}")
                except Exception as e:
                    print(f"⚠️ Could not cancel subscription: {e}")
            
            # Create new subscription in PayPal
            subscription_data = {
                "plan_id": plan.paypal_plan_id,
                "application_context": {
                    "brand_name": "Fitness App",
                    "locale": "en-US",
                    "shipping_preference": "NO_SHIPPING",
                    "user_action": "SUBSCRIBE_NOW",
                    "payment_method": {
                        "payer_selected": "PAYPAL",
                        "payee_preferred": "IMMEDIATE_PAYMENT_REQUIRED"
                    },
                    "return_url": f"{settings.FRONTEND_URL}/subscription/success",
                    "cancel_url": f"{settings.FRONTEND_URL}/subscription/cancel"
                }
            }
            
            subscription = paypalrestsdk.Subscription(subscription_data)
            
            if subscription.create():
                # Update user record with subscription but NOT active until payment succeeds
                user.paypal_subscription_id = subscription.id
                user.save()
                
                # Create pending transaction record
                PaymentTransaction.objects.create(
                    user=user,
                    paypal_subscription_id=subscription.id,
                    amount=plan.amount,
                    payment_type='SUBSCRIPTION',
                    status='PENDING',
                    metadata={
                        'subscription_id': subscription.id,
                        'plan_name': plan.name,
                        'plan_id': plan.paypal_plan_id,
                        'awaiting_payment': True,
                        'subscribed_during_trial': user.is_trial_active()
                    }
                )
                
                # Find approval URL
                approval_url = None
                for link in subscription.links:
                    if link.rel == "approve":
                        approval_url = link.href
                        break
                
                return {
                    'success': True,
                    'subscription_id': subscription.id,
                    'approval_url': approval_url,
                    'requires_payment': True,
                    'message': 'Please approve the subscription to activate'
                }
            else:
                return {
                    'success': False,
                    'error': subscription.error
                }
            
        except Exception as e:
            print(f"❌ Error creating subscription: {e}")
            import traceback
            traceback.print_exc()
            return {
                'success': False,
                'error': str(e)
            }
    
    @staticmethod
    def handle_successful_payment(payment, user=None):
        """Process successful payment - can be called from webhook OR directly"""
        try:
            # Get user from payment custom field if not provided
            if not user and hasattr(payment, 'transactions'):
                custom = payment.transactions[0].custom if payment.transactions else None
                if custom:
                    from apps.accounts.models import User
                    user = User.objects.get(id=custom)
            
            if not user:
                print("❌ No user found for payment")
                return False
            
            print(f"💰 Processing successful payment for user {user.email}")
            
            # Update user subscription status
            user.is_subscription_active = True
            user.subscription_end_date = timezone.now() + timedelta(days=30)
            
            # IMPORTANT: If user was on trial, mark trial as completed
            if user.is_trial_active():
                print(f"🔄 User {user.email} was on trial, converting to paid subscription")
                user.has_used_trial = True  # Already true, but ensure
                # Clear trial end date since they're now subscribed
                user.trial_end_date = None
                user.trial_start_date = None
            
            user.save()
            
            # Update or create transaction record
            payment_id = payment.id if hasattr(payment, 'id') else payment.get('id')
            transaction, created = PaymentTransaction.objects.update_or_create(
                paypal_payment_id=payment_id,
                defaults={
                    'user': user,
                    'amount': float(payment.transactions[0].amount.total) if hasattr(payment, 'transactions') else 9.99,
                    'payment_type': 'SUBSCRIPTION',
                    'status': 'SUCCEEDED',
                    'metadata': {
                        'payment': str(payment),
                        'processed_at': str(timezone.now())
                    }
                }
            )
            
            print(f"✅ Subscription activated for user {user.email}")
            print(f"   - Subscription active: {user.is_subscription_active}")
            print(f"   - End date: {user.subscription_end_date}")
            print(f"   - Trial active: {user.is_trial_active()}")
            
            return True
            
        except Exception as e:
            print(f"❌ Error handling successful payment: {e}")
            import traceback
            traceback.print_exc()
            return False
    
    @staticmethod
    def cancel_subscription(user: User) -> bool:
        """Cancel subscription at period end"""
        try:
            if user.paypal_subscription_id:
                subscription = paypalrestsdk.Subscription.find(user.paypal_subscription_id)
                if subscription.status == 'ACTIVE':
                    # Cancel the subscription
                    result = subscription.cancel()
                    if result:
                        user.is_subscription_active = False
                        user.save()
                        print(f"✅ Subscription cancelled for user {user.email}")
                        return True
            return False
        except Exception as e:
            print(f"❌ Error cancelling subscription: {e}")
            return False
    
    @staticmethod
    def get_subscription_status(user: User) -> dict:
        """Get current subscription status from PayPal"""
        try:
            if not user.paypal_subscription_id:
                return {'status': 'no_subscription'}
            
            subscription = paypalrestsdk.Subscription.find(user.paypal_subscription_id)
            
            return {
                'status': subscription.status.lower() if subscription.status else 'unknown',
                'start_time': subscription.start_time if hasattr(subscription, 'start_time') else None,
                'next_billing_time': subscription.billing_info.next_billing_time if hasattr(subscription, 'billing_info') and subscription.billing_info else None,
                'plan_id': subscription.plan_id if hasattr(subscription, 'plan_id') else None,
                'quantity': subscription.quantity if hasattr(subscription, 'quantity') else None
            }
        except Exception as e:
            print(f"❌ Error getting subscription status: {e}")
            return {'status': 'error', 'error': str(e)}
    
    @staticmethod
    def get_payment_details(payment_id: str) -> dict:
        """Get payment details from PayPal"""
        try:
            payment = paypalrestsdk.Payment.find(payment_id)
            return {
                'id': payment.id,
                'state': payment.state,
                'amount': payment.transactions[0].amount.total if payment.transactions else None,
                'currency': payment.transactions[0].amount.currency if payment.transactions else None,
                'create_time': payment.create_time,
                'payer_info': {
                    'email': payment.payer.payer_info.email if payment.payer.payer_info else None,
                    'first_name': payment.payer.payer_info.first_name if payment.payer.payer_info else None,
                    'last_name': payment.payer.payer_info.last_name if payment.payer.payer_info else None
                } if payment.payer else {}
            }
        except Exception as e:
            print(f"❌ Error getting payment details: {e}")
            return {'error': str(e)}
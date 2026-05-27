import paypalrestsdk
from django.conf import settings
from django.utils import timezone
from datetime import timedelta
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.http import HttpResponse
from .models import SubscriptionPlan, PaymentTransaction
from .serializers import SubscriptionPlanSerializer
from .paypal_service import PayPalService
from apps.accounts.models import User
import json
import traceback

# Configure PayPal
paypalrestsdk.configure({
    "mode": settings.PAYPAL_MODE,  # sandbox or live
    "client_id": settings.PAYPAL_CLIENT_ID,
    "client_secret": settings.PAYPAL_CLIENT_SECRET
})


class PaymentViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    
    @action(detail=False, methods=['GET'])
    def plan(self, request):
        """Get the subscription plan"""
        try:
            # Try to get the plan from database
            plan = SubscriptionPlan.objects.filter(is_active=True).first()
            
            if plan:
                # Return plan data
                return Response({
                    'name': plan.name,
                    'amount': str(plan.amount),
                    'currency': 'USD',
                    'interval': plan.interval,
                    'id': str(plan.id),
                    'is_active': plan.is_active,
                    'paypal_plan_id': plan.paypal_plan_id
                })
            
            # Return default plan if none exists in DB
            return Response({
                'name': 'Premium Plan',
                'amount': '9.99',
                'currency': 'USD',
                'interval': 'month'
            })
            
        except Exception as e:
            # Log the error for debugging
            print(f"❌ Error in plan endpoint: {e}")
            traceback.print_exc()
            
            # Always return a fallback plan instead of crashing
            return Response({
                'name': 'Premium Plan',
                'amount': '9.99',
                'currency': 'USD',
                'interval': 'month'
            })
    
    @action(detail=False, methods=['GET'])
    def check_trial_eligibility(self, request):
        """Check if user is eligible for free trial"""
        user = request.user
        
        return Response({
            'eligible_for_trial': not user.has_used_trial,
            'has_used_trial': user.has_used_trial,
            'trial_end_date': user.trial_end_date,
            'is_trial_active': user.is_trial_active(),
            'days_remaining': user.get_trial_days_remaining()
        })
    
    @action(detail=False, methods=['POST'])
    def start_trial(self, request):
        """Start 7-day free trial"""
        user = request.user
        
        # Check if user already used trial
        if user.has_used_trial:
            return Response({'error': 'Trial already used'}, status=400)
        
        # Check if trial is already active
        if user.is_trial_active():
            return Response({'error': 'Trial already active'}, status=400)
        
        # Check if user already has active subscription
        if user.is_subscription_active:
            return Response({'error': 'User already has active subscription'}, status=400)
        
        result = PayPalService.start_trial(user)
        return Response(result)
    
    @action(detail=False, methods=['POST'])
    def create_payment(self, request):
        """Create a PayPal Payment for subscription"""
        user = request.user
        
        # FIXED: Allow upgrades during trial - only block if already has PAID subscription
        if user.is_subscription_active:
            return Response({
                'error': 'User already has an active paid subscription'
            }, status=400)
        
        # Check if there's already a pending transaction
        existing_pending = PaymentTransaction.objects.filter(
            user=user,
            status='PENDING'
        ).first()
        
        if existing_pending:
            # Check if pending payment is stale (older than 30 minutes)
            time_since_created = timezone.now() - existing_pending.created_at
            if time_since_created > timedelta(minutes=30):
                # Old pending payment - delete it and create new one
                existing_pending.delete()
                print(f"🗑️ Deleted stale pending transaction for user {user.email}")
            else:
                return Response({
                    'error': 'You already have a pending payment. Please complete or cancel it.',
                    'pending_payment_id': str(existing_pending.id),
                    'created_at': existing_pending.created_at,
                    'created_at_formatted': existing_pending.created_at.strftime("%Y-%m-%d %H:%M:%S")
                }, status=400)
        
        try:
            # Get plan amount (default $9.99)
            plan = SubscriptionPlan.objects.filter(is_active=True).first()
            amount = str(plan.amount) if plan else '9.99'
            
            # Create a PayPal payment
            payment = paypalrestsdk.Payment({
                "intent": "sale",
                "payer": {
                    "payment_method": "paypal"
                },
                "redirect_urls": {
                    "return_url": f"{settings.FRONTEND_URL}/payment/success",
                    "cancel_url": f"{settings.FRONTEND_URL}/payment/cancel"
                },
                "transactions": [{
                    "amount": {
                        "total": amount,
                        "currency": "USD"
                    },
                    "description": f'Monthly subscription for {user.email}',
                    "custom": str(user.id)  # Store user ID for webhook reference
                }]
            })
            
            if payment.create():
                # Create a pending transaction record
                transaction = PaymentTransaction.objects.create(
                    user=user,
                    amount=float(amount),
                    status='PENDING',
                    payment_type='SUBSCRIPTION',
                    paypal_payment_id=payment.id,
                    metadata={
                        'plan_name': plan.name if plan else 'Premium Plan',
                        'payment_id': payment.id,
                        'upgrading_from_trial': user.is_trial_active()  # Track upgrade
                    }
                )
                
                # Find approval URL
                approval_url = None
                for link in payment.links:
                    if link.rel == "approval_url":
                        approval_url = link.href
                        break
                
                return Response({
                    'payment_id': payment.id,
                    'approval_url': approval_url,
                    'transaction_id': str(transaction.id)
                })
            else:
                error_msg = str(payment.error) if payment.error else 'Payment creation failed'
                print(f"PayPal payment creation error: {error_msg}")
                return Response({'error': error_msg}, status=500)
            
        except Exception as e:
            print(f"Error creating PayPal payment: {e}")
            traceback.print_exc()
            return Response({'error': str(e)}, status=500)
    
    @action(detail=False, methods=['POST'])
    def cancel_pending_payment(self, request):
        """Cancel a pending payment"""
        user = request.user
        
        # Find pending transaction
        pending = PaymentTransaction.objects.filter(
            user=user,
            status='PENDING'
        ).first()
        
        if not pending:
            return Response({
                'error': 'No pending payment found',
                'success': False
            }, status=400)
        
        try:
            # Mark as failed
            pending.status = 'FAILED'
            pending.metadata = {
                **(pending.metadata or {}),
                'cancelled_at': str(timezone.now()),
                'cancelled_by': 'user'
            }
            pending.save()
            
            print(f"✅ Cancelled pending payment {pending.id} for user {user.email}")
            
            return Response({
                'success': True,
                'message': 'Pending payment cancelled successfully',
                'transaction_id': str(pending.id)
            })
            
        except Exception as e:
            print(f"❌ Error cancelling pending payment: {e}")
            return Response({
                'error': f'Failed to cancel payment: {str(e)}',
                'success': False
            }, status=500)
    
    @action(detail=False, methods=['GET'])
    def get_pending_payment(self, request):
        """Get pending payment status"""
        user = request.user
        
        pending = PaymentTransaction.objects.filter(
            user=user,
            status='PENDING'
        ).first()
        
        if pending:
            return Response({
                'has_pending': True,
                'payment_id': str(pending.id),
                'amount': str(pending.amount),
                'created_at': pending.created_at,
                'created_at_formatted': pending.created_at.strftime("%Y-%m-%d %H:%M:%S"),
                'is_stale': (timezone.now() - pending.created_at) > timedelta(minutes=30)
            })
        
        return Response({
            'has_pending': False
        })
    
    @action(detail=False, methods=['POST'])
    def execute_payment(self, request):
        """Execute PayPal payment after user approval"""
        payment_id = request.data.get('payment_id')
        payer_id = request.data.get('payer_id')
        
        if not payment_id or not payer_id:
            return Response({'error': 'Payment ID and Payer ID required'}, status=400)
        
        try:
            payment = paypalrestsdk.Payment.find(payment_id)
            
            if payment.execute({"payer_id": payer_id}):
                # Payment successful
                success = PayPalService.handle_successful_payment(payment, request.user)
                
                if success:
                    # Update transaction
                    transaction = PaymentTransaction.objects.filter(
                        paypal_payment_id=payment_id
                    ).first()
                    if transaction:
                        transaction.status = 'SUCCEEDED'
                        transaction.save()
                    
                    # Clear trial if user upgraded
                    if request.user.is_trial_active():
                        request.user.trial_end_date = None
                        request.user.trial_start_date = None
                        request.user.save()
                    
                    return Response({
                        'success': True,
                        'has_access': request.user.has_access(),
                        'is_subscribed': request.user.is_subscription_active,
                        'message': 'Payment confirmed and subscription activated'
                    })
                else:
                    return Response({'error': 'Failed to update subscription'}, status=500)
            else:
                error_msg = str(payment.error) if payment.error else 'Payment execution failed'
                return Response({'error': error_msg}, status=400)
                
        except Exception as e:
            print(f"Error executing payment: {e}")
            traceback.print_exc()
            return Response({'error': str(e)}, status=500)
    
    @action(detail=False, methods=['POST'])
    def create_subscription(self, request):
        """Create a PayPal subscription"""
        user = request.user
        
        # FIXED: Allow upgrades during trial - only block if already has PAID subscription
        if user.is_subscription_active:
            return Response({
                'error': 'User already has an active subscription'
            }, status=400)
        
        # Check if there's already a pending transaction
        existing_pending = PaymentTransaction.objects.filter(
            user=user,
            status='PENDING'
        ).first()
        
        if existing_pending:
            time_since_created = timezone.now() - existing_pending.created_at
            if time_since_created > timedelta(minutes=30):
                existing_pending.delete()
            else:
                return Response({
                    'error': 'You already have a pending payment. Please complete or cancel it.',
                    'pending_payment_id': str(existing_pending.id)
                }, status=400)
        
        try:
            # Get plan
            plan = SubscriptionPlan.objects.filter(is_active=True).first()
            if not plan or not plan.paypal_plan_id:
                return Response({'error': 'Subscription plan not configured. Please contact support.'}, status=500)
            
            # Create subscription
            subscription = paypalrestsdk.Subscription({
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
            })
            
            if subscription.create():
                # Store subscription ID
                user.paypal_subscription_id = subscription.id
                user.save()
                
                # Create pending transaction
                PaymentTransaction.objects.create(
                    user=user,
                    amount=float(plan.amount),
                    status='PENDING',
                    payment_type='SUBSCRIPTION',
                    paypal_subscription_id=subscription.id,
                    metadata={
                        'plan_name': plan.name,
                        'subscription_id': subscription.id,
                        'upgrading_from_trial': user.is_trial_active()  # Track upgrade
                    }
                )
                
                # Find approval URL
                approval_url = None
                for link in subscription.links:
                    if link.rel == "approve":
                        approval_url = link.href
                        break
                
                return Response({
                    'subscription_id': subscription.id,
                    'approval_url': approval_url
                })
            else:
                error_msg = str(subscription.error) if subscription.error else 'Subscription creation failed'
                print(f"PayPal subscription creation error: {error_msg}")
                return Response({'error': error_msg}, status=500)
                
        except Exception as e:
            print(f"Error creating PayPal subscription: {e}")
            traceback.print_exc()
            return Response({'error': str(e)}, status=500)
    
    @action(detail=False, methods=['POST'])
    def cancel_subscription(self, request):
        """Cancel subscription"""
        result = PayPalService.cancel_subscription(request.user)
        if result:
            return Response({'message': 'Subscription cancelled successfully'})
        return Response({'error': 'No active subscription found'}, status=400)
    
    @action(detail=False, methods=['GET'])
    def status(self, request):
        """Get subscription/trial status"""
        user = request.user
        
        # CRITICAL FIX: Check for successful payments that might not have updated the user
        # This handles cases where webhook might have failed
        successful_pending = PaymentTransaction.objects.filter(
            user=user,
            status='SUCCEEDED',
            payment_type='SUBSCRIPTION'
        ).exists()
        
        if successful_pending and not user.is_subscription_active:
            print(f"⚠️ Found successful transaction but user not subscribed - fixing for user {user.email}")
            # Activate subscription for user
            user.is_subscription_active = True
            if not user.subscription_end_date or user.subscription_end_date < timezone.now():
                user.subscription_end_date = timezone.now() + timedelta(days=30)
            # Clear trial if user upgraded
            if user.is_trial_active():
                user.trial_end_date = None
                user.trial_start_date = None
            user.save()
        
        # Force refresh from PayPal if needed
        if user.paypal_subscription_id and user.is_subscription_active:
            # Check subscription status with PayPal
            try:
                subscription = paypalrestsdk.Subscription.find(user.paypal_subscription_id)
                if subscription.status == 'ACTIVE':
                    # Update local status
                    if subscription.billing_info and subscription.billing_info.next_billing_time:
                        user.subscription_end_date = subscription.billing_info.next_billing_time
                    user.is_subscription_active = True
                    user.save()
                else:
                    # No active subscription found
                    user.is_subscription_active = False
                    user.save()
            except Exception as e:
                print(f"Error checking PayPal subscription: {e}")
        
        return Response({
            'has_access': user.has_access(),
            'is_trial_active': user.is_trial_active(),
            'trial_days_remaining': user.get_trial_days_remaining(),
            'is_subscribed': user.is_subscription_active,
            'subscription_end_date': user.subscription_end_date,
            'has_used_trial': user.has_used_trial,
        })
    
    @action(detail=False, methods=['GET'])
    def payment_history(self, request):
        """Get payment history"""
        try:
            transactions = PaymentTransaction.objects.filter(user=request.user).order_by('-created_at')
            return Response({
                'transactions': [
                    {
                        'id': str(t.id),
                        'amount': str(t.amount),
                        'status': t.status,
                        'payment_type': t.payment_type,
                        'created_at': t.created_at.isoformat() if t.created_at else None,
                        'metadata': t.metadata
                    } for t in transactions
                ]
            })
        except Exception as e:
            print(f"Error getting payment history: {e}")
            return Response({'transactions': []}, status=200)


@method_decorator(csrf_exempt, name='dispatch')
class PayPalWebhookView(viewsets.ViewSet):
    """Handle PayPal webhook events"""
    permission_classes = [AllowAny]
    
    def create(self, request):
        payload = request.body
        webhook_id = settings.PAYPAL_WEBHOOK_ID
        
        try:
            # Verify webhook signature (implement proper verification)
            headers = request.META
            event = json.loads(payload)
            
            # For production, implement signature verification:
            # https://developer.paypal.com/docs/api-basics/notifications/verify-webhook-signature/
            
            print(f"📨 Received PayPal webhook event: {event.get('event_type')}")
            
        except Exception as e:
            print(f"Error parsing webhook: {e}")
            return HttpResponse(status=400)
        
        # Handle different event types
        event_handlers = {
            'PAYMENT.SALE.COMPLETED': handle_payment_success,
            'PAYMENT.SALE.DENIED': handle_payment_failure,
            'BILLING.SUBSCRIPTION.ACTIVATED': handle_subscription_activated,
            'BILLING.SUBSCRIPTION.CANCELLED': handle_subscription_cancelled,
            'BILLING.SUBSCRIPTION.SUSPENDED': handle_subscription_suspended,
            'BILLING.SUBSCRIPTION.EXPIRED': handle_subscription_expired,
            'BILLING.SUBSCRIPTION.PAYMENT.FAILED': handle_payment_failure,
            'BILLING.SUBSCRIPTION.RENEWED': handle_subscription_renewed,
        }
        
        handler = event_handlers.get(event.get('event_type'))
        if handler:
            handler(event.get('resource', {}))
        else:
            print(f"⚠️ Unhandled event type: {event.get('event_type')}")
        
        return HttpResponse(status=200)


def handle_payment_success(resource):
    """Handle successful payment"""
    try:
        print(f"💰 Payment succeeded: {resource.get('id')}")
        
        # Get custom field which contains user_id
        custom = resource.get('custom', '')
        user_id = custom if custom else None
        
        if user_id:
            try:
                user = User.objects.get(id=user_id)
                
                # Update transaction
                transaction = PaymentTransaction.objects.filter(
                    paypal_payment_id=resource.get('id')
                ).first()
                
                if not transaction:
                    transaction = PaymentTransaction.objects.filter(
                        user=user,
                        status='PENDING'
                    ).first()
                
                if transaction:
                    transaction.status = 'SUCCEEDED'
                    transaction.paypal_payment_id = resource.get('id')
                    transaction.save()
                    print(f"✅ Updated transaction {transaction.id} to SUCCEEDED")
                else:
                    # Create transaction if it doesn't exist
                    amount = float(resource.get('amount', {}).get('total', 9.99))
                    transaction = PaymentTransaction.objects.create(
                        user=user,
                        amount=amount,
                        status='SUCCEEDED',
                        payment_type='SUBSCRIPTION',
                        paypal_payment_id=resource.get('id'),
                        metadata={
                            'payment_id': resource.get('id'),
                            'webhook_created': True
                        }
                    )
                    print(f"✅ Created new transaction {transaction.id} as SUCCEEDED")
                
                # Activate subscription and clear trial if upgrading
                if not user.is_subscription_active:
                    user.is_subscription_active = True
                    user.subscription_end_date = timezone.now() + timedelta(days=30)
                    user.save()
                    print(f"✅ Subscription activated for user {user.email}")
                    
                    # Clear trial dates if user was on trial (upgrade scenario)
                    if user.is_trial_active():
                        print(f"🔄 User {user.email} upgraded from trial to paid - clearing trial dates")
                        user.trial_end_date = None
                        user.trial_start_date = None
                        user.save()
                else:
                    print(f"⚠️ User {user.email} already had active subscription")
                
            except User.DoesNotExist:
                print(f"❌ User not found for ID: {user_id}")
        else:
            print("⚠️ No user_id in payment custom field")
            
    except Exception as e:
        print(f"❌ Error handling payment success: {e}")
        traceback.print_exc()


def handle_payment_failure(resource):
    """Handle failed payment"""
    try:
        print(f"❌ Payment failed: {resource.get('id')}")
        
        # Update transaction status to failed
        PaymentTransaction.objects.filter(
            paypal_payment_id=resource.get('id')
        ).update(status='FAILED')
        print(f"✅ Updated transaction to FAILED")
        
    except Exception as e:
        print(f"❌ Error handling payment failure: {e}")


def handle_subscription_activated(resource):
    """Handle subscription activated"""
    try:
        print(f"✅ Subscription activated: {resource.get('id')}")
        
        user = User.objects.filter(paypal_subscription_id=resource.get('id')).first()
        if user:
            was_on_trial = user.is_trial_active()
            user.is_subscription_active = True
            if resource.get('billing_info', {}).get('next_billing_time'):
                user.subscription_end_date = resource['billing_info']['next_billing_time']
            # Clear trial if user was on trial
            if was_on_trial:
                user.trial_end_date = None
                user.trial_start_date = None
            user.save()
            print(f"✅ Activated subscription for user {user.email}" + 
                  (" (upgraded from trial)" if was_on_trial else ""))
            
    except Exception as e:
        print(f"❌ Error handling subscription activation: {e}")
        traceback.print_exc()


def handle_subscription_cancelled(resource):
    """Handle subscription cancelled"""
    try:
        print(f"❌ Subscription cancelled: {resource.get('id')}")
        
        user = User.objects.filter(paypal_subscription_id=resource.get('id')).first()
        if user:
            user.is_subscription_active = False
            user.subscription_end_date = None
            user.save()
            print(f"✅ Deactivated subscription for user {user.email}")
            
    except Exception as e:
        print(f"❌ Error handling subscription cancel: {e}")
        traceback.print_exc()


def handle_subscription_suspended(resource):
    """Handle subscription suspended"""
    try:
        print(f"⚠️ Subscription suspended: {resource.get('id')}")
        
        user = User.objects.filter(paypal_subscription_id=resource.get('id')).first()
        if user:
            user.is_subscription_active = False
            user.save()
            print(f"✅ Suspended subscription for user {user.email}")
            
    except Exception as e:
        print(f"❌ Error handling subscription suspension: {e}")
        traceback.print_exc()


def handle_subscription_expired(resource):
    """Handle subscription expired"""
    try:
        print(f"⚠️ Subscription expired: {resource.get('id')}")
        
        user = User.objects.filter(paypal_subscription_id=resource.get('id')).first()
        if user:
            user.is_subscription_active = False
            user.subscription_end_date = None
            user.save()
            print(f"✅ Expired subscription for user {user.email}")
            
    except Exception as e:
        print(f"❌ Error handling subscription expiry: {e}")
        traceback.print_exc()


def handle_subscription_renewed(resource):
    """Handle subscription renewed"""
    try:
        print(f"🔄 Subscription renewed: {resource.get('id')}")
        
        user = User.objects.filter(paypal_subscription_id=resource.get('id')).first()
        if user:
            user.is_subscription_active = True
            if resource.get('billing_info', {}).get('next_billing_time'):
                user.subscription_end_date = resource['billing_info']['next_billing_time']
            user.save()
            print(f"✅ Renewed subscription for user {user.email}")
            
    except Exception as e:
        print(f"❌ Error handling subscription renewal: {e}")
        traceback.print_exc()
# views.py
import stripe
from django.conf import settings
from django.shortcuts import redirect
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from django.http import HttpResponse
from .models import SubscriptionPlan, PaymentTransaction, Invoice
from .serializers import SubscriptionPlanSerializer, PaymentIntentSerializer
from apps.accounts.models import User
import json

stripe.api_key = settings.STRIPE_SECRET_KEY

class PaymentViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    
    @action(detail=False, methods=['GET'])
    def plans(self, request):
        plans = SubscriptionPlan.objects.filter(is_active=True)
        serializer = SubscriptionPlanSerializer(plans, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['POST'])
    def create_subscription(self, request):
        price_id = request.data.get('price_id')
        
        try:
            # Get or create Stripe customer
            user = request.user
            if not user.stripe_customer_id:
                customer = stripe.Customer.create(
                    email=user.email,
                    name=user.username,
                    metadata={'user_id': str(user.id)}
                )
                user.stripe_customer_id = customer.id
                user.save()
            
            # Create subscription
            subscription = stripe.Subscription.create(
                customer=user.stripe_customer_id,
                items=[{'price': price_id}],
                payment_behavior='default_incomplete',
                expand=['latest_invoice.payment_intent'],
                metadata={'user_id': str(user.id)}
            )
            
            # Save to database
            plan = SubscriptionPlan.objects.get(stripe_price_id=price_id)
            PaymentTransaction.objects.create(
                user=user,
                stripe_payment_intent_id=subscription.latest_invoice.payment_intent.id,
                stripe_subscription_id=subscription.id,
                amount=plan.amount,
                payment_type='SUBSCRIPTION',
                status='PENDING',
                metadata={'subscription_id': subscription.id}
            )
            
            return Response({
                'subscription_id': subscription.id,
                'client_secret': subscription.latest_invoice.payment_intent.client_secret
            })
            
        except stripe.error.StripeError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['POST'])
    def cancel_subscription(self, request):
        try:
            subscription_id = request.user.stripe_subscription_id
            if subscription_id:
                stripe.Subscription.delete(subscription_id)
                request.user.subscription_tier = 'FREE'
                request.user.subscription_end_date = None
                request.user.stripe_subscription_id = None
                request.user.save()
                return Response({'message': 'Subscription cancelled successfully'})
            return Response({'error': 'No active subscription found'}, status=status.HTTP_400_BAD_REQUEST)
        except stripe.error.StripeError as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['GET'])
    def payment_history(self, request):
        transactions = PaymentTransaction.objects.filter(user=request.user).order_by('-created_at')
        return Response({
            'transactions': [
                {
                    'amount': t.amount,
                    'status': t.status,
                    'type': t.payment_type,
                    'date': t.created_at,
                } for t in transactions
            ]
        })

@method_decorator(csrf_exempt, name='dispatch')
class StripeWebhookView(viewsets.ViewSet):
    permission_classes = [AllowAny]
    
    def create(self, request):
        payload = request.body
        sig_header = request.META.get('HTTP_STRIPE_SIGNATURE')
        
        try:
            event = stripe.Webhook.construct_event(
                payload, sig_header, settings.STRIPE_WEBHOOK_SECRET
            )
        except ValueError:
            return HttpResponse(status=400)
        except stripe.error.SignatureVerificationError:
            return HttpResponse(status=400)
        
        # Handle the event
        if event['type'] == 'invoice.payment_succeeded':
            invoice = event['data']['object']
            self._handle_payment_success(invoice)
        elif event['type'] == 'customer.subscription.updated':
            subscription = event['data']['object']
            self._handle_subscription_update(subscription)
        elif event['type'] == 'customer.subscription.deleted':
            subscription = event['data']['object']
            self._handle_subscription_cancel(subscription)
        
        return HttpResponse(status=200)
    
    def _handle_payment_success(self, invoice):
        try:
            # Update transaction
            transaction = PaymentTransaction.objects.get(
                stripe_payment_intent_id=invoice['payment_intent']
            )
            transaction.status = 'SUCCEEDED'
            transaction.save()
            
            # Update user subscription
            user = transaction.user
            user.subscription_tier = 'PREMIUM'
            user.subscription_end_date = invoice['period_end']
            user.stripe_subscription_id = invoice['subscription']
            user.save()
            
        except PaymentTransaction.DoesNotExist:
            pass
    
    def _handle_subscription_update(self, subscription):
        try:
            user = User.objects.get(stripe_customer_id=subscription['customer'])
            user.subscription_end_date = subscription['current_period_end']
            user.save()
        except User.DoesNotExist:
            pass
    
    def _handle_subscription_cancel(self, subscription):
        try:
            user = User.objects.get(stripe_customer_id=subscription['customer'])
            user.subscription_tier = 'FREE'
            user.subscription_end_date = None
            user.stripe_subscription_id = None
            user.save()
        except User.DoesNotExist:
            pass
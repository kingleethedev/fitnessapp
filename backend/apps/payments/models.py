# backend/apps/payments/models.py
from django.db import models
from django.conf import settings
import uuid

class SubscriptionPlan(models.Model):
    """Single subscription plan for the SaaS"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100, default='Premium')
    paypal_plan_id = models.CharField(max_length=100, unique=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2, default=9.99)
    interval = models.CharField(max_length=20, default='month')  # 'month' or 'year'
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.name} - ${self.amount}/{self.interval}"


class PaymentTransaction(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='payments')
    paypal_payment_id = models.CharField(max_length=100, unique=True, null=True, blank=True)
    paypal_subscription_id = models.CharField(max_length=100, null=True, blank=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    currency = models.CharField(max_length=3, default='USD')
    
    STATUS_CHOICES = [
        ('PENDING', 'Pending'),
        ('SUCCEEDED', 'Succeeded'),
        ('FAILED', 'Failed'),
        ('REFUNDED', 'Refunded'),
    ]
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    
    PAYMENT_TYPE_CHOICES = [
        ('SUBSCRIPTION', 'Subscription'),
        ('ONE_TIME', 'One Time'),
    ]
    payment_type = models.CharField(max_length=20, choices=PAYMENT_TYPE_CHOICES)
    
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.user.username} - ${self.amount} - {self.status}"
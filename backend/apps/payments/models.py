# models.py
from django.db import models
from django.conf import settings
import uuid

class SubscriptionPlan(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100)
    stripe_price_id = models.CharField(max_length=100, unique=True)
    tier = models.CharField(max_length=20, choices=[
        ('PREMIUM', 'Premium'),
        ('PRO', 'Pro'),
    ])
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    interval = models.CharField(max_length=20, choices=[
        ('month', 'Monthly'),
        ('year', 'Yearly'),
    ])
    
    # Features
    unlimited_workouts = models.BooleanField(default=False)
    advanced_analytics = models.BooleanField(default=False)
    custom_workouts = models.BooleanField(default=False)
    priority_support = models.BooleanField(default=False)
    
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.name} - ${self.amount}/{self.interval}"

class PaymentTransaction(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='payments')
    stripe_payment_intent_id = models.CharField(max_length=100, unique=True)
    stripe_subscription_id = models.CharField(max_length=100, null=True, blank=True)
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

class Invoice(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='invoices')
    transaction = models.OneToOneField(PaymentTransaction, on_delete=models.CASCADE, related_name='invoice')
    invoice_number = models.CharField(max_length=100, unique=True)
    stripe_invoice_id = models.CharField(max_length=100, unique=True)
    pdf_url = models.URLField(max_length=500)
    amount_due = models.DecimalField(max_digits=10, decimal_places=2)
    amount_paid = models.DecimalField(max_digits=10, decimal_places=2)
    invoice_date = models.DateTimeField()
    due_date = models.DateTimeField()
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"Invoice {self.invoice_number} - {self.user.username}"
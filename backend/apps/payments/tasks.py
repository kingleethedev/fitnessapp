from celery import shared_task
from django.utils import timezone
from datetime import timedelta
from django.core.mail import send_mail
from django.conf import settings
from .models import PaymentTransaction
from apps.accounts.models import User

@shared_task
def send_renewal_reminders():
    """Send subscription renewal reminders"""
    three_days_from_now = timezone.now() + timedelta(days=3)
    
    # Check for users with active subscription ending in 3 days
    users = User.objects.filter(
        subscription_end_date__date=three_days_from_now.date(),
        is_subscription_active=True
    )
    
    reminder_count = 0
    for user in users:
        send_mail(
            'Subscription Renewal Reminder',
            f'Hi {user.username},\n\nYour subscription will renew in 3 days.',
            settings.DEFAULT_FROM_EMAIL,
            [user.email],
            fail_silently=False,
        )
        reminder_count += 1
    
    return f"Sent {reminder_count} renewal reminders"
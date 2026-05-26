from celery import shared_task
from django.utils import timezone
from datetime import timedelta
from django.core.mail import send_mail
from django.conf import settings
from .models import User

@shared_task
def cleanup_inactive_users():
    """Delete users who haven't logged in for 6 months"""
    six_months_ago = timezone.now() - timedelta(days=180)
    inactive_users = User.objects.filter(
        last_login__lt=six_months_ago,
        is_active=True
    )
    
    count = inactive_users.count()
    inactive_users.delete()
    
    return f"Cleaned up {count} inactive users"

@shared_task
def send_welcome_email(user_id):
    """Send welcome email to new user"""
    try:
        user = User.objects.get(id=user_id)
        send_mail(
            'Welcome to Fitness App',
            f'Hi {user.username},\n\nWelcome to Fitness App! Get started with your fitness journey today.',
            settings.DEFAULT_FROM_EMAIL,
            [user.email],
            fail_silently=False,
        )
        return f"Welcome email sent to {user.email}"
    except User.DoesNotExist:
        return f"User {user_id} not found"
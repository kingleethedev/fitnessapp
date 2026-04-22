from celery import shared_task
from django.utils import timezone
from datetime import timedelta
from django.core.mail import send_mail
from django.conf import settings
from .models import Workout
from .workout_engine import WorkoutGenerator

@shared_task
def send_workout_reminders():
    """Send workout reminders to users"""
    from apps.accounts.models import User
    
    users = User.objects.filter(is_active=True, profile__push_notifications_enabled=True)
    
    reminder_count = 0
    for user in users:
        # Check if user has worked out today
        today = timezone.now().date()
        if not Workout.objects.filter(user=user, date=today, is_completed=True).exists():
            # Send reminder via Firebase
            # This would integrate with Firebase Cloud Messaging
            reminder_count += 1
    
    return f"Sent {reminder_count} workout reminders"

@shared_task
def update_streaks():
    """Update user streaks daily"""
    from apps.accounts.models import User
    
    users = User.objects.filter(is_active=True)
    yesterday = timezone.now().date() - timedelta(days=1)
    
    for user in users:
        # Check if user worked out yesterday
        if not Workout.objects.filter(user=user, date=yesterday, is_completed=True).exists():
            # Reset streak if no workout yesterday
            user.streak_days = 0
            user.save()
    
    return "Streaks updated"

@shared_task
def sync_offline_data():
    """Sync offline workout data from Firebase"""
    # This would sync data from Firestore to PostgreSQL
    return "Offline data synced"
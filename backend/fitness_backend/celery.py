import os
from celery import Celery
from celery.schedules import crontab
from pathlib import Path

# Set the default Django settings module for the 'celery' program.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fitness_backend.settings')

app = Celery('fitness_backend')

# Using a string here means the worker doesn't have to serialize
# the configuration object to child processes.
app.config_from_object('django.conf:settings', namespace='CELERY')

# Load task modules from all registered Django apps.
app.autodiscover_tasks()

# Configure periodic tasks
app.conf.beat_schedule = {
    'send-daily-workout-reminders': {
        'task': 'apps.workouts.tasks.send_workout_reminders',
        'schedule': crontab(hour=8, minute=0),  # 8 AM daily
    },
    'send-daily-meal-reminders': {
        'task': 'apps.meals.tasks.send_meal_reminders',
        'schedule': crontab(hour=7, minute=30),  # 7:30 AM daily
    },
    'update-user-streaks': {
        'task': 'apps.workouts.tasks.update_streaks',
        'schedule': crontab(minute=0, hour=0),  # Midnight daily
    },
    'generate-weekly-meal-plans': {
        'task': 'apps.meals.tasks.generate_weekly_meal_plans',
        'schedule': crontab(day_of_week=6, hour=20, minute=0),  # Saturday 8 PM
    },
    'generate-weekly-reports': {
        'task': 'apps.analytics.tasks.generate_weekly_reports',
        'schedule': crontab(day_of_week=0, hour=9, minute=0),  # Monday 9 AM
    },
    'cleanup-inactive-users': {
        'task': 'apps.accounts.tasks.cleanup_inactive_users',
        'schedule': crontab(day_of_month=1, hour=2, minute=0),  # 1st of month at 2 AM
    },
    'send-subscription-renewal-reminders': {
        'task': 'apps.payments.tasks.send_renewal_reminders',
        'schedule': crontab(hour=10, minute=0),  # 10 AM daily
    },
    'sync-offline-data': {
        'task': 'apps.workouts.tasks.sync_offline_data',
        'schedule': crontab(hour='*/2', minute=0),  # Every 2 hours
    },
}

@app.task(bind=True)
def debug_task(self):
    print(f'Request: {self.request!r}')
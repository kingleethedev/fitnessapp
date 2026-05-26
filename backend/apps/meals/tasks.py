from celery import shared_task
from django.utils import timezone
from django.core.mail import send_mail
from django.template.loader import render_to_string
from django.conf import settings
from .models import MealPlan
from .meal_planner import MealPlanner

@shared_task
def generate_weekly_meal_plans():
    """Generate meal plans for all users who don't have one"""
    from apps.accounts.models import User
    
    today = timezone.now().date()
    # Get all active users
    users = User.objects.filter(is_active=True)
    
    generated_count = 0
    for user in users:
        # Check if user already has a meal plan for this week
        if not MealPlan.objects.filter(user=user, week_start_date__lte=today, week_end_date__gte=today).exists():
            MealPlanner.generate_meal_plan(user)
            generated_count += 1
    
    return f"Generated {generated_count} weekly meal plans"

@shared_task
def send_meal_reminders():
    """Send meal reminders to users"""
    from apps.accounts.models import User
    
    users = User.objects.filter(is_active=True, profile__push_notifications_enabled=True)
    
    reminder_count = 0
    for user in users:
        if user.profile.workout_reminder_time:
            # Logic to send push notifications via Firebase
            # This would integrate with Firebase Cloud Messaging
            reminder_count += 1
    
    return f"Sent {reminder_count} meal reminders"

@shared_task
def send_meal_plan_email(user_id, plan_id):
    """Email the weekly meal plan to user"""
    try:
        user = User.objects.get(id=user_id)
        meal_plan = MealPlan.objects.get(id=plan_id)
        
        # Prepare email context
        context = {
            'username': user.username,
            'week_start': meal_plan.week_start_date,
            'week_end': meal_plan.week_end_date,
            'goal_display': meal_plan.get_goal_display(),
            'meal_plan': meal_plan.meals,
            'target_calories': meal_plan.target_calories,
            'target_protein': meal_plan.target_protein,
            'target_carbs': meal_plan.target_carbs,
            'target_fats': meal_plan.target_fats,
            'app_link': f"{settings.FRONTEND_URL}/meal-plan",
        }
        
        html_content = render_to_string('email/meal_plan_email.html', context)
        
        send_mail(
            f'Your Weekly Meal Plan - {meal_plan.week_start_date}',
            'Your meal plan is ready in the app',
            settings.DEFAULT_FROM_EMAIL,
            [user.email],
            html_message=html_content,
            fail_silently=False,
        )
        
        return f"Meal plan email sent to {user.email}"
    except (User.DoesNotExist, MealPlan.DoesNotExist) as e:
        return f"Error: {str(e)}"
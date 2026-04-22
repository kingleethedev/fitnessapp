from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils import timezone
import uuid

class User(AbstractUser):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    
    # Personal Information
    height = models.FloatField(null=True, blank=True, help_text="Height in cm")
    weight = models.FloatField(null=True, blank=True, help_text="Weight in kg")
    date_of_birth = models.DateField(null=True, blank=True)
    gender = models.CharField(max_length=10, choices=[('MALE', 'Male'), ('FEMALE', 'Female')], null=True, blank=True)
    age = models.IntegerField(null=True, blank=True)
    
    # Fitness Preferences
    GOAL_CHOICES = [
        ('FAT_LOSS', 'Fat Loss'),
        ('MUSCLE_GAIN', 'Muscle Gain'),
        ('FITNESS', 'General Fitness'),
    ]
    goal = models.CharField(max_length=20, choices=GOAL_CHOICES, default='FITNESS')
    
    EXPERIENCE_CHOICES = [
        ('BEGINNER', 'Beginner'),
        ('INTERMEDIATE', 'Intermediate'),
        ('ADVANCED', 'Advanced'),
    ]
    experience_level = models.CharField(max_length=20, choices=EXPERIENCE_CHOICES, default='BEGINNER')
    
    LOCATION_CHOICES = [
        ('HOME', 'Home'),
        ('GYM', 'Gym'),
        ('OUTDOOR', 'Outdoor'),
    ]
    training_location = models.CharField(max_length=20, choices=LOCATION_CHOICES, default='HOME')
    
    days_per_week = models.IntegerField(default=3, help_text="Workout days per week")
    time_available = models.IntegerField(default=30, help_text="Minutes per workout")
    
    # Subscription
    SUBSCRIPTION_CHOICES = [
        ('FREE', 'Free'),
        ('PREMIUM', 'Premium'),
        ('PRO', 'Pro'),
    ]
    subscription_tier = models.CharField(max_length=20, choices=SUBSCRIPTION_CHOICES, default='FREE')
    subscription_end_date = models.DateTimeField(null=True, blank=True)
    stripe_customer_id = models.CharField(max_length=100, null=True, blank=True)
    stripe_subscription_id = models.CharField(max_length=100, null=True, blank=True)
    
    # Stats
    streak_days = models.IntegerField(default=0)
    total_workouts = models.IntegerField(default=0)
    total_minutes = models.IntegerField(default=0)
    last_workout_date = models.DateField(null=True, blank=True)
    
    # Onboarding
    onboarding_completed = models.BooleanField(default=False)
    onboarding_completed_at = models.DateTimeField(null=True, blank=True)
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    last_active = models.DateTimeField(auto_now=True)
    
    # Fix the reverse accessor clashes by adding related_name
    groups = models.ManyToManyField(
        'auth.Group',
        verbose_name='groups',
        blank=True,
        help_text='The groups this user belongs to.',
        related_name='accounts_user_set',
        related_query_name='accounts_user',
    )
    user_permissions = models.ManyToManyField(
        'auth.Permission',
        verbose_name='user permissions',
        blank=True,
        help_text='Specific permissions for this user.',
        related_name='accounts_user_set',
        related_query_name='accounts_user',
    )
    
    class Meta:
        ordering = ['-date_joined']
        indexes = [
            models.Index(fields=['email']),
            models.Index(fields=['stripe_customer_id']),
        ]
    
    def __str__(self):
        return f"{self.username} - {self.email}"
    
    def is_premium(self):
        if self.subscription_tier == 'FREE':
            return False
        if self.subscription_end_date and self.subscription_end_date > timezone.now():
            return True
        return False
    
    def get_streak_text(self):
        if self.streak_days >= 30:
            return "Legendary Streak"
        elif self.streak_days >= 14:
            return "Great Streak"
        elif self.streak_days >= 7:
            return "Good Streak"
        return "Keep Going"


class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    bio = models.TextField(max_length=500, blank=True)
    avatar = models.ImageField(upload_to='avatars/', null=True, blank=True)
    push_notifications_enabled = models.BooleanField(default=True)
    email_notifications_enabled = models.BooleanField(default=True)
    workout_reminder_time = models.TimeField(null=True, blank=True)
    meal_reminder_time = models.TimeField(null=True, blank=True)
    
    # Privacy settings
    PROFILE_VISIBILITY_CHOICES = [
        ('PUBLIC', 'Public'),
        ('FRIENDS', 'Friends Only'),
        ('PRIVATE', 'Private'),
    ]
    profile_visibility = models.CharField(max_length=20, choices=PROFILE_VISIBILITY_CHOICES, default='PUBLIC')
    show_on_leaderboard = models.BooleanField(default=True)
    
    # Dietary preferences
    dietary_preferences = models.JSONField(default=dict, blank=True, help_text="Dietary preferences like vegetarian, vegan, etc.")
    allergies = models.TextField(blank=True, help_text="Food allergies")
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.user.username}'s profile"


class UserMetric(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='metrics')
    date = models.DateField(default=timezone.now)
    weight = models.FloatField(null=True, blank=True, help_text="Weight in kg")
    body_fat = models.FloatField(null=True, blank=True, help_text="Body fat percentage")
    muscle_mass = models.FloatField(null=True, blank=True, help_text="Muscle mass in kg")
    waist_circumference = models.FloatField(null=True, blank=True, help_text="Waist in cm")
    hip_circumference = models.FloatField(null=True, blank=True, help_text="Hip in cm")
    notes = models.TextField(blank=True)
    
    class Meta:
        unique_together = ['user', 'date']
        ordering = ['-date']
    
    def __str__(self):
        return f"{self.user.username} - {self.date}"


class UserActivityLog(models.Model):
    """Track user activity for analytics"""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='activity_logs')
    activity_type = models.CharField(max_length=50, choices=[
        ('LOGIN', 'Login'),
        ('WORKOUT_START', 'Workout Started'),
        ('WORKOUT_COMPLETE', 'Workout Completed'),
        ('MEAL_LOG', 'Meal Logged'),
        ('SOCIAL_INTERACTION', 'Social Interaction'),
        ('PAYMENT', 'Payment Made'),
    ])
    metadata = models.JSONField(default=dict, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['activity_type']),
        ]
    
    def __str__(self):
        return f"{self.user.username} - {self.activity_type} - {self.created_at}"
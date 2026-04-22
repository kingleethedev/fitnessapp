from django.db import models
from django.conf import settings
from django.utils import timezone
import uuid

class MealCategory(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=50)
    display_order = models.IntegerField(default=0)
    
    def __str__(self):
        return self.name
    
    class Meta:
        ordering = ['display_order']
        verbose_name_plural = "Meal Categories"

class MealItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=200)
    category = models.ForeignKey(MealCategory, on_delete=models.CASCADE, related_name='meals')
    
    # Nutritional info
    calories = models.IntegerField(null=True, blank=True)
    protein = models.FloatField(null=True, blank=True, help_text="Grams")
    carbs = models.FloatField(null=True, blank=True, help_text="Grams")
    fats = models.FloatField(null=True, blank=True, help_text="Grams")
    fiber = models.FloatField(null=True, blank=True, help_text="Grams")
    
    # Preparation
    preparation_time = models.IntegerField(null=True, blank=True, help_text="Minutes")
    ingredients = models.TextField(blank=True, help_text="Comma separated list")
    instructions = models.TextField(blank=True)
    
    # Dietary tags
    is_vegetarian = models.BooleanField(default=False)
    is_vegan = models.BooleanField(default=False)
    is_gluten_free = models.BooleanField(default=False)
    is_dairy_free = models.BooleanField(default=False)
    is_high_protein = models.BooleanField(default=False)
    is_low_carb = models.BooleanField(default=False)
    
    # Meal type
    MEAL_TYPE_CHOICES = [
        ('BREAKFAST', 'Breakfast'),
        ('SNACK', 'Snack'),
        ('LUNCH', 'Lunch'),
        ('DINNER', 'Dinner'),
    ]
    meal_type = models.CharField(max_length=20, choices=MEAL_TYPE_CHOICES)
    
    image = models.ImageField(upload_to='meal_images/', null=True, blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"{self.name} ({self.get_meal_type_display()})"

class MealPlan(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='meal_plans')
    
    # Plan details
    week_start_date = models.DateField()
    week_end_date = models.DateField()
    
    GOAL_CHOICES = [
        ('WEIGHT_LOSS', 'Weight Loss'),
        ('MUSCLE_GAIN', 'Muscle Gain'),
        ('MAINTENANCE', 'Maintenance'),
        ('HEALTHY_EATING', 'Healthy Eating'),
    ]
    goal = models.CharField(max_length=20, choices=GOAL_CHOICES, default='HEALTHY_EATING')
    
    # Daily calories target
    target_calories = models.IntegerField(default=2000)
    target_protein = models.IntegerField(default=150, help_text="Grams")
    target_carbs = models.IntegerField(default=200, help_text="Grams")
    target_fats = models.IntegerField(default=55, help_text="Grams")
    
    # Generated meal plan data (JSON structure)
    meals = models.JSONField(default=dict, help_text="Structured meal plan for the week")
    
    # Tracking
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.user.username} - Week of {self.week_start_date}"
    
    class Meta:
        ordering = ['-week_start_date']
        unique_together = ['user', 'week_start_date']

class DailyMealLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='meal_logs')
    meal_plan = models.ForeignKey(MealPlan, on_delete=models.CASCADE, related_name='logs', null=True, blank=True)
    
    date = models.DateField(default=timezone.now)
    meal_type = models.CharField(max_length=20, choices=MealItem.MEAL_TYPE_CHOICES)
    
    # Meal details
    meal_item = models.ForeignKey(MealItem, on_delete=models.SET_NULL, null=True, blank=True)
    custom_meal_name = models.CharField(max_length=200, blank=True, null=True)  # Changed to allow null
    custom_calories = models.IntegerField(null=True, blank=True)
    
    # Completion tracking
    is_completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)
    
    # User feedback
    rating = models.IntegerField(null=True, blank=True, choices=[(i, i) for i in range(1, 6)])
    notes = models.TextField(blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)

class FavoriteMeal(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='favorite_meals')
    meal_item = models.ForeignKey(MealItem, on_delete=models.CASCADE)
    added_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ['user', 'meal_item']
    
    def __str__(self):
        return f"{self.user.username} - {self.meal_item.name}"
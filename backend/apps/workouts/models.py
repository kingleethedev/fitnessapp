from django.db import models
from django.conf import settings
from django.utils import timezone
import uuid


# =========================
# SHARED CHOICES (CLEAN)
# =========================

class Goal(models.TextChoices):
    WEIGHT_LOSS = "weight_loss", "Weight Loss"
    MUSCLE_GAIN = "muscle_gain", "Muscle Gain"
    ENDURANCE = "endurance", "Endurance"
    STRENGTH = "strength", "Strength"


class ExperienceLevel(models.TextChoices):
    BEGINNER = "beginner", "Beginner"
    INTERMEDIATE = "intermediate", "Intermediate"
    ADVANCED = "advanced", "Advanced"


class TrainingLocation(models.TextChoices):
    GYM = "gym", "Gym"
    HOME = "home", "Home"
    OUTDOOR = "outdoor", "Outdoor"


# =========================
# WORKOUT MODEL
# =========================

class Workout(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='workouts')
    date = models.DateField(default=timezone.now)
    duration = models.IntegerField(help_text="Duration in minutes")
    exercises = models.JSONField(help_text="List of exercises with details")

    difficulty_score = models.FloatField(default=0.5)
    intensity_level = models.IntegerField(default=1, choices=[(i, i) for i in range(1, 6)])

    is_completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)

    calories_burned = models.IntegerField(null=True, blank=True)
    satisfaction_rating = models.IntegerField(null=True, blank=True, choices=[(i, i) for i in range(1, 6)])

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-date']
        indexes = [
            models.Index(fields=['user', 'date']),
            models.Index(fields=['user', 'is_completed']),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.date}"


# =========================
# WORKOUT LOGS
# =========================

class WorkoutLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    workout = models.ForeignKey(Workout, on_delete=models.CASCADE, related_name='logs')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)

    exercise_name = models.CharField(max_length=100)

    target_reps = models.IntegerField(null=True, blank=True)
    actual_reps = models.IntegerField(null=True, blank=True)

    target_duration = models.IntegerField(null=True, blank=True, help_text="Seconds")
    actual_duration = models.IntegerField(null=True, blank=True, help_text="Seconds")

    completed = models.BooleanField(default=False)
    difficulty_rating = models.IntegerField(null=True, blank=True, choices=[(i, i) for i in range(1, 6)])

    notes = models.TextField(blank=True)
    logged_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.exercise_name} - {self.workout.date}"


# =========================
# TEMPLATE WORKOUTS
# =========================

class TemplateWorkout(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    name = models.CharField(max_length=100)
    description = models.TextField()

    goal = models.CharField(max_length=20, choices=Goal.choices)
    experience_level = models.CharField(max_length=20, choices=ExperienceLevel.choices)
    training_location = models.CharField(max_length=20, choices=TrainingLocation.choices)

    exercises = models.JSONField()
    default_duration = models.IntegerField(help_text="Duration in minutes")

    is_active = models.BooleanField(default=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True
    )

    created_at = models.DateTimeField(auto_now_add=True)
    image = models.ImageField(upload_to='workout_images/', null=True, blank=True)

    def __str__(self):
        return f"{self.name} - {self.goal} - {self.experience_level}"
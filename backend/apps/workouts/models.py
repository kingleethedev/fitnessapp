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
# EXERCISE LIBRARY (NEW)
# =========================

class Exercise(models.Model):
    """Master library of exercises that admins can manage with videos"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    
    # Basic info
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(blank=True)
    
    # Video - support both URL and uploaded file
    video_url = models.URLField(blank=True, null=True, help_text="YouTube/Vimeo URL or direct video URL")
    video_file = models.FileField(upload_to='exercise_videos/', blank=True, null=True)
    
    # Media thumbnails
    thumbnail = models.ImageField(upload_to='exercise_thumbnails/', blank=True, null=True)
    
    # Categories
    primary_goal = models.CharField(max_length=20, choices=Goal.choices, blank=True, null=True)
    experience_level = models.CharField(max_length=20, choices=ExperienceLevel.choices, default='beginner')
    training_location = models.CharField(max_length=20, choices=TrainingLocation.choices, default='home')
    
    # Metadata
    equipment_needed = models.CharField(max_length=200, blank=True, help_text="Comma separated equipment")
    calories_per_minute = models.FloatField(default=8.0, help_text="Estimated calories burned per minute")
    
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['name']
        indexes = [
            models.Index(fields=['primary_goal', 'is_active']),
            models.Index(fields=['training_location', 'experience_level']),
        ]
    
    def get_video_url(self):
        """Get the best available video URL"""
        if self.video_file and hasattr(self.video_file, 'url'):
            return self.video_file.url
        return self.video_url
    
    def has_video(self):
        """Check if exercise has any video source"""
        return bool(self.get_video_url())
    
    def __str__(self):
        return self.name


# =========================
# WORKOUT MODEL (UPDATED)
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
    
    def get_exercises_with_videos(self):
        """Process exercises JSON and add video URLs if available"""
        exercises_with_video = []
        
        for exercise in self.exercises:
            # Make a copy to avoid modifying original
            exercise_copy = exercise.copy() if isinstance(exercise, dict) else {'name': str(exercise)}
            
            # Check if exercise has video reference by ID
            if 'exercise_id' in exercise_copy:
                try:
                    db_exercise = Exercise.objects.get(id=exercise_copy['exercise_id'])
                    exercise_copy['video_url'] = db_exercise.get_video_url()
                    exercise_copy['thumbnail'] = db_exercise.thumbnail.url if db_exercise.thumbnail else None
                    exercise_copy['description'] = db_exercise.description
                    exercise_copy['has_video'] = db_exercise.has_video()
                except Exercise.DoesNotExist:
                    exercise_copy['video_url'] = None
                    exercise_copy['has_video'] = False
            else:
                # Fallback: try to find by name
                try:
                    db_exercise = Exercise.objects.get(name__iexact=exercise_copy.get('name', ''))
                    exercise_copy['video_url'] = db_exercise.get_video_url()
                    exercise_copy['thumbnail'] = db_exercise.thumbnail.url if db_exercise.thumbnail else None
                    exercise_copy['exercise_id'] = str(db_exercise.id)
                    exercise_copy['has_video'] = db_exercise.has_video()
                except Exercise.DoesNotExist:
                    exercise_copy['video_url'] = None
                    exercise_copy['has_video'] = False
            
            exercises_with_video.append(exercise_copy)
        
        return exercises_with_video


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
# TEMPLATE WORKOUTS (UPDATED)
# =========================

class TemplateWorkout(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)

    name = models.CharField(max_length=100)
    description = models.TextField()

    goal = models.CharField(max_length=20, choices=Goal.choices)
    experience_level = models.CharField(max_length=20, choices=ExperienceLevel.choices)
    training_location = models.CharField(max_length=20, choices=TrainingLocation.choices)

    exercises = models.JSONField(help_text="List of exercises with details")
    default_duration = models.IntegerField(help_text="Duration in minutes")

    is_active = models.BooleanField(default=True)

    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True
    )

    created_at = models.DateTimeField(auto_now_add=True)
    image = models.CharField(max_length=500, blank=True, null=True, help_text="Image URL")

    def __str__(self):
        return f"{self.name} - {self.goal} - {self.experience_level}"
    
    def get_exercises_with_videos(self):
        """Get template exercises with video URLs from the Exercise library"""
        exercises_with_video = []
        
        for exercise in self.exercises:
            exercise_copy = exercise.copy() if isinstance(exercise, dict) else {'name': str(exercise)}
            
            # Try to find matching exercise in database
            try:
                db_exercise = Exercise.objects.get(name__iexact=exercise_copy.get('name', ''))
                exercise_copy['video_url'] = db_exercise.get_video_url()
                exercise_copy['thumbnail'] = db_exercise.thumbnail.url if db_exercise.thumbnail else None
                exercise_copy['exercise_id'] = str(db_exercise.id)
                exercise_copy['has_video'] = db_exercise.has_video()
            except Exercise.DoesNotExist:
                exercise_copy['video_url'] = None
                exercise_copy['has_video'] = False
            
            exercises_with_video.append(exercise_copy)
        
        return exercises_with_video


# =========================
# TEMPLATE WORKOUT EXERCISES (NEW - OPTIONAL FOR BETTER STRUCTURE)
# =========================

class TemplateWorkoutExercise(models.Model):
    """Link between template workout and exercises with specific parameters (optional - use if you want to migrate from JSON)"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    template = models.ForeignKey(TemplateWorkout, on_delete=models.CASCADE, related_name='template_exercises')
    exercise = models.ForeignKey(Exercise, on_delete=models.CASCADE, related_name='template_uses')
    
    # Exercise-specific parameters
    sets = models.IntegerField(default=3)
    reps = models.IntegerField(null=True, blank=True)
    duration_seconds = models.IntegerField(null=True, blank=True, help_text="For timed exercises")
    rest_seconds = models.IntegerField(default=30)
    order = models.IntegerField(default=0)
    
    class Meta:
        ordering = ['order']
        unique_together = ['template', 'exercise', 'order']
    
    def get_exercise_data(self):
        """Return exercise data with video info"""
        return {
            'name': self.exercise.name,
            'description': self.exercise.description,
            'video_url': self.exercise.get_video_url(),
            'thumbnail': self.exercise.thumbnail.url if self.exercise.thumbnail else None,
            'sets': self.sets,
            'reps': self.reps,
            'duration': self.duration_seconds,
            'rest': self.rest_seconds,
            'calories_per_minute': self.exercise.calories_per_minute,
            'has_video': self.exercise.has_video(),
        }
    
    def __str__(self):
        return f"{self.exercise.name} in {self.template.name}"
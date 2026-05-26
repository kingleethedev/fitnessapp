# workout_engine.py
import random
from .models import Exercise, Goal, ExperienceLevel, TrainingLocation

class WorkoutGenerator:
    def __init__(self):
        """Initialize the workout generator"""
        self.exercise_cache = {}
    
    def generate_workout(self, user, data):
        """
        Generate workout prioritizing database exercises with videos
        Falls back to simple template if no database exercises available
        """
        
        goal = data.get("goal", "general")
        experience = data.get("experience_level", "beginner")
        location = data.get("training_location", "home")
        duration = data.get("time_available", 45)
        
        # Try to get exercises from database first
        db_exercises = self._get_exercises_from_database(goal, experience, location)
        
        if db_exercises and len(db_exercises) > 0:
            # Build workout from database exercises
            return self._build_workout_from_db_exercises(
                db_exercises, 
                duration, 
                experience
            )
        else:
            # Fallback to hardcoded exercises
            return self._get_fallback_workout(goal, experience, location, duration)
    
    def _get_exercises_from_database(self, goal, experience, location, limit=8):
        """
        Get exercises from database that match criteria and have videos
        """
        # Map string goals to Goal enum
        goal_mapping = {
            'FAT_LOSS': Goal.WEIGHT_LOSS,
            'WEIGHT_LOSS': Goal.WEIGHT_LOSS,
            'MUSCLE_GAIN': Goal.MUSCLE_GAIN,
            'FITNESS': Goal.ENDURANCE,
            'ENDURANCE': Goal.ENDURANCE,
            'STRENGTH': Goal.STRENGTH,
            'general': None
        }
        
        mapped_goal = goal_mapping.get(goal.upper(), None)
        
        # Map experience level
        exp_mapping = {
            'BEGINNER': ExperienceLevel.BEGINNER,
            'INTERMEDIATE': ExperienceLevel.INTERMEDIATE,
            'ADVANCED': ExperienceLevel.ADVANCED,
            'beginner': ExperienceLevel.BEGINNER,
            'intermediate': ExperienceLevel.INTERMEDIATE,
            'advanced': ExperienceLevel.ADVANCED,
        }
        
        mapped_exp = exp_mapping.get(experience.lower(), ExperienceLevel.BEGINNER)
        
        # Map location
        loc_mapping = {
            'HOME': TrainingLocation.HOME,
            'GYM': TrainingLocation.GYM,
            'OUTDOOR': TrainingLocation.OUTDOOR,
            'home': TrainingLocation.HOME,
            'gym': TrainingLocation.GYM,
            'outdoor': TrainingLocation.OUTDOOR,
        }
        
        mapped_loc = loc_mapping.get(location.lower(), TrainingLocation.HOME)
        
        # Query database for exercises
        queryset = Exercise.objects.filter(
            is_active=True,
            training_location=mapped_loc
        ).exclude(
            video_url__isnull=True, 
            video_file__isnull=True  # Must have at least one video source
        )
        
        # Filter by goal if specified
        if mapped_goal:
            queryset = queryset.filter(primary_goal=mapped_goal)
        
        # Filter by experience level (include beginner and user's level)
        experience_levels = [ExperienceLevel.BEGINNER]
        if mapped_exp == ExperienceLevel.INTERMEDIATE:
            experience_levels.append(ExperienceLevel.INTERMEDIATE)
        elif mapped_exp == ExperienceLevel.ADVANCED:
            experience_levels.extend([ExperienceLevel.INTERMEDIATE, ExperienceLevel.ADVANCED])
        
        queryset = queryset.filter(experience_level__in=experience_levels)
        
        # Randomize and limit
        exercises = list(queryset)
        random.shuffle(exercises)
        
        return exercises[:limit]
    
    def _build_workout_from_db_exercises(self, exercises, target_duration, experience_level):
        """
        Build workout structure from database exercise objects
        """
        workout_exercises = []
        total_time_seconds = 0
        estimated_calories = 0
        
        # Adjust sets based on experience level
        sets_multiplier = {
            'BEGINNER': 2,
            'INTERMEDIATE': 3,
            'ADVANCED': 4
        }
        sets = sets_multiplier.get(experience_level.upper(), 3)
        
        for ex in exercises:
            # Determine if exercise should be rep-based or time-based
            # Strength goals -> reps, cardio/endurance -> time
            is_reps_based = ex.primary_goal in [Goal.STRENGTH, Goal.MUSCLE_GAIN]
            
            # Calculate reps or duration
            if is_reps_based:
                reps = self._calculate_reps(ex, experience_level)
                time_per_set_seconds = reps * 2  # Approx 2 seconds per rep
                exercise_data = {
                    'name': ex.name,
                    'description': ex.description,
                    'exercise_id': str(ex.id),
                    'video_url': ex.get_video_url(),
                    'thumbnail': ex.thumbnail.url if ex.thumbnail else None,
                    'has_video': ex.has_video(),
                    'sets': sets,
                    'reps': reps,
                    'duration': None,
                    'rest_seconds': 30,
                    'calories_per_minute': ex.calories_per_minute,
                }
            else:
                duration_seconds = self._calculate_duration(ex, experience_level)
                time_per_set_seconds = duration_seconds
                exercise_data = {
                    'name': ex.name,
                    'description': ex.description,
                    'exercise_id': str(ex.id),
                    'video_url': ex.get_video_url(),
                    'thumbnail': ex.thumbnail.url if ex.thumbnail else None,
                    'has_video': ex.has_video(),
                    'sets': sets,
                    'reps': None,
                    'duration': duration_seconds,
                    'rest_seconds': 20,
                    'calories_per_minute': ex.calories_per_minute,
                }
            
            # Calculate total time for this exercise
            exercise_total_time = (time_per_set_seconds + exercise_data['rest_seconds']) * sets
            total_time_seconds += exercise_total_time
            
            # Calculate calories
            minutes = exercise_total_time / 60
            estimated_calories += minutes * ex.calories_per_minute
            
            workout_exercises.append(exercise_data)
            
            # Stop if we've reached target duration
            if total_time_seconds / 60 >= target_duration:
                break
        
        # Calculate difficulty score based on experience and exercises
        difficulty_score = self._calculate_difficulty(experience_level, len(workout_exercises))
        
        # Calculate intensity level (1-5)
        intensity_level = self._calculate_intensity(experience_level, sets)
        
        return {
            "duration": max(20, int(total_time_seconds / 60)),  # Convert to minutes
            "exercises": workout_exercises,
            "difficulty_score": difficulty_score,
            "intensity_level": intensity_level,
            "calories_estimate": int(estimated_calories),
            "source": "database_exercises"
        }
    
    def _calculate_reps(self, exercise, experience_level):
        """Calculate appropriate reps based on experience"""
        rep_ranges = {
            'BEGINNER': (8, 12),
            'INTERMEDIATE': (12, 15),
            'ADVANCED': (15, 20)
        }
        min_reps, max_reps = rep_ranges.get(experience_level.upper(), (10, 15))
        return random.randint(min_reps, max_reps)
    
    def _calculate_duration(self, exercise, experience_level):
        """Calculate appropriate duration in seconds"""
        duration_ranges = {
            'BEGINNER': (20, 30),
            'INTERMEDIATE': (30, 45),
            'ADVANCED': (45, 60)
        }
        min_dur, max_dur = duration_ranges.get(experience_level.upper(), (25, 40))
        return random.randint(min_dur, max_dur)
    
    def _calculate_difficulty(self, experience_level, num_exercises):
        """Calculate difficulty score (0-1)"""
        base_difficulty = {
            'BEGINNER': 0.3,
            'INTERMEDIATE': 0.6,
            'ADVANCED': 0.8
        }
        difficulty = base_difficulty.get(experience_level.upper(), 0.5)
        
        # Adjust based on number of exercises
        if num_exercises > 6:
            difficulty = min(1.0, difficulty + 0.1)
        elif num_exercises < 4:
            difficulty = max(0.1, difficulty - 0.1)
        
        return round(difficulty, 2)
    
    def _calculate_intensity(self, experience_level, sets):
        """Calculate intensity level (1-5)"""
        intensity_map = {
            'BEGINNER': 2,
            'INTERMEDIATE': 3,
            'ADVANCED': 4
        }
        intensity = intensity_map.get(experience_level.upper(), 2)
        
        # Adjust based on sets
        if sets >= 4:
            intensity = min(5, intensity + 1)
        
        return intensity
    
    def _get_fallback_workout(self, goal, experience, location, duration):
        """
        Fallback hardcoded workout when no database exercises are available
        Includes placeholder video URLs that you can replace
        """
        
        # Placeholder video URLs (replace with your own default videos)
        default_videos = {
            'pushups': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
            'squats': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
            'lunges': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFunflies.mp4',
            'plank': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
            'jumping_jacks': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
            'burpees': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
            'high_knees': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4',
            'mountain_climbers': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
        }
        
        # Basic exercise templates based on goal
        if goal == 'FAT_LOSS':
            exercises = [
                {"name": "Jumping Jacks", "sets": 3, "duration": 45, "rest": 15, 
                 "video_url": default_videos['jumping_jacks'], "has_video": True},
                {"name": "Burpees", "sets": 3, "reps": 12, "rest": 20,
                 "video_url": default_videos['burpees'], "has_video": True},
                {"name": "High Knees", "sets": 3, "duration": 45, "rest": 15,
                 "video_url": default_videos['high_knees'], "has_video": True},
                {"name": "Mountain Climbers", "sets": 3, "duration": 45, "rest": 15,
                 "video_url": default_videos['mountain_climbers'], "has_video": True},
            ]
        elif goal == 'MUSCLE_GAIN':
            exercises = [
                {"name": "Push Ups", "sets": 3, "reps": 12, "rest": 45,
                 "video_url": default_videos['pushups'], "has_video": True},
                {"name": "Squats", "sets": 3, "reps": 15, "rest": 45,
                 "video_url": default_videos['squats'], "has_video": True},
                {"name": "Lunges", "sets": 3, "reps": 12, "rest": 45,
                 "video_url": default_videos['lunges'], "has_video": True},
                {"name": "Plank", "sets": 3, "duration": 45, "rest": 30,
                 "video_url": default_videos['plank'], "has_video": True},
            ]
        else:  # FITNESS / general
            exercises = [
                {"name": "Push Ups", "sets": 3, "reps": 10, "rest": 30,
                 "video_url": default_videos['pushups'], "has_video": True},
                {"name": "Squats", "sets": 3, "reps": 15, "rest": 30,
                 "video_url": default_videos['squats'], "has_video": True},
                {"name": "Plank", "sets": 3, "duration": 30, "rest": 20,
                 "video_url": default_videos['plank'], "has_video": True},
                {"name": "Lunges", "sets": 3, "reps": 12, "rest": 30,
                 "video_url": default_videos['lunges'], "has_video": True},
            ]
        
        # Adjust for experience level
        difficulty_score = 0.5
        intensity_level = 2
        
        if experience == "intermediate":
            difficulty_score = 0.7
            intensity_level = 3
            # Add more sets
            for ex in exercises:
                ex['sets'] = 4
        elif experience == "advanced":
            difficulty_score = 0.9
            intensity_level = 4
            for ex in exercises:
                ex['sets'] = 5
        
        return {
            "duration": duration,
            "exercises": exercises,
            "difficulty_score": difficulty_score,
            "intensity_level": intensity_level,
            "calories_estimate": duration * 8,  # Rough estimate
            "source": "fallback_hardcoded"
        }
    
    def get_video_status(self):
        """Get status of videos in the database"""
        total = Exercise.objects.filter(is_active=True).count()
        with_video = Exercise.objects.exclude(
            video_url__isnull=True, video_file__isnull=True
        ).count()
        
        return {
            'total_exercises': total,
            'exercises_with_video': with_video,
            'has_videos': with_video > 0,
            'coverage_percentage': (with_video / total * 100) if total > 0 else 0
        }
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from datetime import timedelta
from django.db.models import Count, Avg, Sum
from .models import Workout, WorkoutLog, TemplateWorkout, Exercise
from .serializers import (
    WorkoutSerializer, WorkoutLogSerializer, TemplateWorkoutSerializer,
    WorkoutGenerateSerializer, WorkoutCompleteSerializer, ExerciseSerializer,
    VideoStatusSerializer
)
from .workout_engine import WorkoutGenerator
from .adaptive_logic import AdaptiveLogicEngine


class WorkoutViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.generator = WorkoutGenerator()
    
    def _get_generated_workout(self, user, duration=None):
        """Generate a workout based on user's goal - fallback when no templates exist"""
        if duration is None:
            duration = user.time_available or 30
        
        exercises = []
        if user.goal == 'FAT_LOSS':
            exercises = [
                {'name': 'Jumping Jacks', 'duration': 45, 'rest': 15, 'sets': 3},
                {'name': 'Burpees', 'reps': 12, 'rest': 20, 'sets': 3},
                {'name': 'High Knees', 'duration': 45, 'rest': 15, 'sets': 3},
                {'name': 'Mountain Climbers', 'duration': 45, 'rest': 15, 'sets': 3},
            ]
        elif user.goal == 'MUSCLE_GAIN':
            exercises = [
                {'name': 'Push Ups', 'reps': 12, 'rest': 45, 'sets': 3},
                {'name': 'Squats', 'reps': 15, 'rest': 45, 'sets': 3},
                {'name': 'Pull Ups', 'reps': 8, 'rest': 45, 'sets': 3},
                {'name': 'Dips', 'reps': 10, 'rest': 45, 'sets': 3},
            ]
        else:  # FITNESS
            exercises = [
                {'name': 'Push Ups', 'reps': 10, 'rest': 30, 'sets': 3},
                {'name': 'Squats', 'reps': 15, 'rest': 30, 'sets': 3},
                {'name': 'Plank', 'duration': 30, 'rest': 20, 'sets': 3},
                {'name': 'Lunges', 'reps': 12, 'rest': 30, 'sets': 3},
            ]
        
        return {
            'duration': duration,
            'exercises': exercises,
            'difficulty_score': 0.5,
            'intensity_level': 1,
        }
    
    def _get_random_template(self):
        """Get a random active template from the database"""
        templates = TemplateWorkout.objects.filter(is_active=True)
        if templates.exists():
            import random
            return random.choice(templates)
        return None
    
    def _enhance_exercises_with_videos(self, exercises):
        """Add video URLs to exercises list"""
        enhanced = []
        for exercise in exercises:
            exercise_copy = exercise.copy() if isinstance(exercise, dict) else {'name': str(exercise)}
            
            # Try to find video from Exercise library
            try:
                db_exercise = Exercise.objects.get(name__iexact=exercise_copy.get('name', ''))
                exercise_copy['video_url'] = db_exercise.get_video_url()
                exercise_copy['thumbnail'] = db_exercise.thumbnail.url if db_exercise.thumbnail else None
                exercise_copy['exercise_id'] = str(db_exercise.id)
                exercise_copy['has_video'] = db_exercise.has_video()
                exercise_copy['description'] = db_exercise.description
            except Exercise.DoesNotExist:
                exercise_copy['video_url'] = None
                exercise_copy['has_video'] = False
            
            enhanced.append(exercise_copy)
        
        return enhanced
    
    @action(detail=False, methods=['GET'])
    def today(self, request):
        """Get today's workout - prioritizes database exercises with videos, then admin templates, then fallback"""
        today = timezone.now().date()
        
        # Check if there's already a workout for today
        workout = Workout.objects.filter(
            user=request.user,
            date=today
        ).first()
        
        if not workout:
            # FIRST: Try to generate from database exercises with videos
            user_data = {
                'goal': request.user.goal,
                'experience_level': getattr(request.user, 'experience_level', 'beginner'),
                'training_location': 'home',  # You can make this dynamic based on user preference
                'time_available': getattr(request.user, 'time_available', 30)
            }
            
            db_workout = self.generator.generate_workout(request.user, user_data)
            
            # Check if we got exercises from database and they have videos
            if db_workout and db_workout.get('source') == 'database_exercises' and len(db_workout.get('exercises', [])) > 0:
                workout = Workout.objects.create(
                    user=request.user,
                    date=today,
                    duration=db_workout['duration'],
                    exercises=db_workout['exercises'],
                    difficulty_score=db_workout['difficulty_score'],
                    intensity_level=db_workout['intensity_level'],
                    is_completed=False
                )
                print(f"✅ Using database exercises with videos ({len(db_workout['exercises'])} exercises)")
            
            else:
                # SECOND: Try to get an admin template and enhance with videos
                template = self._get_random_template()
                
                if template:
                    # Enhance template exercises with video URLs
                    enhanced_exercises = self._enhance_exercises_with_videos(template.exercises)
                    
                    workout = Workout.objects.create(
                        user=request.user,
                        date=today,
                        duration=template.default_duration,
                        exercises=enhanced_exercises,
                        difficulty_score=0.5,
                        intensity_level=2,
                        is_completed=False
                    )
                    print(f"✅ Using admin template with videos: {template.name}")
                
                else:
                    # THIRD: Fallback to hardcoded generated workout
                    generated = self._get_generated_workout(request.user)
                    # Try to add videos to fallback exercises
                    enhanced_exercises = self._enhance_exercises_with_videos(generated['exercises'])
                    
                    workout = Workout.objects.create(
                        user=request.user,
                        date=today,
                        duration=generated['duration'],
                        exercises=enhanced_exercises,
                        difficulty_score=generated['difficulty_score'],
                        intensity_level=generated['intensity_level'],
                        is_completed=False
                    )
                    print("⚠️ Using fallback workout (no database videos or admin templates)")
        
        # Use serializer that includes video URLs
        serializer = WorkoutSerializer(workout)
        return Response(serializer.data)
    
    @action(detail=False, methods=['POST'])
    def generate(self, request):
        """Generate a new workout - prioritizes database exercises with videos"""
        user = request.user
        duration = request.data.get('duration', user.time_available or 30)
        
        # Prepare user data for generator
        user_data = {
            'goal': request.data.get('goal', user.goal),
            'experience_level': request.data.get('experience_level', getattr(user, 'experience_level', 'beginner')),
            'training_location': request.data.get('training_location', 'home'),
            'time_available': duration
        }
        
        # Check if user wants to use specific template
        template_id = request.data.get('template_id')
        
        if template_id:
            # Use specific template
            try:
                template = TemplateWorkout.objects.get(id=template_id, is_active=True)
                enhanced_exercises = self._enhance_exercises_with_videos(template.exercises)
                
                workout = Workout.objects.create(
                    user=user,
                    duration=template.default_duration,
                    exercises=enhanced_exercises,
                    difficulty_score=0.5,
                    intensity_level=2,
                    is_completed=False
                )
                
                return Response({
                    'workout_id': str(workout.id),
                    'id': str(workout.id),
                    'duration': workout.duration,
                    'exercises': workout.get_exercises_with_videos(),
                    'difficulty_score': workout.difficulty_score,
                    'intensity_level': workout.intensity_level,
                    'from_template': template.name,
                    'has_videos': any(ex.get('has_video', False) for ex in workout.exercises)
                })
            except TemplateWorkout.DoesNotExist:
                pass
        
        # Generate from database or fallback
        generated = self.generator.generate_workout(user, user_data)
        
        workout = Workout.objects.create(
            user=user,
            duration=generated['duration'],
            exercises=generated['exercises'],
            difficulty_score=generated['difficulty_score'],
            intensity_level=generated['intensity_level'],
            is_completed=False
        )
        
        return Response({
            'workout_id': str(workout.id),
            'id': str(workout.id),
            'duration': workout.duration,
            'exercises': workout.get_exercises_with_videos(),
            'difficulty_score': workout.difficulty_score,
            'intensity_level': workout.intensity_level,
            'from_template': None,
            'source': generated.get('source', 'unknown'),
            'has_videos': any(ex.get('has_video', False) for ex in workout.exercises)
        })
    
    @action(detail=False, methods=['GET'])
    def available_templates(self, request):
        """Get all available admin templates with video info"""
        templates = TemplateWorkout.objects.filter(is_active=True)
        
        data = []
        for template in templates:
            template_data = {
                'id': str(template.id),
                'name': template.name,
                'description': template.description,
                'default_duration': template.default_duration,
                'goal': template.goal,
                'experience_level': template.experience_level,
                'training_location': template.training_location,
                'exercises_count': len(template.exercises) if template.exercises else 0,
                'has_videos': any(
                    Exercise.objects.filter(name__iexact=ex.get('name', '')).exists() 
                    for ex in (template.exercises or [])
                )
            }
            data.append(template_data)
        
        return Response({
            'templates': data,
            'total': len(data),
            'message': 'Select a template or use generated workouts'
        })
    
    @action(detail=False, methods=['POST'])
    def use_template(self, request):
        """Use a specific template by ID to create a workout with videos"""
        template_id = request.data.get('template_id')
        
        if not template_id:
            return Response({'error': 'template_id is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            template = TemplateWorkout.objects.get(id=template_id, is_active=True)
            
            # Enhance exercises with video URLs
            enhanced_exercises = self._enhance_exercises_with_videos(template.exercises)
            
            workout = Workout.objects.create(
                user=request.user,
                duration=template.default_duration,
                exercises=enhanced_exercises,
                difficulty_score=0.5,
                intensity_level=2,
                is_completed=False
            )
            
            return Response({
                'workout_id': str(workout.id),
                'id': str(workout.id),
                'duration': workout.duration,
                'exercises': workout.get_exercises_with_videos(),
                'difficulty_score': workout.difficulty_score,
                'intensity_level': workout.intensity_level,
                'template_name': template.name,
                'has_videos': any(ex.get('has_video', False) for ex in workout.exercises),
                'message': f'Workout created from template: {template.name}'
            })
        except TemplateWorkout.DoesNotExist:
            return Response({'error': 'Template not found'}, status=status.HTTP_404_NOT_FOUND)
    
    @action(detail=False, methods=['POST'])
    def complete(self, request):
        """Complete a workout and log results"""
        serializer = WorkoutCompleteSerializer(data=request.data)
        
        if serializer.is_valid():
            try:
                workout_id = serializer.validated_data.get('workout_id')
                workout = Workout.objects.get(
                    id=workout_id,
                    user=request.user
                )
                
                # Mark workout as completed
                workout.is_completed = True
                workout.completed_at = timezone.now()
                workout.satisfaction_rating = serializer.validated_data.get('satisfaction_rating')
                workout.save()
                
                # Save workout logs
                for log_data in serializer.validated_data.get('logs', []):
                    WorkoutLog.objects.create(
                        workout=workout,
                        user=request.user,
                        exercise_name=log_data.get('exercise_name'),
                        target_reps=log_data.get('target_reps'),
                        actual_reps=log_data.get('actual_reps'),
                        target_duration=log_data.get('target_duration'),
                        actual_duration=log_data.get('actual_duration'),
                        completed=log_data.get('completed', True),
                        difficulty_rating=log_data.get('difficulty_rating')
                    )
                
                # Update user stats
                request.user.total_workouts += 1
                request.user.total_minutes += workout.duration
                
                # Calculate calories burned (rough estimate: 8 calories per minute)
                calories_burned = workout.duration * 8
                workout.calories_burned = calories_burned
                workout.save()
                
                # Update streak
                today = timezone.now().date()
                if request.user.last_workout_date == today - timedelta(days=1):
                    request.user.streak_days += 1
                elif request.user.last_workout_date != today:
                    request.user.streak_days = 1
                request.user.last_workout_date = today
                request.user.save()
                
                return Response({
                    'status': 'completed',
                    'streak_days': request.user.streak_days,
                    'calories_burned': calories_burned,
                    'total_workouts': request.user.total_workouts,
                    'message': 'Workout completed successfully!'
                }, status=status.HTTP_200_OK)
                
            except Workout.DoesNotExist:
                return Response(
                    {'error': f'Workout with id {workout_id} not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            except Exception as e:
                return Response(
                    {'error': str(e)}, 
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['GET'])
    def history(self, request):
        """Get workout history with video info"""
        limit = int(request.query_params.get('limit', 30))
        
        workouts = Workout.objects.filter(
            user=request.user,
            is_completed=True
        ).order_by('-date')[:limit]
        
        serializer = WorkoutSerializer(workouts, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['GET'])
    def stats(self, request):
        """Get workout statistics"""
        thirty_days_ago = timezone.now().date() - timedelta(days=30)
        
        stats = Workout.objects.filter(
            user=request.user,
            is_completed=True,
            date__gte=thirty_days_ago
        ).aggregate(
            total_workouts=Count('id'),
            total_minutes=Sum('duration'),
            avg_difficulty=Avg('difficulty_score'),
            avg_intensity=Avg('intensity_level'),
            total_calories=Sum('calories_burned')
        )
        
        # Weekly breakdown
        weekly_workouts = []
        for i in range(4):
            week_start = thirty_days_ago + timedelta(days=i*7)
            week_end = week_start + timedelta(days=6)
            count = Workout.objects.filter(
                user=request.user,
                is_completed=True,
                date__gte=week_start,
                date__lte=week_end
            ).count()
            weekly_workouts.append({
                'week': i + 1,
                'start_date': week_start,
                'end_date': week_end,
                'count': count
            })
        
        return Response({
            'summary': {
                'total_workouts': stats['total_workouts'] or 0,
                'total_minutes': stats['total_minutes'] or 0,
                'avg_difficulty': round(stats['avg_difficulty'] or 0, 1),
                'avg_intensity': round(stats['avg_intensity'] or 0, 1),
                'total_calories': stats['total_calories'] or 0,
            },
            'weekly_breakdown': weekly_workouts,
            'current_streak': request.user.streak_days,
            'total_all_time': request.user.total_workouts
        })
    
    @action(detail=False, methods=['GET'])
    def check_templates(self, request):
        """Check if admin templates exist in the database"""
        template_count = TemplateWorkout.objects.filter(is_active=True).count()
        return Response({
            'has_templates': template_count > 0,
            'template_count': template_count,
            'message': f'Found {template_count} active admin templates. Users will get workouts from these templates.' if template_count > 0 else 'No admin templates found. Users will get generated workouts based on their goals.'
        })
    
    @action(detail=False, methods=['GET'])
    def video_status(self, request):
        """Get comprehensive video status for debugging"""
        video_status = self.generator.get_video_status()
        
        # Get template video coverage
        templates = TemplateWorkout.objects.filter(is_active=True)
        templates_with_videos = 0
        for template in templates:
            if any(Exercise.objects.filter(name__iexact=ex.get('name', '')).exists() for ex in (template.exercises or [])):
                templates_with_videos += 1
        
        return Response({
            'exercises': video_status,
            'templates': {
                'total': templates.count(),
                'have_videos': templates_with_videos,
                'coverage_percentage': (templates_with_videos / templates.count() * 100) if templates.count() > 0 else 0
            },
            'system_status': 'healthy' if video_status['has_videos'] else 'warning',
            'message': 'System will prioritize database exercises with videos' if video_status['has_videos'] else 'No videos found. Please add videos to exercises in admin panel.'
        })
    
    @action(detail=False, methods=['GET'])
    def debug_workout(self, request):
        """Debug endpoint to see what workout would be generated"""
        user_data = {
            'goal': request.user.goal,
            'experience_level': getattr(request.user, 'experience_level', 'beginner'),
            'training_location': 'home',
            'time_available': 30
        }
        
        generated = self.generator.generate_workout(request.user, user_data)
        
        return Response({
            'user_goal': request.user.goal,
            'generated_workout': {
                'source': generated.get('source'),
                'duration': generated['duration'],
                'exercise_count': len(generated['exercises']),
                'has_videos': any(ex.get('has_video', False) for ex in generated['exercises']),
                'exercises': generated['exercises']
            },
            'database_status': self.generator.get_video_status()
        })


class TemplateWorkoutViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated]
    queryset = TemplateWorkout.objects.filter(is_active=True)
    serializer_class = TemplateWorkoutSerializer
    
    @action(detail=True, methods=['POST'])
    def use_template(self, request, pk=None):
        """Use a template to create a workout with videos"""
        template = self.get_object()
        
        # Enhance exercises with video URLs
        enhanced_exercises = []
        for exercise in template.exercises:
            exercise_copy = exercise.copy() if isinstance(exercise, dict) else {'name': str(exercise)}
            
            # Try to find video
            try:
                db_exercise = Exercise.objects.get(name__iexact=exercise_copy.get('name', ''))
                exercise_copy['video_url'] = db_exercise.get_video_url()
                exercise_copy['thumbnail'] = db_exercise.thumbnail.url if db_exercise.thumbnail else None
                exercise_copy['exercise_id'] = str(db_exercise.id)
                exercise_copy['has_video'] = db_exercise.has_video()
            except Exercise.DoesNotExist:
                exercise_copy['video_url'] = None
                exercise_copy['has_video'] = False
            
            enhanced_exercises.append(exercise_copy)
        
        workout = Workout.objects.create(
            user=request.user,
            duration=template.default_duration,
            exercises=enhanced_exercises,
            difficulty_score=0.5,
            intensity_level=2,
            is_completed=False
        )
        
        return Response({
            'workout_id': str(workout.id),
            'id': str(workout.id),
            'duration': workout.duration,
            'exercises': workout.get_exercises_with_videos(),
            'template_name': template.name,
            'has_videos': any(ex.get('has_video', False) for ex in workout.exercises)
        })
    
    @action(detail=False, methods=['GET'])
    def list_all(self, request):
        """List all templates with more details including video info"""
        templates = TemplateWorkout.objects.filter(is_active=True)
        data = []
        for template in templates:
            # Check if template exercises have videos
            has_videos = False
            for ex in (template.exercises or []):
                if Exercise.objects.filter(name__iexact=ex.get('name', '')).exists():
                    has_videos = True
                    break
            
            data.append({
                'id': str(template.id),
                'name': template.name,
                'description': template.description,
                'duration': template.default_duration,
                'goal': template.goal,
                'experience_level': template.experience_level,
                'training_location': template.training_location,
                'exercises_count': len(template.exercises) if template.exercises else 0,
                'has_videos': has_videos,
                'image': template.image.url if template.image else None
            })
        
        return Response({
            'templates': data,
            'total': len(data)
        })


class ExerciseViewSet(viewsets.ModelViewSet):
    """ViewSet for managing exercises (admin only)"""
    permission_classes = [IsAuthenticated]
    serializer_class = ExerciseSerializer
    
    def get_queryset(self):
        """Allow filtering by goal, location, and experience level"""
        queryset = Exercise.objects.all()
        
        # Filter by goal
        goal = self.request.query_params.get('goal')
        if goal:
            queryset = queryset.filter(primary_goal=goal)
        
        # Filter by location
        location = self.request.query_params.get('location')
        if location:
            queryset = queryset.filter(training_location=location)
        
        # Filter by experience level
        experience = self.request.query_params.get('experience')
        if experience:
            queryset = queryset.filter(experience_level=experience)
        
        # Only show exercises with videos
        only_with_videos = self.request.query_params.get('only_with_videos', 'false').lower() == 'true'
        if only_with_videos:
            queryset = queryset.exclude(video_url__isnull=True, video_file__isnull=True)
        
        return queryset
    
    @action(detail=False, methods=['GET'])
    def by_goal(self, request):
        """Get exercises grouped by goal"""
        goals = ['weight_loss', 'muscle_gain', 'endurance', 'strength']
        result = {}
        
        for goal in goals:
            exercises = Exercise.objects.filter(primary_goal=goal, is_active=True)
            result[goal] = ExerciseSerializer(exercises, many=True).data
        
        return Response(result)
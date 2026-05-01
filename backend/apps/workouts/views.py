from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from datetime import timedelta
from django.db.models import Count, Avg, Sum
from .models import Workout, WorkoutLog, TemplateWorkout
from .serializers import (
    WorkoutSerializer, WorkoutLogSerializer, TemplateWorkoutSerializer,
    WorkoutGenerateSerializer, WorkoutCompleteSerializer
)
from .workout_engine import WorkoutGenerator
from .adaptive_logic import AdaptiveLogicEngine


class WorkoutViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    
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
            # Get random template
            import random
            return random.choice(templates)
        return None
    
    @action(detail=False, methods=['GET'])
    def today(self, request):
        """Get today's workout - prioritizes admin templates, falls back to generated"""
        today = timezone.now().date()
        
        # Check if there's already a workout for today
        workout = Workout.objects.filter(
            user=request.user,
            date=today
        ).first()
        
        if not workout:
            # FIRST: Try to get an admin template
            template = self._get_random_template()
            
            if template:
                # Use the admin template
                workout = Workout.objects.create(
                    user=request.user,
                    date=today,
                    duration=template.default_duration,
                    exercises=template.exercises,
                    difficulty_score=0.5,
                    intensity_level=2,
                    is_completed=False
                )
                print(f"✅ Using admin template: {template.name} (ID: {template.id})")
            else:
                # SECOND: Fall back to generated workout
                generated = self._get_generated_workout(request.user)
                workout = Workout.objects.create(
                    user=request.user,
                    date=today,
                    duration=generated['duration'],
                    exercises=generated['exercises'],
                    difficulty_score=generated['difficulty_score'],
                    intensity_level=generated['intensity_level'],
                    is_completed=False
                )
                print("✅ Using generated workout (no admin templates available)")
        
        serializer = WorkoutSerializer(workout)
        return Response(serializer.data)
    
    @action(detail=False, methods=['POST'])
    def generate(self, request):
        """Generate a new workout from template or dynamically"""
        user = request.user
        duration = request.data.get('duration', user.time_available or 30)
        
        # Try to get a template first
        template_id = request.data.get('template_id')
        
        if template_id:
            # Use specific template
            try:
                template = TemplateWorkout.objects.get(id=template_id, is_active=True)
                workout = Workout.objects.create(
                    user=user,
                    duration=template.default_duration,
                    exercises=template.exercises,
                    difficulty_score=0.5,
                    intensity_level=2,
                    is_completed=False
                )
                return Response({
                    'workout_id': str(workout.id),
                    'id': str(workout.id),
                    'duration': workout.duration,
                    'exercises': workout.exercises,
                    'difficulty_score': workout.difficulty_score,
                    'intensity_level': workout.intensity_level,
                    'from_template': template.name
                })
            except TemplateWorkout.DoesNotExist:
                pass
        
        # Otherwise use generated workout
        generated = self._get_generated_workout(user, duration)
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
            'exercises': workout.exercises,
            'difficulty_score': workout.difficulty_score,
            'intensity_level': workout.intensity_level,
            'from_template': None
        })
    
    @action(detail=False, methods=['GET'])
    def available_templates(self, request):
        """Get all available admin templates for the user to choose from"""
        templates = TemplateWorkout.objects.filter(is_active=True).values(
            'id', 'name', 'description', 'default_duration', 'goal', 
            'experience_level', 'training_location'
        )
        return Response({
            'templates': list(templates),
            'total': templates.count(),
            'message': 'Select a template or use generated workouts'
        })
    
    @action(detail=False, methods=['POST'])
    def use_template(self, request):
        """Use a specific template by ID to create a workout"""
        template_id = request.data.get('template_id')
        
        if not template_id:
            return Response({'error': 'template_id is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            template = TemplateWorkout.objects.get(id=template_id, is_active=True)
            
            workout = Workout.objects.create(
                user=request.user,
                duration=template.default_duration,
                exercises=template.exercises,
                difficulty_score=0.5,
                intensity_level=2,
                is_completed=False
            )
            
            return Response({
                'workout_id': str(workout.id),
                'id': str(workout.id),
                'duration': workout.duration,
                'exercises': workout.exercises,
                'difficulty_score': workout.difficulty_score,
                'intensity_level': workout.intensity_level,
                'template_name': template.name,
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
        """Get workout history"""
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


class TemplateWorkoutViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated]
    queryset = TemplateWorkout.objects.filter(is_active=True)
    serializer_class = TemplateWorkoutSerializer
    
    @action(detail=True, methods=['POST'])
    def use_template(self, request, pk=None):
        """Use a template to create a workout"""
        template = self.get_object()
        
        workout = Workout.objects.create(
            user=request.user,
            duration=template.default_duration,
            exercises=template.exercises,
            difficulty_score=0.5,
            intensity_level=2,
            is_completed=False
        )
        
        return Response({
            'workout_id': str(workout.id),
            'id': str(workout.id),
            'duration': workout.duration,
            'exercises': workout.exercises,
            'template_name': template.name
        })
    
    @action(detail=False, methods=['GET'])
    def list_all(self, request):
        """List all templates with more details"""
        templates = TemplateWorkout.objects.filter(is_active=True)
        data = []
        for template in templates:
            data.append({
                'id': str(template.id),
                'name': template.name,
                'description': template.description,
                'duration': template.default_duration,
                'goal': template.goal,
                'experience_level': template.experience_level,
                'training_location': template.training_location,
                'exercises_count': len(template.exercises) if template.exercises else 0
            })
        return Response({
            'templates': data,
            'total': len(data)
        })
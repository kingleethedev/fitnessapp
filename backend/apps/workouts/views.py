from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from datetime import timedelta
from .models import Workout, WorkoutLog, TemplateWorkout
from .serializers import (
    WorkoutSerializer, WorkoutLogSerializer, TemplateWorkoutSerializer,
    WorkoutGenerateSerializer, WorkoutCompleteSerializer
)
from .workout_engine import WorkoutGenerator
from .adaptive_logic import AdaptiveLogicEngine


class WorkoutViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    
    @action(detail=False, methods=['GET'])
    def today(self, request):
        """Get today's workout"""
        today = timezone.now().date()
        
        # Check if there's already a workout for today
        workout = Workout.objects.filter(
            user=request.user,
            date=today
        ).first()
        
        if not workout:
            # Create a simple default workout for testing
            workout = Workout.objects.create(
                user=request.user,
                date=today,
                duration=30,
                exercises=[
                    {'name': 'Push Ups', 'reps': 10, 'rest': 30},
                    {'name': 'Squats', 'reps': 15, 'rest': 30},
                    {'name': 'Plank', 'duration': 30, 'rest': 20},
                    {'name': 'Lunges', 'reps': 12, 'rest': 30},
                ],
                difficulty_score=0.5,
                intensity_level=2,
                is_completed=False
            )
        
        serializer = WorkoutSerializer(workout)
        return Response(serializer.data)
    
    @action(detail=False, methods=['POST'])
    def generate(self, request):
        """Generate a new workout"""
        # Get user preferences
        user = request.user
        duration = request.data.get('duration', user.time_available or 30)
        
        # Simple workout generation based on goal
        exercises = []
        if user.goal == 'FAT_LOSS':
            exercises = [
                {'name': 'Jumping Jacks', 'duration': 45, 'rest': 15},
                {'name': 'Burpees', 'reps': 12, 'rest': 20},
                {'name': 'High Knees', 'duration': 45, 'rest': 15},
                {'name': 'Mountain Climbers', 'duration': 45, 'rest': 15},
            ]
        elif user.goal == 'MUSCLE_GAIN':
            exercises = [
                {'name': 'Push Ups', 'reps': 12, 'rest': 45},
                {'name': 'Squats', 'reps': 15, 'rest': 45},
                {'name': 'Pull Ups', 'reps': 8, 'rest': 45},
                {'name': 'Dips', 'reps': 10, 'rest': 45},
            ]
        else:  # FITNESS
            exercises = [
                {'name': 'Push Ups', 'reps': 10, 'rest': 30},
                {'name': 'Squats', 'reps': 15, 'rest': 30},
                {'name': 'Plank', 'duration': 30, 'rest': 20},
                {'name': 'Lunges', 'reps': 12, 'rest': 30},
            ]
        
        workout = Workout.objects.create(
            user=user,
            duration=duration,
            exercises=exercises,
            difficulty_score=0.5,
            intensity_level=1,
            is_completed=False
        )
        
        return Response({
            'workout_id': str(workout.id),
            'id': str(workout.id),  # Add both formats for compatibility
            'duration': workout.duration,
            'exercises': workout.exercises,
            'difficulty_score': workout.difficulty_score,
            'intensity_level': workout.intensity_level
        })
    
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
                for log_data in serializer.validated_data['logs']:
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
                    'total_workouts': request.user.total_workouts
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
        from django.db.models import Count, Avg, Sum
        
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
            intensity_level=2
        )
        
        return Response({
            'workout_id': str(workout.id),
            'id': str(workout.id),
            'duration': workout.duration,
            'exercises': workout.exercises
        })
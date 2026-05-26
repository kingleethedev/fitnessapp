# views.py
from rest_framework import viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Count, Avg, Sum, Q
from django.utils import timezone
from datetime import timedelta
from apps.workouts.models import Workout
from apps.accounts.models import User

class AnalyticsViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    
    @action(detail=False, methods=['GET'])
    def dashboard(self, request):
        """Get analytics dashboard data for current user"""
        today = timezone.now().date()
        thirty_days_ago = today - timedelta(days=30)
        seven_days_ago = today - timedelta(days=7)
        
        # Workout stats
        workouts_last_30 = Workout.objects.filter(
            user=request.user,
            is_completed=True,
            date__gte=thirty_days_ago
        )
        
        workouts_last_7 = workouts_last_30.filter(date__gte=seven_days_ago)
        
        # Calculate metrics
        total_workouts = workouts_last_30.count()
        total_minutes = workouts_last_30.aggregate(total=Sum('duration'))['total'] or 0
        avg_difficulty = workouts_last_30.aggregate(avg=Avg('difficulty_score'))['avg'] or 0
        total_calories = workouts_last_30.aggregate(total=Sum('calories_burned'))['total'] or 0
        
        # Weekly breakdown
        weekly_workouts = []
        for i in range(4):
            week_start = thirty_days_ago + timedelta(days=i*7)
            week_end = week_start + timedelta(days=6)
            count = workouts_last_30.filter(
                date__gte=week_start,
                date__lte=week_end
            ).count()
            weekly_workouts.append({
                'week': i + 1,
                'count': count
            })
        
        # Exercise preferences
        exercise_counts = {}
        for workout in workouts_last_30:
            for exercise in workout.exercises:
                name = exercise.get('name', 'Unknown')
                exercise_counts[name] = exercise_counts.get(name, 0) + 1
        
        top_exercises = sorted(exercise_counts.items(), key=lambda x: x[1], reverse=True)[:5]
        
        return Response({
            'summary': {
                'total_workouts': total_workouts,
                'total_minutes': total_minutes,
                'avg_difficulty': round(avg_difficulty, 1),
                'total_calories': total_calories,
                'current_streak': request.user.streak_days,
                'consistency_rate': round((total_workouts / 30) * 100, 1) if total_workouts > 0 else 0,
            },
            'weekly_breakdown': weekly_workouts,
            'top_exercises': [{'name': name, 'count': count} for name, count in top_exercises],
            'last_7_days': {
                'workouts': workouts_last_7.count(),
                'minutes': workouts_last_7.aggregate(total=Sum('duration'))['total'] or 0,
            }
        })
    
    @action(detail=False, methods=['GET'])
    def admin_stats(self, request):
        """Get admin statistics (requires staff status)"""
        if not request.user.is_staff:
            return Response({'error': 'Admin access required'}, status=403)
        
        today = timezone.now().date()
        thirty_days_ago = today - timedelta(days=30)
        
        # User stats
        total_users = User.objects.count()
        active_users_last_30 = User.objects.filter(last_active__gte=thirty_days_ago).count()
        new_users_last_30 = User.objects.filter(date_joined__gte=thirty_days_ago).count()
        
        # Workout stats
        total_workouts = Workout.objects.filter(is_completed=True).count()
        workouts_last_30 = Workout.objects.filter(
            is_completed=True,
            date__gte=thirty_days_ago
        ).count()
        
        # Premium users
        premium_users = User.objects.filter(
            subscription_tier__in=['PREMIUM', 'PRO'],
            subscription_end_date__gt=timezone.now()
        ).count()
        
        # Revenue stats (from payments)
        from apps.payments.models import PaymentTransaction
        revenue_last_30 = PaymentTransaction.objects.filter(
            status='SUCCEEDED',
            created_at__gte=thirty_days_ago
        ).aggregate(total=Sum('amount'))['total'] or 0
        
        return Response({
            'users': {
                'total': total_users,
                'active_last_30': active_users_last_30,
                'new_last_30': new_users_last_30,
                'premium': premium_users,
                'premium_percentage': round((premium_users / total_users) * 100, 1) if total_users > 0 else 0,
            },
            'workouts': {
                'total': total_workouts,
                'last_30_days': workouts_last_30,
                'avg_daily': round(workouts_last_30 / 30, 1),
            },
            'revenue': {
                'last_30_days': float(revenue_last_30),
            },
            'retention': {
                'day_1': self._calculate_retention(1),
                'day_7': self._calculate_retention(7),
                'day_30': self._calculate_retention(30),
            }
        })
    
    def _calculate_retention(self, days):
        """Calculate user retention after X days"""
        date = timezone.now().date() - timedelta(days=days)
        users_joined = User.objects.filter(date_joined__date=date).count()
        
        if users_joined == 0:
            return 0
        
        users_active = User.objects.filter(
            date_joined__date=date,
            last_active__gte=timezone.now() - timedelta(days=days)
        ).count()
        
        return round((users_active / users_joined) * 100, 1)
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from datetime import datetime, timedelta
from .models import MealItem, MealPlan, DailyMealLog, FavoriteMeal
from .serializers import (
    MealItemSerializer, MealPlanSerializer, DailyMealLogSerializer, 
    FavoriteMealSerializer, MealPlanGenerateSerializer
)
from .meal_planner import MealPlanner

class MealViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    
    @action(detail=False, methods=['GET'])
    def meals(self, request):
        """Get all available meals"""
        try:
            meal_type = request.query_params.get('meal_type', None)
            diet = request.query_params.get('diet', None)
            
            queryset = MealItem.objects.filter(is_active=True)
            
            if meal_type:
                queryset = queryset.filter(meal_type=meal_type)
            
            if diet == 'vegetarian':
                queryset = queryset.filter(is_vegetarian=True)
            elif diet == 'vegan':
                queryset = queryset.filter(is_vegan=True)
            elif diet == 'gluten_free':
                queryset = queryset.filter(is_gluten_free=True)
            
            serializer = MealItemSerializer(queryset, many=True)
            return Response(serializer.data)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['POST'])
    def generate_plan(self, request):
        """Generate a weekly meal plan"""
        serializer = MealPlanGenerateSerializer(data=request.data)
        
        if serializer.is_valid():
            try:
                goal = serializer.validated_data.get('goal', 'HEALTHY_EATING')
                start_date = serializer.validated_data.get('start_date')
                
                if start_date:
                    start_date = datetime.strptime(start_date, '%Y-%m-%d').date()
                
                meal_plan = MealPlanner.generate_meal_plan(
                    user=request.user,
                    goal=goal,
                    start_date=start_date
                )
                
                # Customize based on preferences if provided
                if 'preferences' in serializer.validated_data:
                    meal_plan = MealPlanner.customize_meal_plan(
                        meal_plan, 
                        serializer.validated_data['preferences']
                    )
                
                plan_serializer = MealPlanSerializer(meal_plan)
                return Response(plan_serializer.data, status=status.HTTP_201_CREATED)
            except Exception as e:
                return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['GET'])
    def current_plan(self, request):
        """Get the current active meal plan"""
        try:
            today = timezone.now().date()
            # Get plan for current week
            week_start = today - timedelta(days=today.weekday() + 1)
            
            meal_plan = MealPlan.objects.filter(
                user=request.user,
                week_start_date=week_start,
                is_active=True
            ).first()
            
            if not meal_plan:
                # Generate one if doesn't exist
                meal_plan = MealPlanner.generate_meal_plan(request.user)
            
            serializer = MealPlanSerializer(meal_plan)
            return Response(serializer.data)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['GET'])
    def todays_meals(self, request):
        """Get today's meals"""
        try:
            today = timezone.now().date()
            week_start = today - timedelta(days=today.weekday() + 1)
            
            meal_plan = MealPlan.objects.filter(
                user=request.user,
                week_start_date=week_start,
                is_active=True
            ).first()
            
            if not meal_plan:
                meal_plan = MealPlanner.generate_meal_plan(request.user)
            
            todays_meals = MealPlanner.get_todays_meals(meal_plan)
            
            # Get completion status
            today_logs = {
                log.meal_type: log for log in DailyMealLog.objects.filter(
                    user=request.user,
                    date=today
                )
            }
            
            for meal_type, meal_data in todays_meals.items():
                if meal_type in today_logs:
                    meal_data['completed'] = today_logs[meal_type].is_completed
                    meal_data['log_id'] = str(today_logs[meal_type].id)
                else:
                    meal_data['completed'] = False
                    meal_data['log_id'] = None
            
            return Response({
                'date': today,
                'meals': todays_meals,
                'daily_targets': {
                    'calories': meal_plan.target_calories,
                    'protein': meal_plan.target_protein,
                    'carbs': meal_plan.target_carbs,
                    'fats': meal_plan.target_fats
                }
            })
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['POST'])
    def log_meal(self, request):
        """Log a completed meal"""
        try:
            date = request.data.get('date', timezone.now().date())
            meal_type = request.data.get('meal_type')
            meal_item_id = request.data.get('meal_item_id')
            custom_name = request.data.get('custom_name')
            custom_calories = request.data.get('custom_calories')
            
            # Handle null/empty values - convert empty string to None
            if custom_name == '' or custom_name is None:
                custom_name = None
            if custom_calories == '':
                custom_calories = None
            if meal_item_id == '':
                meal_item_id = None
            
            print(f"📝 Logging meal - Type: {meal_type}, Name: {custom_name}, Calories: {custom_calories}, MealItemId: {meal_item_id}")
            
            # Get current meal plan
            today = timezone.now().date()
            week_start = today - timedelta(days=today.weekday() + 1)
            meal_plan = MealPlan.objects.filter(
                user=request.user,
                week_start_date=week_start,
                is_active=True
            ).first()
            
            meal_log, created = DailyMealLog.objects.update_or_create(
                user=request.user,
                date=date,
                meal_type=meal_type,
                defaults={
                    'meal_plan': meal_plan,
                    'meal_item_id': meal_item_id,
                    'custom_meal_name': custom_name,
                    'custom_calories': custom_calories,
                    'is_completed': True,
                    'completed_at': timezone.now()
                }
            )
            
            serializer = DailyMealLogSerializer(meal_log)
            
            # Update weekly summary cache if needed
            if hasattr(request.user, 'update_meal_streak'):
                request.user.update_meal_streak()
            
            return Response(serializer.data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)
        except Exception as e:
            print(f"❌ Error logging meal: {str(e)}")
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['POST'])
    def rate_meal(self, request):
        """Rate a meal"""
        try:
            log_id = request.data.get('log_id')
            rating = request.data.get('rating')
            notes = request.data.get('notes', '')
            
            meal_log = DailyMealLog.objects.get(id=log_id, user=request.user)
            meal_log.rating = rating
            meal_log.notes = notes
            meal_log.save()
            
            return Response({'message': 'Meal rated successfully'})
        except DailyMealLog.DoesNotExist:
            return Response({'error': 'Meal log not found'}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    
    
    
    
    @action(detail=False, methods=['GET'])
    def favorites(self, request):
        """Get user's favorite meals"""
        try:
            favorites = FavoriteMeal.objects.filter(user=request.user).select_related('meal_item')
            serializer = FavoriteMealSerializer(favorites, many=True)
            return Response(serializer.data)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    @action(detail=False, methods=['GET'])
    def weekly_summary(self, request):
        """Get weekly meal summary"""
        try:
            today = timezone.now().date()
            week_start = today - timedelta(days=today.weekday() + 1)
            week_end = week_start + timedelta(days=6)
            
            logs = DailyMealLog.objects.filter(
                user=request.user,
                date__gte=week_start,
                date__lte=week_end,
                is_completed=True
            )
            
            # Calculate statistics
            total_meals = logs.count()
            meals_by_day = {}
            calories_by_day = {}
            
            for log in logs:
                day = log.date.strftime('%A')
                meals_by_day[day] = meals_by_day.get(day, 0) + 1
                
                # Calculate calories for this meal
                calories = 0
                if log.meal_item and log.meal_item.calories:
                    calories = log.meal_item.calories
                elif log.custom_calories:
                    calories = log.custom_calories
                calories_by_day[day] = calories_by_day.get(day, 0) + calories
            
            return Response({
                'week_start': week_start,
                'week_end': week_end,
                'total_meals_completed': total_meals,
                'total_possible_meals': 7 * 5,  # 5 meals per day
                'completion_rate': round((total_meals / (7 * 5)) * 100, 1) if total_meals > 0 else 0,
                'meals_by_day': meals_by_day,
                'calories_by_day': calories_by_day,
                'streak': request.user.streak_days
            })
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
    @action(detail=False, methods=['POST'], url_path='favorite_meal')
    def favorite_meal(self, request):
        """Add a meal to favorites"""
        try:
            meal_item_id = request.data.get('meal_item_id')
            
            if not meal_item_id:
                return Response(
                    {'error': 'meal_item_id is required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Try to get the meal item
            try:
                meal_item = MealItem.objects.get(id=meal_item_id)
            except MealItem.DoesNotExist:
                return Response(
                    {'error': f'Meal with id {meal_item_id} not found'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Create favorite
            favorite, created = FavoriteMeal.objects.get_or_create(
                user=request.user,
                meal_item=meal_item
            )
            
            if created:
                return Response(
                    {'message': 'Added to favorites', 'created': True}, 
                    status=status.HTTP_201_CREATED
                )
            else:
                return Response(
                    {'message': 'Already in favorites', 'created': False}, 
                    status=status.HTTP_200_OK
                )
                
        except Exception as e:
            print(f"❌ Error in favorite_meal: {str(e)}")
            import traceback
            traceback.print_exc()
            return Response(
                {'error': str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    @action(detail=False, methods=['DELETE'], url_path='unfavorite_meal')
    def unfavorite_meal(self, request):
        """Remove a meal from favorites"""
        try:
            meal_item_id = request.data.get('meal_item_id')
            
            if not meal_item_id:
                return Response(
                    {'error': 'meal_item_id is required'}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            deleted_count = FavoriteMeal.objects.filter(
                user=request.user,
                meal_item_id=meal_item_id
            ).delete()
            
            if deleted_count[0] > 0:
                return Response(
                    {'message': 'Removed from favorites'}, 
                    status=status.HTTP_200_OK
                )
            else:
                return Response(
                    {'message': 'Meal not in favorites'}, 
                    status=status.HTTP_404_NOT_FOUND
                )
                
        except Exception as e:
            print(f"❌ Error in unfavorite_meal: {str(e)}")
            return Response(
                {'error': str(e)}, 
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
from rest_framework import serializers
from .models import MealItem, MealPlan, DailyMealLog, FavoriteMeal

class MealItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = MealItem
        fields = '__all__'

class MealPlanSerializer(serializers.ModelSerializer):
    class Meta:
        model = MealPlan
        fields = '__all__'
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']


class DailyMealLogSerializer(serializers.ModelSerializer):
    meal_item_name = serializers.CharField(source='meal_item.name', read_only=True)
    
    class Meta:
        model = DailyMealLog
        fields = '__all__'
        read_only_fields = ['id', 'user', 'created_at']
        extra_kwargs = {
            'custom_meal_name': {'required': False, 'allow_null': True},
            'custom_calories': {'required': False, 'allow_null': True},
        }

class FavoriteMealSerializer(serializers.ModelSerializer):
    meal_item = MealItemSerializer(read_only=True)
    
    class Meta:
        model = FavoriteMeal
        fields = '__all__'
        read_only_fields = ['id', 'user', 'added_at']

class MealPlanGenerateSerializer(serializers.Serializer):
    goal = serializers.ChoiceField(choices=['WEIGHT_LOSS', 'MUSCLE_GAIN', 'MAINTENANCE', 'HEALTHY_EATING'], required=False)
    start_date = serializers.DateField(required=False)
    preferences = serializers.DictField(required=False)
# apps/workouts/serializers.py
from rest_framework import serializers
from .models import Workout, WorkoutLog, TemplateWorkout

class WorkoutSerializer(serializers.ModelSerializer):
    class Meta:
        model = Workout
        fields = '__all__'
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']

class WorkoutLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = WorkoutLog
        fields = '__all__'
        read_only_fields = ['id', 'user', 'logged_at']

class TemplateWorkoutSerializer(serializers.ModelSerializer):
    class Meta:
        model = TemplateWorkout
        fields = '__all__'

class WorkoutGenerateSerializer(serializers.Serializer):
    goal = serializers.ChoiceField(choices=['FAT_LOSS', 'MUSCLE_GAIN', 'FITNESS'], required=False)
    experience_level = serializers.ChoiceField(choices=['BEGINNER', 'INTERMEDIATE', 'ADVANCED'], required=False)
    training_location = serializers.ChoiceField(choices=['HOME', 'GYM', 'OUTDOOR'], required=False)
    days_per_week = serializers.IntegerField(required=False, min_value=1, max_value=7)
    time_available = serializers.IntegerField(required=False, min_value=5, max_value=120)

class WorkoutCompleteSerializer(serializers.Serializer):
    workout_id = serializers.UUIDField()
    completed = serializers.BooleanField()
    time_taken = serializers.IntegerField(required=False)
    satisfaction_rating = serializers.IntegerField(required=False, min_value=1, max_value=5)
    logs = serializers.ListField(
        child=serializers.DictField(),
        required=True
    )
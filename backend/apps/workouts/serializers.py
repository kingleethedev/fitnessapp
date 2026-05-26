# apps/workouts/serializers.py
from rest_framework import serializers
from .models import Workout, WorkoutLog, TemplateWorkout, Exercise

class WorkoutSerializer(serializers.ModelSerializer):
    exercises_with_videos = serializers.SerializerMethodField()
    
    class Meta:
        model = Workout
        fields = '__all__'
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']
    
    def get_exercises_with_videos(self, obj):
        """Add video URLs to exercises for frontend"""
        return obj.get_exercises_with_videos()
    
    def to_representation(self, instance):
        """Override to include videos in the response"""
        data = super().to_representation(instance)
        # Replace exercises with enriched version that includes videos
        data['exercises'] = instance.get_exercises_with_videos()
        return data


class WorkoutLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = WorkoutLog
        fields = '__all__'
        read_only_fields = ['id', 'user', 'logged_at']


class TemplateWorkoutSerializer(serializers.ModelSerializer):
    exercises_with_videos = serializers.SerializerMethodField()
    
    class Meta:
        model = TemplateWorkout
        fields = '__all__'
    
    def get_exercises_with_videos(self, obj):
        """Get template exercises with video URLs"""
        return obj.get_exercises_with_videos()
    
    def to_representation(self, instance):
        """Override to include videos in the response"""
        data = super().to_representation(instance)
        # Replace exercises with enriched version that includes videos
        data['exercises'] = instance.get_exercises_with_videos()
        return data


class ExerciseSerializer(serializers.ModelSerializer):
    video_url_display = serializers.SerializerMethodField()
    has_video = serializers.SerializerMethodField()
    
    class Meta:
        model = Exercise
        fields = '__all__'
        read_only_fields = ['id', 'created_at', 'updated_at']
    
    def get_video_url_display(self, obj):
        """Get the actual video URL to use"""
        return obj.get_video_url()
    
    def get_has_video(self, obj):
        """Check if exercise has video"""
        return obj.has_video()


class WorkoutGenerateSerializer(serializers.Serializer):
    goal = serializers.ChoiceField(choices=['FAT_LOSS', 'MUSCLE_GAIN', 'FITNESS'], required=False)
    experience_level = serializers.ChoiceField(choices=['BEGINNER', 'INTERMEDIATE', 'ADVANCED'], required=False)
    training_location = serializers.ChoiceField(choices=['HOME', 'GYM', 'OUTDOOR'], required=False)
    days_per_week = serializers.IntegerField(required=False, min_value=10, max_value=7)
    time_available = serializers.IntegerField(required=False, min_value=5, max_value=120)
    use_database_exercises = serializers.BooleanField(default=True, help_text="Use exercises from database with videos")


class WorkoutCompleteSerializer(serializers.Serializer):
    workout_id = serializers.UUIDField()
    completed = serializers.BooleanField()
    time_taken = serializers.IntegerField(required=False)
    satisfaction_rating = serializers.IntegerField(required=False, min_value=1, max_value=5)
    logs = serializers.ListField(
        child=serializers.DictField(),
        required=True
    )


# New serializer for checking video availability
class VideoStatusSerializer(serializers.Serializer):
    total_exercises = serializers.IntegerField()
    exercises_with_video = serializers.IntegerField()
    video_coverage = serializers.CharField()
    has_videos = serializers.BooleanField()
    message = serializers.CharField()
from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from django.core.validators import MinValueValidator, MaxValueValidator
from .models import User, UserProfile, UserMetric

class UserSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=False)
    confirm_password = serializers.CharField(write_only=True, required=False)
    
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password', 'confirm_password', 'height', 'weight',
                  'goal', 'experience_level', 'training_location', 'days_per_week', 
                  'time_available', 'streak_days', 'total_workouts', 'subscription_tier',
                  'onboarding_completed', 'created_at']
        read_only_fields = ['id', 'streak_days', 'total_workouts', 'created_at']
        extra_kwargs = {
            'password': {'write_only': True, 'required': False},
            'confirm_password': {'write_only': True, 'required': False},
        }
    
    def validate(self, attrs):
        # Only validate password if both are provided
        if 'password' in attrs and 'confirm_password' in attrs:
            if attrs['password'] != attrs['confirm_password']:
                raise serializers.ValidationError({"password": "Password fields didn't match."})
        return attrs
    
    def create(self, validated_data):
        validated_data.pop('confirm_password', None)
        password = validated_data.pop('password', None)
        user = User(**validated_data)
        if password:
            user.set_password(password)
        user.save()
        return user
    
    def update(self, instance, validated_data):
        # Remove confirm_password if present
        validated_data.pop('confirm_password', None)
        
        # Handle password separately if provided
        password = validated_data.pop('password', None)
        if password:
            instance.set_password(password)
        
        # Update other fields
        for attr, value in validated_data.items():
            if value is not None:
                setattr(instance, attr, value)
        
        instance.save()
        return instance

class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = '__all__'
        read_only_fields = ['user']

class UserMetricSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserMetric
        fields = '__all__'
        read_only_fields = ['user']

class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

class OnboardingSerializer(serializers.Serializer):
    goal = serializers.CharField()
    experience_level = serializers.CharField()
    training_location = serializers.CharField()
    days_per_week = serializers.IntegerField()
    time_available = serializers.IntegerField()
    height = serializers.FloatField(required=False, allow_null=True)
    weight = serializers.FloatField(required=False, allow_null=True)
    
    def validate_goal(self, value):
        # Convert string to match model choices
        value = value.upper().replace(' ', '_')
        valid_choices = ['FAT_LOSS', 'MUSCLE_GAIN', 'FITNESS']
        if value not in valid_choices:
            raise serializers.ValidationError(f'Invalid goal. Must be one of {valid_choices}')
        return value
    
    def validate_experience_level(self, value):
        value = value.upper().replace(' ', '_')
        valid_choices = ['BEGINNER', 'INTERMEDIATE', 'ADVANCED']
        if value not in valid_choices:
            raise serializers.ValidationError(f'Invalid experience level. Must be one of {valid_choices}')
        return value
    
    def validate_training_location(self, value):
        value = value.upper()
        valid_choices = ['HOME', 'GYM', 'OUTDOOR']
        if value not in valid_choices:
            raise serializers.ValidationError(f'Invalid training location. Must be one of {valid_choices}')
        return value
# serializers.py
from rest_framework import serializers
from .models import Friend, FriendRequest, Challenge, ChallengeParticipant, ActivityFeed
from apps.accounts.models import User

class FriendSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    friend_name = serializers.CharField(source='friend.username', read_only=True)
    
    class Meta:
        model = Friend
        fields = ['id', 'user', 'friend', 'user_name', 'friend_name', 'status', 'created_at']
        read_only_fields = ['id', 'created_at']

class FriendRequestSerializer(serializers.ModelSerializer):
    from_user_name = serializers.CharField(source='from_user.username', read_only=True)
    to_user_name = serializers.CharField(source='to_user.username', read_only=True)
    
    class Meta:
        model = FriendRequest
        fields = ['id', 'from_user', 'to_user', 'from_user_name', 'to_user_name', 'status', 'created_at']
        read_only_fields = ['id', 'created_at']

class ChallengeSerializer(serializers.ModelSerializer):
    created_by_name = serializers.CharField(source='created_by.username', read_only=True)
    participants_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Challenge
        fields = ['id', 'name', 'description', 'challenge_type', 'target_value', 
                 'start_date', 'end_date', 'created_by', 'created_by_name', 
                 'participants_count', 'is_active', 'created_at']
        read_only_fields = ['id', 'created_by', 'created_at']
    
    def get_participants_count(self, obj):
        return obj.participants.count()

class ChallengeParticipantSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    challenge_name = serializers.CharField(source='challenge.name', read_only=True)
    progress = serializers.SerializerMethodField()
    
    class Meta:
        model = ChallengeParticipant
        fields = ['id', 'user', 'user_name', 'challenge', 'challenge_name', 
                 'current_value', 'completed', 'progress', 'joined_at']
        read_only_fields = ['id', 'joined_at']
    
    def get_progress(self, obj):
        if obj.challenge.target_value > 0:
            return (obj.current_value / obj.challenge.target_value) * 100
        return 0

class ActivityFeedSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    user_avatar = serializers.SerializerMethodField()
    
    class Meta:
        model = ActivityFeed
        fields = ['id', 'user', 'user_name', 'user_avatar', 'activity_type', 
                 'content', 'metadata', 'created_at']
        read_only_fields = ['id', 'created_at']
    
    def get_user_avatar(self, obj):
        if hasattr(obj.user, 'profile') and obj.user.profile.avatar:
            return obj.user.profile.avatar.url
        return None

class LeaderboardSerializer(serializers.Serializer):
    rank = serializers.IntegerField()
    user_id = serializers.CharField()
    username = serializers.CharField()
    workouts = serializers.IntegerField()
    streak_days = serializers.IntegerField()
    total_minutes = serializers.IntegerField()
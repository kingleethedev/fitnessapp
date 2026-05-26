# models.py
from django.db import models
from django.conf import settings
from django.utils import timezone
import uuid

class Friend(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='friends_initiated')
    friend = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='friends_received')
    status = models.CharField(max_length=20, choices=[
        ('PENDING', 'Pending'),
        ('ACCEPTED', 'Accepted'),
        ('BLOCKED', 'Blocked'),
    ], default='PENDING')
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ['user', 'friend']
    
    def __str__(self):
        return f"{self.user.username} - {self.friend.username}"

class FriendRequest(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    from_user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='sent_requests')
    to_user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='received_requests')
    status = models.CharField(max_length=20, choices=[
        ('PENDING', 'Pending'),
        ('ACCEPTED', 'Accepted'),
        ('REJECTED', 'Rejected'),
    ], default='PENDING')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        unique_together = ['from_user', 'to_user']
    
    def __str__(self):
        return f"{self.from_user.username} -> {self.to_user.username} ({self.status})"

class Challenge(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100)
    description = models.TextField()
    
    CHALLENGE_TYPES = [
        ('STREAK', 'Streak Challenge'),
        ('WORKOUT_COUNT', 'Workout Count'),
        ('CALORIES', 'Calories Burned'),
        ('DURATION', 'Total Workout Duration'),
        ('CONSISTENCY', 'Consistency Challenge'),
    ]
    challenge_type = models.CharField(max_length=20, choices=CHALLENGE_TYPES)
    target_value = models.FloatField(help_text="Target value to achieve")
    
    start_date = models.DateField()
    end_date = models.DateField()
    
    participants = models.ManyToManyField(settings.AUTH_USER_MODEL, through='ChallengeParticipant', related_name='challenges')
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='created_challenges')
    
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.name} ({self.challenge_type})"

class ChallengeParticipant(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    challenge = models.ForeignKey(Challenge, on_delete=models.CASCADE)
    current_value = models.FloatField(default=0)
    completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)
    joined_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        unique_together = ['user', 'challenge']
    
    def __str__(self):
        return f"{self.user.username} - {self.challenge.name}"

class ActivityFeed(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='activities')
    
    ACTIVITY_TYPES = [
        ('WORKOUT_COMPLETE', 'Workout Complete'),
        ('STREAK_MILESTONE', 'Streak Milestone'),
        ('CHALLENGE_JOINED', 'Challenge Joined'),
        ('CHALLENGE_COMPLETE', 'Challenge Complete'),
        ('FRIEND_ADDED', 'Friend Added'),
        ('ACHIEVEMENT', 'Achievement Unlocked'),
    ]
    activity_type = models.CharField(max_length=30, choices=ACTIVITY_TYPES)
    content = models.CharField(max_length=255)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['activity_type']),
        ]
    
    def __str__(self):
        return f"{self.user.username} - {self.activity_type}"
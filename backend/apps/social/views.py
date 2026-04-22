# views.py
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db.models import Q, Count, Avg
from django.utils import timezone
from datetime import timedelta
from .models import Friend, FriendRequest, Challenge, ChallengeParticipant, ActivityFeed
from .serializers import (
    FriendSerializer, FriendRequestSerializer, ChallengeSerializer, 
    ChallengeParticipantSerializer, ActivityFeedSerializer, 
    LeaderboardSerializer
)
from apps.accounts.models import User
from apps.workouts.models import Workout

class SocialViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    
    # Friend Management
    @action(detail=False, methods=['GET'])
    def friends(self, request):
        """Get user's friends list"""
        friends = Friend.objects.filter(
            Q(user=request.user) | Q(friend=request.user),
            status='ACCEPTED'
        )
        
        friend_list = []
        for friendship in friends:
            friend_user = friendship.friend if friendship.user == request.user else friendship.user
            friend_list.append({
                'id': str(friend_user.id),
                'username': friend_user.username,
                'email': friend_user.email,
                'streak_days': friend_user.streak_days,
                'total_workouts': friend_user.total_workouts,
                'avatar': getattr(friend_user.profile, 'avatar', None),
            })
        
        return Response(friend_list)
    
    @action(detail=False, methods=['GET'])
    def friend_requests(self, request):
        """Get pending friend requests"""
        requests = FriendRequest.objects.filter(
            to_user=request.user,
            status='PENDING'
        ).select_related('from_user')
        
        serializer = FriendRequestSerializer(requests, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['POST'])
    def send_request(self, request):
        """Send a friend request"""
        user_id = request.data.get('user_id')
        
        try:
            to_user = User.objects.get(id=user_id)
            
            # Check if already friends
            if Friend.objects.filter(
                Q(user=request.user, friend=to_user) | Q(user=to_user, friend=request.user),
                status='ACCEPTED'
            ).exists():
                return Response({'error': 'Already friends'}, status=status.HTTP_400_BAD_REQUEST)
            
            # Check if request already exists
            if FriendRequest.objects.filter(
                from_user=request.user, to_user=to_user, status='PENDING'
            ).exists():
                return Response({'error': 'Friend request already sent'}, status=status.HTTP_400_BAD_REQUEST)
            
            friend_request = FriendRequest.objects.create(
                from_user=request.user,
                to_user=to_user
            )
            
            serializer = FriendRequestSerializer(friend_request)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
            
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
    
    @action(detail=False, methods=['POST'])
    def accept_request(self, request):
        """Accept a friend request"""
        request_id = request.data.get('request_id')
        
        try:
            friend_request = FriendRequest.objects.get(
                id=request_id,
                to_user=request.user,
                status='PENDING'
            )
            
            # Create friendship
            Friend.objects.create(
                user=friend_request.from_user,
                friend=friend_request.to_user,
                status='ACCEPTED'
            )
            
            friend_request.status = 'ACCEPTED'
            friend_request.save()
            
            return Response({'message': 'Friend request accepted'})
            
        except FriendRequest.DoesNotExist:
            return Response({'error': 'Friend request not found'}, status=status.HTTP_404_NOT_FOUND)
    
    @action(detail=False, methods=['POST'])
    def reject_request(self, request):
        """Reject a friend request"""
        request_id = request.data.get('request_id')
        
        try:
            friend_request = FriendRequest.objects.get(
                id=request_id,
                to_user=request.user,
                status='PENDING'
            )
            friend_request.status = 'REJECTED'
            friend_request.save()
            
            return Response({'message': 'Friend request rejected'})
            
        except FriendRequest.DoesNotExist:
            return Response({'error': 'Friend request not found'}, status=status.HTTP_404_NOT_FOUND)
    
    @action(detail=False, methods=['DELETE'])
    def remove_friend(self, request):
        """Remove a friend"""
        friend_id = request.data.get('friend_id')
        
        try:
            friend = User.objects.get(id=friend_id)
            friendship = Friend.objects.filter(
                Q(user=request.user, friend=friend) | Q(user=friend, friend=request.user),
                status='ACCEPTED'
            ).first()
            
            if friendship:
                friendship.delete()
                return Response({'message': 'Friend removed'})
            else:
                return Response({'error': 'Friendship not found'}, status=status.HTTP_404_NOT_FOUND)
                
        except User.DoesNotExist:
            return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
    
    # Activity Feed
    @action(detail=False, methods=['GET'])
    def feed(self, request):
        """Get activity feed from friends"""
        limit = int(request.query_params.get('limit', 50))
        
        # Get user's friends
        friends = Friend.objects.filter(
            Q(user=request.user) | Q(friend=request.user),
            status='ACCEPTED'
        )
        
        friend_ids = []
        for friendship in friends:
            friend_id = friendship.friend.id if friendship.user == request.user else friendship.user.id
            friend_ids.append(friend_id)
        
        # Include current user
        friend_ids.append(request.user.id)
        
        # Get activities from friends and self
        activities = ActivityFeed.objects.filter(
            user_id__in=friend_ids
        ).select_related('user').order_by('-created_at')[:limit]
        
        serializer = ActivityFeedSerializer(activities, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['POST'])
    def create_activity(self, request):
        """Create an activity feed item"""
        activity_type = request.data.get('activity_type')
        content = request.data.get('content')
        metadata = request.data.get('metadata', {})
        
        activity = ActivityFeed.objects.create(
            user=request.user,
            activity_type=activity_type,
            content=content,
            metadata=metadata
        )
        
        serializer = ActivityFeedSerializer(activity)
        return Response(serializer.data)
    
    # Leaderboard
    @action(detail=False, methods=['GET'])
    def leaderboard(self, request):
        """Get global leaderboard"""
        period = request.query_params.get('period', 'weekly')  # weekly, monthly, all_time
        limit = int(request.query_params.get('limit', 50))
        
        if period == 'weekly':
            start_date = timezone.now().date() - timedelta(days=7)
        elif period == 'monthly':
            start_date = timezone.now().date() - timedelta(days=30)
        else:
            start_date = None
        
        # Get workout stats
        workout_stats = Workout.objects.filter(
            is_completed=True
        )
        
        if start_date:
            workout_stats = workout_stats.filter(date__gte=start_date)
        
        leaderboard_data = workout_stats.values('user').annotate(
            total_workouts=Count('id'),
            total_duration=Avg('duration'),
            total_calories=Avg('calories_burned')
        ).order_by('-total_workouts')[:limit]
        
        result = []
        rank = 1
        for stat in leaderboard_data:
            user = User.objects.get(id=stat['user'])
            result.append({
                'rank': rank,
                'user_id': str(user.id),
                'username': user.username,
                'workouts': stat['total_workouts'],
                'avg_duration': round(stat['total_duration'], 0) if stat['total_duration'] else 0,
                'streak_days': user.streak_days,
            })
            rank += 1
        
        return Response(result)
    
    @action(detail=False, methods=['GET'])
    def friend_leaderboard(self, request):
        """Get leaderboard among friends"""
        # Get user's friends
        friends = Friend.objects.filter(
            Q(user=request.user) | Q(friend=request.user),
            status='ACCEPTED'
        )
        
        friend_ids = [request.user.id]
        for friendship in friends:
            friend_id = friendship.friend.id if friendship.user == request.user else friendship.user.id
            friend_ids.append(friend_id)
        
        # Get last 30 days stats
        start_date = timezone.now().date() - timedelta(days=30)
        
        workout_stats = Workout.objects.filter(
            user_id__in=friend_ids,
            is_completed=True,
            date__gte=start_date
        ).values('user').annotate(
            total_workouts=Count('id'),
            total_minutes=Avg('duration')
        ).order_by('-total_workouts')
        
        result = []
        rank = 1
        for stat in workout_stats:
            user = User.objects.get(id=stat['user'])
            result.append({
                'rank': rank,
                'user_id': str(user.id),
                'username': user.username,
                'workouts': stat['total_workouts'],
                'total_minutes': round(stat['total_minutes'], 0) if stat['total_minutes'] else 0,
                'is_current_user': user.id == request.user.id,
            })
            rank += 1
        
        return Response(result)
    
    # Challenges
    @action(detail=False, methods=['GET'])
    def challenges(self, request):
        """Get active challenges"""
        now = timezone.now().date()
        
        challenges = Challenge.objects.filter(
            is_active=True,
            start_date__lte=now,
            end_date__gte=now
        ).select_related('created_by')
        
        serializer = ChallengeSerializer(challenges, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['GET'])
    def my_challenges(self, request):
        """Get challenges user is participating in"""
        participations = ChallengeParticipant.objects.filter(
            user=request.user
        ).select_related('challenge')
        
        result = []
        for participation in participations:
            challenge = participation.challenge
            result.append({
                'id': str(challenge.id),
                'name': challenge.name,
                'description': challenge.description,
                'challenge_type': challenge.challenge_type,
                'target_value': challenge.target_value,
                'current_value': participation.current_value,
                'progress': (participation.current_value / challenge.target_value) * 100 if challenge.target_value > 0 else 0,
                'start_date': challenge.start_date,
                'end_date': challenge.end_date,
                'completed': participation.completed,
            })
        
        return Response(result)
    
    @action(detail=False, methods=['POST'])
    def join_challenge(self, request):
        """Join a challenge"""
        challenge_id = request.data.get('challenge_id')
        
        try:
            challenge = Challenge.objects.get(id=challenge_id, is_active=True)
            
            participation, created = ChallengeParticipant.objects.get_or_create(
                user=request.user,
                challenge=challenge,
                defaults={'current_value': 0}
            )
            
            if not created:
                return Response({'message': 'Already joined this challenge'})
            
            return Response({'message': 'Joined challenge successfully'})
            
        except Challenge.DoesNotExist:
            return Response({'error': 'Challenge not found'}, status=status.HTTP_404_NOT_FOUND)
    
    @action(detail=False, methods=['POST'])
    def create_challenge(self, request):
        """Create a new challenge"""
        serializer = ChallengeSerializer(data=request.data)
        
        if serializer.is_valid():
            challenge = Challenge.objects.create(
                name=serializer.validated_data['name'],
                description=serializer.validated_data['description'],
                challenge_type=serializer.validated_data['challenge_type'],
                target_value=serializer.validated_data['target_value'],
                start_date=serializer.validated_data['start_date'],
                end_date=serializer.validated_data['end_date'],
                created_by=request.user
            )
            
            return Response(ChallengeSerializer(challenge).data, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    # Search Users
    @action(detail=False, methods=['GET'])
    def search(self, request):
        """Search for users"""
        query = request.query_params.get('q', '')
        
        if len(query) < 2:
            return Response([])
        
        users = User.objects.filter(
            Q(username__icontains=query) | Q(email__icontains=query),
            is_active=True
        ).exclude(id=request.user.id)[:20]
        
        result = []
        for user in users:
            # Check if already friends
            is_friend = Friend.objects.filter(
                Q(user=request.user, friend=user) | Q(user=user, friend=request.user),
                status='ACCEPTED'
            ).exists()
            
            # Check if request pending
            request_sent = FriendRequest.objects.filter(
                from_user=request.user, to_user=user, status='PENDING'
            ).exists()
            
            result.append({
                'id': str(user.id),
                'username': user.username,
                'email': user.email,
                'is_friend': is_friend,
                'request_sent': request_sent,
            })
        
        return Response(result)
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import authenticate
from django.contrib.auth import get_user_model
from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_encode, urlsafe_base64_decode
from django.utils.encoding import force_bytes, force_str
from django.core.mail import send_mail
from django.conf import settings
from django.utils import timezone
from .models import User, UserProfile, UserMetric
from .serializers import (
    UserSerializer, UserProfileSerializer, UserMetricSerializer, 
    LoginSerializer, OnboardingSerializer
)

# Get the correct User model
UserModel = get_user_model()


class AuthViewSet(viewsets.GenericViewSet):
    permission_classes = [AllowAny]
    
    @action(detail=False, methods=['POST'])
    def register(self, request):
        print("📝 Registration request received")
        serializer = UserSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            refresh = RefreshToken.for_user(user)
            
            # Create user profile
            UserProfile.objects.create(user=user)
            
            return Response({
                'user': UserSerializer(user).data,
                'refresh': str(refresh),
                'access': str(refresh.access_token),
            }, status=status.HTTP_201_CREATED)
        print(f"❌ Registration errors: {serializer.errors}")
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['POST'])
    def login(self, request):
        print("🔑 Login request received")
        serializer = LoginSerializer(data=request.data)
        
        if serializer.is_valid():
            email = serializer.validated_data['email']
            password = serializer.validated_data['password']
            
            print(f"📧 Login attempt with email: {email}")
            
            try:
                # Use get_user_model() to get the correct User model
                user = UserModel.objects.get(email=email)
                print(f"✅ User found: {user.username}")
                
                # Authenticate using username (Django's default)
                auth_user = authenticate(username=user.username, password=password)
                
                if auth_user:
                    print(f"✅ Authentication successful for: {auth_user.username}")
                    refresh = RefreshToken.for_user(auth_user)
                    
                    return Response({
                        'user': {
                            'id': str(auth_user.id),
                            'username': auth_user.username,
                            'email': auth_user.email,
                        },
                        'refresh': str(refresh),
                        'access': str(refresh.access_token),
                    }, status=status.HTTP_200_OK)
                else:
                    print(f"❌ Authentication failed for: {user.username}")
                    return Response(
                        {'error': 'Invalid credentials'}, 
                        status=status.HTTP_401_UNAUTHORIZED
                    )
                    
            except UserModel.DoesNotExist:
                print(f"❌ User not found with email: {email}")
                return Response(
                    {'error': 'Invalid credentials'}, 
                    status=status.HTTP_401_UNAUTHORIZED
                )
        
        print(f"❌ Login serializer errors: {serializer.errors}")
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['POST'])
    def logout(self, request):
        try:
            refresh_token = request.data.get("refresh")
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
            return Response({'message': 'Successfully logged out'}, status=status.HTTP_200_OK)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)


class PasswordResetViewSet(viewsets.GenericViewSet):
    permission_classes = [AllowAny]
    
    @action(detail=False, methods=['POST'])
    def forgot_password(self, request):
        email = request.data.get('email')
        
        try:
            user = UserModel.objects.get(email=email)
            
            # Generate token
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            token = default_token_generator.make_token(user)
            
            # Send email
            reset_link = f"{settings.FRONTEND_URL}/reset-password/{uid}/{token}"
            
            send_mail(
                'Password Reset Request',
                f'Click the link to reset your password: {reset_link}',
                settings.DEFAULT_FROM_EMAIL,
                [email],
                fail_silently=False,
            )
            
            return Response({'message': 'Password reset link sent to your email'})
        except UserModel.DoesNotExist:
            # Don't reveal that user doesn't exist for security
            return Response({'message': 'If an account exists, a reset link has been sent'})
    
    @action(detail=False, methods=['POST'])
    def reset_password(self, request):
        uid = request.data.get('uid')
        token = request.data.get('token')
        new_password = request.data.get('new_password')
        
        try:
            user_id = force_str(urlsafe_base64_decode(uid))
            user = UserModel.objects.get(pk=user_id)
            
            if default_token_generator.check_token(user, token):
                user.set_password(new_password)
                user.save()
                return Response({'message': 'Password reset successful'})
            else:
                return Response({'error': 'Invalid token'}, status=status.HTTP_400_BAD_REQUEST)
        except (TypeError, ValueError, OverflowError, UserModel.DoesNotExist):
            return Response({'error': 'Invalid request'}, status=status.HTTP_400_BAD_REQUEST)


class UserViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = UserSerializer
    
    def get_queryset(self):
        return UserModel.objects.filter(id=self.request.user.id)
    
    @action(detail=False, methods=['GET'])
    def me(self, request):
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)
    
    @action(detail=False, methods=['PUT', 'PATCH'])
    def update_profile(self, request):
        user = request.user
        serializer = UserSerializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['POST'])
    def complete_onboarding(self, request):
        print("📋 Onboarding request received")
        print(f"📋 Data: {request.data}")
        
        serializer = OnboardingSerializer(data=request.data)
        
        if serializer.is_valid():
            user = request.user
            validated_data = serializer.validated_data
            
            user.goal = validated_data['goal']
            user.experience_level = validated_data['experience_level']
            user.training_location = validated_data['training_location']
            user.days_per_week = validated_data['days_per_week']
            user.time_available = validated_data['time_available']
            
            if validated_data.get('height'):
                user.height = validated_data['height']
            if validated_data.get('weight'):
                user.weight = validated_data['weight']
            
            user.onboarding_completed = True
            user.onboarding_completed_at = timezone.now()
            user.save()
            
            return Response({
                'status': 'success',
                'message': 'Onboarding completed successfully',
                'user': UserSerializer(user).data
            }, status=status.HTTP_200_OK)
        
        print(f"❌ Onboarding validation errors: {serializer.errors}")
        return Response({
            'status': 'error',
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['GET'])
    def profile(self, request):
        """Get complete user profile with stats"""
        user = request.user
        
        # Import here to avoid circular imports
        from apps.workouts.models import Workout
        from apps.meals.models import DailyMealLog
        
        total_workouts = Workout.objects.filter(user=user, is_completed=True).count()
        weekly_workouts = Workout.objects.filter(
            user=user, 
            is_completed=True,
            date__gte=timezone.now().date() - timezone.timedelta(days=7)
        ).count()
        total_meals_logged = DailyMealLog.objects.filter(user=user).count()
        
        return Response({
            'id': str(user.id),
            'username': user.username,
            'email': user.email,
            'height': user.height,
            'weight': user.weight,
            'goal': user.goal,
            'goal_display': user.get_goal_display(),
            'experience_level': user.experience_level,
            'experience_display': user.get_experience_level_display(),
            'training_location': user.training_location,
            'location_display': user.get_training_location_display(),
            'days_per_week': user.days_per_week,
            'time_available': user.time_available,
            'streak_days': user.streak_days,
            'total_workouts': total_workouts,
            'weekly_workouts': weekly_workouts,
            'total_meals_logged': total_meals_logged,
            'subscription_tier': user.subscription_tier,
            'onboarding_completed': user.onboarding_completed,
            'created_at': user.created_at,
        })
    
    @action(detail=False, methods=['GET'])
    def workout_history(self, request):
        """Get user's workout history"""
        from apps.workouts.models import Workout
        from apps.workouts.serializers import WorkoutSerializer
        
        limit = int(request.query_params.get('limit', 50))
        workouts = Workout.objects.filter(
            user=request.user
        ).order_by('-date')[:limit]
        
        serializer = WorkoutSerializer(workouts, many=True)
        return Response({
            'count': workouts.count(),
            'results': serializer.data
        })


class UserMetricViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = UserMetricSerializer
    
    def get_queryset(self):
        return UserMetric.objects.filter(user=self.request.user)
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
    
    @action(detail=False, methods=['POST'])
    def add_measurement(self, request):
        """Add a new body measurement"""
        serializer = UserMetricSerializer(data=request.data)
        if serializer.is_valid():
            today = timezone.now().date()
            existing = UserMetric.objects.filter(
                user=request.user,
                date=today
            ).first()
            
            if existing:
                for key, value in serializer.validated_data.items():
                    if value is not None:
                        setattr(existing, key, value)
                existing.save()
                return Response(UserMetricSerializer(existing).data)
            else:
                metric = serializer.save(user=request.user)
                return Response(UserMetricSerializer(metric).data, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@action(detail=False, methods=['PUT', 'PATCH'])
def update_profile(self, request):
    """Update user profile"""
    user = request.user
    data = request.data
    
    print(f"📝 Updating profile for user {user.username}")
    print(f"📝 Data received: {data}")
    
    # Allowed fields to update - exclude password
    allowed_fields = ['height', 'weight', 'goal', 'experience_level', 
                     'training_location', 'days_per_week', 'time_available']
    
    try:
        for field in allowed_fields:
            if field in data and data[field] is not None:
                value = data[field]
                print(f"Processing field {field} with value {value}")
                
                # Convert to appropriate type
                if field in ['height', 'weight']:
                    value = float(value)
                elif field in ['days_per_week', 'time_available']:
                    value = int(value)
                
                setattr(user, field, value)
                print(f"✅ Updated {field} to {value}")
        
        user.save()
        print(f"✅ User {user.username} saved successfully")
        
        # Return updated user data
        serializer = UserSerializer(user)
        return Response(serializer.data, status=status.HTTP_200_OK)
        
    except ValueError as e:
        print(f"❌ ValueError: {str(e)}")
        return Response(
            {'error': f'Invalid value format: {str(e)}'}, 
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        print(f"❌ Error updating profile: {str(e)}")
        import traceback
        traceback.print_exc()
        return Response(
            {'error': str(e)}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny   


@api_view(['GET'])
@permission_classes([AllowAny])
def test_api(request):
    """Simple test endpoint to verify API is working"""
    return JsonResponse({
        'status': 'success',
        'message': 'API is working!',
        'endpoints': {
            'auth': '/api/auth/',
            'users': '/api/users/',
            'workouts': '/api/workouts/',
            'meals': '/api/meals/',
            'social': '/api/social/',
        }
    })
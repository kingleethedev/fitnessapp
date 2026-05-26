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
from django.db import transaction
from .models import User, UserProfile, UserMetric
from .serializers import (
    UserSerializer, UserProfileSerializer, UserMetricSerializer, 
    LoginSerializer, OnboardingSerializer
)
from .firebase_config import (
    verify_firebase_token, 
    get_or_create_user_from_firebase,
    revoke_firebase_tokens,
    delete_firebase_user
)

UserModel = get_user_model()


class AuthViewSet(viewsets.GenericViewSet):
    permission_classes = [AllowAny]
    
    @action(detail=False, methods=['POST'])
    def register(self, request):
        print("=" * 50)
        print("📝 Registration request received")
        print(f"📝 Data: {request.data}")
        
        serializer = UserSerializer(data=request.data)
        
        if serializer.is_valid():
            try:
                with transaction.atomic():
                    # Create user
                    user = serializer.save()
                    print(f"✅ User created: {user.username} (ID: {user.id})")
                    
                    # Create user profile safely
                    try:
                        # Check if UserProfile model exists and create it
                        profile, created = UserProfile.objects.get_or_create(user=user)
                        if created:
                            print(f"✅ UserProfile created for {user.username}")
                        else:
                            print(f"⚠️ UserProfile already existed for {user.username}")
                    except Exception as profile_error:
                        print(f"⚠️ Could not create UserProfile: {profile_error}")
                        # Don't fail registration if profile creation fails
                        # The profile might have been created via signal or doesn't exist
                    
                    # Generate tokens
                    refresh = RefreshToken.for_user(user)
                    
                    response_data = {
                        'user': {
                            'id': str(user.id),
                            'username': user.username,
                            'email': user.email,
                            'first_name': user.first_name,
                            'last_name': user.last_name,
                            'onboarding_completed': user.onboarding_completed,
                            'has_access': user.has_access(),
                            'is_trial_active': user.is_trial_active(),
                            'is_subscribed': user.is_subscription_active,
                        },
                        'refresh': str(refresh),
                        'access': str(refresh.access_token),
                    }
                    
                    print("✅ Registration successful!")
                    print("=" * 50)
                    
                    return Response(response_data, status=status.HTTP_201_CREATED)
                    
            except Exception as e:
                print(f"❌ CRITICAL ERROR during registration: {type(e).__name__}: {str(e)}")
                import traceback
                traceback.print_exc()
                print("=" * 50)
                
                return Response(
                    {'error': f'Registration failed: {str(e)}'}, 
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        
        print(f"❌ Registration serializer errors: {serializer.errors}")
        print("=" * 50)
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
                user = UserModel.objects.get(email=email)
                print(f"✅ User found: {user.username}")
                
                # Check if user is Firebase user (no password)
                if not user.password and user.firebase_uid:
                    return Response(
                        {'error': 'Please sign in with Google or Firebase', 
                         'provider': user.auth_provider or 'firebase'}, 
                        status=status.HTTP_400_BAD_REQUEST
                    )
                
                auth_user = authenticate(username=user.username, password=password)
                
                if auth_user:
                    print(f"✅ Authentication successful for: {auth_user.username}")
                    refresh = RefreshToken.for_user(auth_user)
                    
                    # Log last active
                    auth_user.last_active = timezone.now()
                    auth_user.save(update_fields=['last_active'])
                    
                    return Response({
                        'user': {
                            'id': str(auth_user.id),
                            'username': auth_user.username,
                            'email': auth_user.email,
                            'first_name': auth_user.first_name,
                            'last_name': auth_user.last_name,
                            'onboarding_completed': auth_user.onboarding_completed,
                            'has_access': auth_user.has_access(),
                            'is_trial_active': auth_user.is_trial_active(),
                            'is_subscribed': auth_user.is_subscription_active,
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
    def firebase_auth(self, request):
        """Authenticate using Firebase ID token"""
        id_token = request.data.get('id_token')
        provider = request.data.get('provider', 'FIREBASE')
        
        if not id_token:
            return Response(
                {'error': 'ID token is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verify Firebase token
        decoded_token = verify_firebase_token(id_token)
        
        if not decoded_token:
            return Response(
                {'error': 'Invalid or expired Firebase token'}, 
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Get or create user
        user = get_or_create_user_from_firebase(decoded_token, provider)
        
        # Generate JWT tokens
        refresh = RefreshToken.for_user(user)
        
        # Update last active
        user.last_active = timezone.now()
        user.save(update_fields=['last_active'])
        
        # Check if onboarding is needed
        requires_onboarding = not user.onboarding_completed
        
        return Response({
            'user': {
                'id': str(user.id),
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'firebase_uid': user.firebase_uid,
                'email_verified': user.email_verified,
                'photo_url': user.firebase_photo_url,
                'onboarding_completed': user.onboarding_completed,
                'has_access': user.has_access(),
                'is_trial_active': user.is_trial_active(),
                'is_subscribed': user.is_subscription_active,
                'requires_onboarding': requires_onboarding,
            },
            'refresh': str(refresh),
            'access': str(refresh.access_token),
            'is_new_user': user.onboarding_completed_at is None,
        }, status=status.HTTP_200_OK)
    
    @action(detail=False, methods=['POST'])
    def firebase_google_auth(self, request):
        """Authenticate with Google Sign-In via Firebase"""
        id_token = request.data.get('id_token')
        
        if not id_token:
            return Response(
                {'error': 'ID token is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verify Firebase token
        decoded_token = verify_firebase_token(id_token)
        
        if not decoded_token:
            return Response(
                {'error': 'Invalid Firebase token'}, 
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Check if it's a Google sign-in
        firebase_sign_in_provider = decoded_token.get('firebase', {}).get('sign_in_provider')
        if firebase_sign_in_provider != 'google.com':
            return Response(
                {'error': 'Expected Google sign-in provider'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Get or create user
        user = get_or_create_user_from_firebase(decoded_token, 'GOOGLE')
        
        # Update Google-specific info
        user.firebase_photo_url = decoded_token.get('picture', user.firebase_photo_url)
        user.first_name = decoded_token.get('given_name', user.first_name)
        user.last_name = decoded_token.get('family_name', user.last_name)
        user.save()
        
        # Generate JWT tokens
        refresh = RefreshToken.for_user(user)
        
        return Response({
            'user': {
                'id': str(user.id),
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'firebase_uid': user.firebase_uid,
                'photo_url': user.firebase_photo_url,
                'onboarding_completed': user.onboarding_completed,
                'has_access': user.has_access(),
                'is_trial_active': user.is_trial_active(),
                'is_subscribed': user.is_subscription_active,
            },
            'refresh': str(refresh),
            'access': str(refresh.access_token),
        }, status=status.HTTP_200_OK)
    
    @action(detail=False, methods=['POST'])
    def link_firebase_account(self, request):
        """Link Firebase account to existing user"""
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required'}, 
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        id_token = request.data.get('id_token')
        provider = request.data.get('provider', 'FIREBASE')
        
        if not id_token:
            return Response(
                {'error': 'ID token is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Verify Firebase token
        decoded_token = verify_firebase_token(id_token)
        
        if not decoded_token:
            return Response(
                {'error': 'Invalid Firebase token'}, 
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        # Check if Firebase UID is already linked to another user
        firebase_uid = decoded_token.get('uid')
        existing_user = UserModel.objects.filter(firebase_uid=firebase_uid).exclude(id=request.user.id).first()
        
        if existing_user:
            return Response(
                {'error': 'Firebase account already linked to another user'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Link Firebase to current user
        request.user.firebase_uid = firebase_uid
        request.user.email_verified = decoded_token.get('email_verified', False)
        request.user.firebase_photo_url = decoded_token.get('picture', request.user.firebase_photo_url)
        request.user.auth_provider = provider
        request.user.save()
        
        return Response({
            'message': 'Firebase account linked successfully',
            'firebase_uid': request.user.firebase_uid,
            'email_verified': request.user.email_verified
        })
    
    @action(detail=False, methods=['POST'])
    def unlink_firebase_account(self, request):
        """Unlink Firebase account from user"""
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required'}, 
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        if not request.user.firebase_uid:
            return Response(
                {'error': 'No Firebase account linked'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        request.user.firebase_uid = None
        request.user.firebase_photo_url = None
        request.user.auth_provider = None
        request.user.save()
        
        return Response({
            'message': 'Firebase account unlinked successfully'
        })
    
    @action(detail=False, methods=['POST'])
    def logout(self, request):
        try:
            refresh_token = request.data.get("refresh")
            if refresh_token:
                token = RefreshToken(refresh_token)
                token.blacklist()
            
            # Optionally revoke Firebase tokens if user has Firebase linked
            if request.user.is_authenticated and request.user.firebase_uid:
                revoke_firebase_tokens(request.user.firebase_uid)
            
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
            
            # Check if user is from Firebase
            if user.firebase_uid:
                return Response({
                    'message': 'This account uses Firebase authentication. Please reset your password through the app using "Forgot Password" option.'
                }, status=status.HTTP_400_BAD_REQUEST)
            
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
            
            if user.firebase_uid:
                return Response({'error': 'Use Firebase to reset password for this account'}, 
                              status=status.HTTP_400_BAD_REQUEST)
            
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
    @transaction.atomic
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
            'first_name': user.first_name,
            'last_name': user.last_name,
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
            'has_access': user.has_access(),
            'is_trial_active': user.is_trial_active(),
            'is_subscribed': user.is_subscription_active,
            'subscription_end_date': user.subscription_end_date,
            'onboarding_completed': user.onboarding_completed,
            'firebase_uid': user.firebase_uid,
            'auth_provider': user.auth_provider,
            'photo_url': user.firebase_photo_url,
            'created_at': user.created_at,
        })
    
    @action(detail=False, methods=['POST'])
    def delete_account(self, request):
        """Delete user account completely"""
        user = request.user
        password = request.data.get('password')
        
        # If user has password, verify it
        if user.password:
            if not password:
                return Response({'error': 'Password is required to delete account'}, 
                              status=status.HTTP_400_BAD_REQUEST)
            
            auth_user = authenticate(username=user.username, password=password)
            if not auth_user:
                return Response({'error': 'Invalid password'}, 
                              status=status.HTTP_401_UNAUTHORIZED)
        
        # Delete from Firebase if linked
        if user.firebase_uid:
            delete_firebase_user(user.firebase_uid)
        
        # Delete user from Django
        user.delete()
        
        return Response({'message': 'Account deleted successfully'}, 
                       status=status.HTTP_200_OK)
    
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
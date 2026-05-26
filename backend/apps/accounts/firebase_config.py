import firebase_admin
from firebase_admin import credentials, auth
from django.conf import settings
import json
import os

def initialize_firebase():
    """Initialize Firebase Admin SDK"""
    if not firebase_admin._apps:
        # Get Firebase credentials from settings
        firebase_creds = settings.FIREBASE_CREDENTIALS
        
        if isinstance(firebase_creds, dict):
            cred = credentials.Certificate(firebase_creds)
        elif isinstance(firebase_creds, str) and os.path.exists(firebase_creds):
            cred = credentials.Certificate(firebase_creds)
        else:
            # Try to get from environment variable
            firebase_creds_json = os.environ.get('FIREBASE_CREDENTIALS_JSON')
            if firebase_creds_json:
                cred_dict = json.loads(firebase_creds_json)
                cred = credentials.Certificate(cred_dict)
            else:
                raise ValueError("Invalid Firebase credentials configuration")
        
        firebase_admin.initialize_app(cred)
    
    return auth

def verify_firebase_token(id_token):
    """Verify Firebase ID token and return user info"""
    try:
        auth_instance = initialize_firebase()
        decoded_token = auth_instance.verify_id_token(id_token)
        return decoded_token
    except Exception as e:
        print(f"Firebase token verification failed: {e}")
        return None

def get_or_create_user_from_firebase(decoded_token, auth_provider='FIREBASE'):
    """Get or create Django user from Firebase user data"""
    from django.contrib.auth import get_user_model
    from datetime import date
    import random
    
    User = get_user_model()
    
    firebase_uid = decoded_token.get('uid')
    email = decoded_token.get('email')
    email_verified = decoded_token.get('email_verified', False)
    name = decoded_token.get('name', '')
    photo_url = decoded_token.get('picture', '')
    
    # Try to find user by Firebase UID
    user = User.objects.filter(firebase_uid=firebase_uid).first()
    
    if not user and email:
        # Try to find by email
        user = User.objects.filter(email=email).first()
        if user:
            # Link Firebase UID to existing user
            user.firebase_uid = firebase_uid
            user.email_verified = email_verified
            if photo_url:
                user.firebase_photo_url = photo_url
            user.auth_provider = auth_provider
            user.save()
            print(f"✅ Linked Firebase to existing user: {user.email}")
    
    if not user:
        # Create new user
        # Generate username from email or name
        if email:
            username = email.split('@')[0]
        elif name:
            username = name.lower().replace(' ', '')
        else:
            username = f"user_{firebase_uid[:8]}"
        
        # Ensure unique username
        base_username = username
        counter = 1
        while User.objects.filter(username=username).exists():
            username = f"{base_username}{counter}"
            counter += 1
        
        # Parse name for first and last name
        first_name = ''
        last_name = ''
        if name:
            name_parts = name.split(' ', 1)
            first_name = name_parts[0]
            if len(name_parts) > 1:
                last_name = name_parts[1]
        
        # Create user with minimal required fields
        user = User.objects.create_user(
            username=username,
            email=email or f"{firebase_uid}@firebase.user",
            password=None,  # No password for Firebase users
            first_name=first_name,
            last_name=last_name,
            firebase_uid=firebase_uid,
            email_verified=email_verified,
            firebase_photo_url=photo_url,
            auth_provider=auth_provider,
            # Set default values for required fields
            goal='FITNESS',
            experience_level='BEGINNER',
            training_location='HOME',
            days_per_week=3,
            time_available=30,
        )
        
        # Create user profile
        from .models import UserProfile
        UserProfile.objects.create(user=user)
        
        print(f"✅ Created new Firebase user: {user.email} (UID: {firebase_uid})")
    
    return user

def revoke_firebase_tokens(uid):
    """Revoke all refresh tokens for a Firebase user"""
    try:
        auth_instance = initialize_firebase()
        auth_instance.revoke_refresh_tokens(uid)
        return True
    except Exception as e:
        print(f"Failed to revoke Firebase tokens: {e}")
        return False

def delete_firebase_user(uid):
    """Delete user from Firebase Auth"""
    try:
        auth_instance = initialize_firebase()
        auth_instance.delete_user(uid)
        return True
    except Exception as e:
        print(f"Failed to delete Firebase user: {e}")
        return False
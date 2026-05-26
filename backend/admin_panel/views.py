import json
from functools import wraps
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import authenticate, login, logout
from django.http import HttpResponseRedirect, JsonResponse
from django.contrib import messages
from django.conf import settings
from django.core.cache import cache
from django.core.mail import send_mail
from django.contrib.auth.tokens import default_token_generator
from django.utils.http import urlsafe_base64_encode
from django.utils.encoding import force_bytes
from apps.accounts.models import User
from apps.meals.models import MealItem
from apps.workouts.models import Workout, TemplateWorkout, Exercise, TemplateWorkoutExercise
from apps.social.models import Friend, FriendRequest, Challenge
from apps.payments.models import SubscriptionPlan, PaymentTransaction


# ==================== CUSTOM ADMIN DECORATOR ====================

def admin_required(view_func):
    """Custom decorator to check if user is admin (replaces staff_member_required)"""
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        if not request.user.is_authenticated:
            return HttpResponseRedirect('/dashboard/login/')
        if not request.user.is_staff:
            return HttpResponseRedirect('/dashboard/login/')
        return view_func(request, *args, **kwargs)
    return wrapper


# ==================== AUTHENTICATION ====================

def admin_login(request):
    """Admin login page"""
    if request.user.is_authenticated and request.user.is_staff:
        return redirect('admin_dashboard')
    
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        user = authenticate(request, username=username, password=password)
        
        if user is not None and user.is_staff:
            login(request, user)
            return redirect('admin_dashboard')
        else:
            return render(request, 'admin/login.html', {'error': 'Invalid credentials or not an admin'})
    
    return render(request, 'admin/login.html')

def admin_logout(request):
    logout(request)
    return redirect('admin_login')


# ==================== DASHBOARD ====================

@admin_required
def admin_dashboard(request):
    """Admin dashboard"""
    context = {'active_page': 'dashboard'}
    return render(request, 'admin/dashboard.html', context)


# ==================== USER MANAGEMENT ====================

@admin_required
def admin_users(request):
    """User management page"""
    context = {'active_page': 'users'}
    return render(request, 'admin/users.html', context)

@admin_required
def admin_user_detail(request, user_id):
    """View user details"""
    from apps.workouts.models import Workout
    from apps.meals.models import DailyMealLog
    from django.db.models import Sum
    
    user = get_object_or_404(User, id=user_id)
    
    workouts = Workout.objects.filter(user=user)
    workout_count = workouts.filter(is_completed=True).count()
    total_minutes = workouts.filter(is_completed=True).aggregate(Sum('duration'))['duration__sum'] or 0
    
    meals = DailyMealLog.objects.filter(user=user)
    meal_count = meals.filter(is_completed=True).count()
    
    recent_workouts = workouts.order_by('-date')[:5]
    recent_meals = meals.order_by('-date')[:5]
    
    context = {
        'active_page': 'users',
        'user_data': user,
        'workout_count': workout_count,
        'total_minutes': total_minutes,
        'meal_count': meal_count,
        'recent_workouts': recent_workouts,
        'recent_meals': recent_meals,
    }
    return render(request, 'admin/user_detail.html', context)

@admin_required
def admin_user_edit(request, user_id):
    """Edit user"""
    user = get_object_or_404(User, id=user_id)
    
    if request.method == 'POST':
        user.username = request.POST.get('username')
        user.email = request.POST.get('email')
        user.is_active = request.POST.get('is_active') == 'on'
        user.is_staff = request.POST.get('is_staff') == 'on'
        user.save()
        messages.success(request, f'User "{user.username}" updated successfully!')
        return redirect('admin_user_detail', user_id=user.id)
    
    context = {'active_page': 'users', 'user_data': user}
    return render(request, 'admin/user_edit.html', context)


# ==================== USER WORKOUTS ====================

@admin_required
def admin_user_workouts(request):
    """User workouts page - shows all workouts done by users"""
    context = {'active_page': 'user_workouts'}
    return render(request, 'admin/user_workouts.html', context)


# ==================== EXERCISE LIBRARY (NEW) ====================

@admin_required
def admin_exercise_library(request):
    """Exercise library page - manage exercises with videos"""
    context = {'active_page': 'exercise_library'}
    return render(request, 'admin/exercise_library.html', context)

@admin_required
def admin_exercise_create(request):
    """Create new exercise with video"""
    if request.method == 'POST':
        try:
            name = request.POST.get('name')
            description = request.POST.get('description', '')
            primary_goal = request.POST.get('primary_goal')
            experience_level = request.POST.get('experience_level', 'beginner')
            training_location = request.POST.get('training_location', 'home')
            equipment_needed = request.POST.get('equipment_needed', '')
            calories_per_minute = request.POST.get('calories_per_minute', 8.0)
            video_url = request.POST.get('video_url', '')
            is_active = request.POST.get('is_active') == 'on'
            
            exercise = Exercise.objects.create(
                name=name,
                description=description,
                primary_goal=primary_goal,
                experience_level=experience_level,
                training_location=training_location,
                equipment_needed=equipment_needed,
                calories_per_minute=calories_per_minute,
                video_url=video_url if video_url else None,
                is_active=is_active
            )
            
            # Handle video file upload
            if request.FILES.get('video_file'):
                exercise.video_file = request.FILES['video_file']
            
            # Handle thumbnail upload
            if request.FILES.get('thumbnail'):
                exercise.thumbnail = request.FILES['thumbnail']
            
            exercise.save()
            
            messages.success(request, f'Exercise "{exercise.name}" created successfully with video!')
            return redirect('admin_exercise_library')
            
        except Exception as e:
            messages.error(request, f'Error creating exercise: {str(e)}')
            return redirect('admin_exercise_create')
    
    context = {'active_page': 'exercise_library'}
    return render(request, 'admin/exercise_create.html', context)

@admin_required
def admin_exercise_edit(request, exercise_id):
    """Edit exercise with video"""
    exercise = get_object_or_404(Exercise, id=exercise_id)
    
    if request.method == 'POST':
        try:
            exercise.name = request.POST.get('name')
            exercise.description = request.POST.get('description', '')
            exercise.primary_goal = request.POST.get('primary_goal')
            exercise.experience_level = request.POST.get('experience_level', 'beginner')
            exercise.training_location = request.POST.get('training_location', 'home')
            exercise.equipment_needed = request.POST.get('equipment_needed', '')
            exercise.calories_per_minute = request.POST.get('calories_per_minute', 8.0)
            exercise.is_active = request.POST.get('is_active') == 'on'
            
            # Handle video URL
            video_url = request.POST.get('video_url', '').strip()
            if video_url:
                exercise.video_url = video_url
            
            # Handle video file upload - Direct Cloudinary upload
            if request.FILES.get('video_file'):
                video_file = request.FILES['video_file']
                print(f"Processing video file: {video_file.name}")
                
                try:
                    # Upload directly to Cloudinary with correct resource type
                    import cloudinary.uploader
                    result = cloudinary.uploader.upload(
                        video_file,
                        resource_type="video",  # CRITICAL: Force video type
                        folder="exercise_videos",
                        public_id=f"exercise_{exercise.id}_{video_file.name.split('.')[0]}"
                    )
                    
                    # Store the Cloudinary URL instead of the file
                    exercise.video_url = result['secure_url']
                    print(f"✅ Video uploaded to Cloudinary: {result['secure_url']}")
                    
                    # Clear the file field since we're using URL
                    if exercise.video_file:
                        exercise.video_file = None
                        
                except Exception as e:
                    print(f"❌ Cloudinary upload error: {str(e)}")
                    messages.error(request, f'Video upload failed: {str(e)}')
                    return redirect('admin_exercise_edit', exercise_id=exercise_id)
            
            # Handle thumbnail upload
            if request.FILES.get('thumbnail'):
                exercise.thumbnail = request.FILES['thumbnail']
            
            exercise.save()
            
            messages.success(request, f'Exercise "{exercise.name}" updated successfully!')
            return redirect('admin_exercise_library')
            
        except Exception as e:
            messages.error(request, f'Error updating exercise: {str(e)}')
            return redirect('admin_exercise_edit', exercise_id=exercise_id)
    
    context = {
        'active_page': 'exercise_library',
        'exercise': exercise
    }
    return render(request, 'admin/exercise_edit.html', context)

@admin_required
def admin_exercise_delete(request, exercise_id):
    """Delete exercise"""
    if request.method == 'POST':
        try:
            exercise = Exercise.objects.get(id=exercise_id)
            exercise_name = exercise.name
            exercise.delete()
            messages.success(request, f'Exercise "{exercise_name}" deleted successfully!')
        except Exercise.DoesNotExist:
            messages.error(request, 'Exercise not found')
    
    return redirect('admin_exercise_library')


# ==================== WORKOUT LIBRARY (UPDATED) ====================

@admin_required
def admin_workout_library(request):
    """Workout library page - templates created by admin"""
    context = {'active_page': 'workout_library'}
    return render(request, 'admin/workout_library.html', context)

@admin_required
def admin_workout_library_create(request):
    """Create new workout template with exercises from library"""
    exercises = Exercise.objects.filter(is_active=True)
    
    if request.method == 'POST':
        try:
            name = request.POST.get('name')
            duration = request.POST.get('duration', 30)
            goal = request.POST.get('goal', 'FITNESS')
            experience_level = request.POST.get('experience_level', 'BEGINNER')
            training_location = request.POST.get('training_location', 'HOME')
            description = request.POST.get('description', '')
            is_active = request.POST.get('is_active') == 'on'
            
            # Get selected exercises with their parameters
            selected_exercises = []
            exercise_ids = request.POST.getlist('exercise_ids')
            sets_list = request.POST.getlist('sets')
            reps_list = request.POST.getlist('reps')
            durations_list = request.POST.getlist('duration_seconds')
            rests_list = request.POST.getlist('rest_seconds')
            
            for idx, exercise_id in enumerate(exercise_ids):
                if exercise_id:
                    exercise = Exercise.objects.get(id=exercise_id)
                    exercise_data = {
                        'name': exercise.name,
                        'exercise_id': str(exercise.id),
                        'sets': int(sets_list[idx]) if idx < len(sets_list) else 3,
                        'reps': int(reps_list[idx]) if reps_list[idx] and idx < len(reps_list) else None,
                        'duration': int(durations_list[idx]) if durations_list[idx] and idx < len(durations_list) else None,
                        'rest': int(rests_list[idx]) if idx < len(rests_list) else 30,
                        'video_url': exercise.get_video_url(),
                        'has_video': exercise.has_video()
                    }
                    selected_exercises.append(exercise_data)
            
            template = TemplateWorkout.objects.create(
                name=name,
                default_duration=duration,
                goal=goal,
                experience_level=experience_level,
                training_location=training_location,
                description=description,
                exercises=selected_exercises,
                is_active=is_active,
                created_by=request.user
            )
            
            # Handle image upload - Upload to Cloudinary
            if request.FILES.get('image'):
                image_file = request.FILES['image']
                
                # Upload to Cloudinary
                import cloudinary.uploader
                result = cloudinary.uploader.upload(
                    image_file,
                    folder="workout_images",
                    public_id=f"workout_{template.id}_{name.lower().replace(' ', '_')}"
                )
                
                # Store the Cloudinary URL
                template.image = result['secure_url']
                template.save()
                print(f"✅ Workout image uploaded to Cloudinary: {result['secure_url']}")
            
            messages.success(request, f'Workout "{template.name}" created successfully with {len(selected_exercises)} exercises!')
            return redirect('admin_workout_library')
            
        except Exception as e:
            messages.error(request, f'Error creating workout: {str(e)}')
            return redirect('admin_workout_library_create')
    
    context = {
        'active_page': 'workout_library',
        'exercises': exercises,
        'goals': ['FITNESS', 'STRENGTH', 'MUSCLE_GAIN', 'ENDURANCE', 'WEIGHT_LOSS'],
        'experience_levels': ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'],
        'locations': ['HOME', 'GYM', 'OUTDOOR']
    }
    return render(request, 'admin/workout_library_create.html', context)

@admin_required
def admin_workout_library_edit(request, workout_id):
    """Edit workout in library"""
    template = get_object_or_404(TemplateWorkout, id=workout_id)
    exercises = Exercise.objects.filter(is_active=True)
    
    if request.method == 'POST':
        try:
            template.name = request.POST.get('name')
            template.default_duration = request.POST.get('duration', 30)
            template.goal = request.POST.get('goal', 'FITNESS')
            template.experience_level = request.POST.get('experience_level', 'BEGINNER')
            template.training_location = request.POST.get('training_location', 'HOME')
            template.description = request.POST.get('description', '')
            template.is_active = request.POST.get('is_active') == 'on'
            
            # Read exercises from the JSON field
            exercises_json = request.POST.get('exercises_json', '[]')
            print(f"📋 Exercises JSON: {exercises_json[:200]}")  # Debug
            
            try:
                exercises_data = json.loads(exercises_json)
                print(f"📋 Parsed {len(exercises_data)} exercises")
                
                # Process each exercise
                processed_exercises = []
                for ex_data in exercises_data:
                    exercise_name = ex_data.get('name')
                    if exercise_name:
                        # Find exercise in library to get video info
                        db_exercise = Exercise.objects.filter(name=exercise_name).first()
                        
                        exercise_item = {
                            'name': exercise_name,
                            'sets': ex_data.get('sets', 3),
                            'rest': ex_data.get('rest', 30),
                        }
                        
                        if ex_data.get('reps'):
                            exercise_item['reps'] = ex_data.get('reps')
                        if ex_data.get('duration'):
                            exercise_item['duration'] = ex_data.get('duration')
                        
                        if db_exercise:
                            exercise_item['exercise_id'] = str(db_exercise.id)
                            exercise_item['video_url'] = db_exercise.get_video_url()
                            exercise_item['has_video'] = db_exercise.has_video()
                        
                        processed_exercises.append(exercise_item)
                
                template.exercises = processed_exercises
                print(f"✅ Saved {len(processed_exercises)} exercises")
                
            except json.JSONDecodeError as e:
                print(f"❌ JSON decode error: {e}")
                messages.error(request, f'Error parsing exercises: {e}')
                return redirect('admin_workout_library_edit', workout_id=workout_id)
            
            # Handle image upload
            if request.FILES.get('image'):
                import cloudinary.uploader
                result = cloudinary.uploader.upload(
                    request.FILES['image'],
                    folder="workout_images",
                    public_id=template.name.lower().replace(' ', '_')
                )
                template.image = result['secure_url']
            
            template.save()
            messages.success(request, f'Workout "{template.name}" updated successfully!')
            return redirect('admin_workout_library')
            
        except Exception as e:
            messages.error(request, f'Error updating workout: {str(e)}')
            return redirect('admin_workout_library_edit', workout_id=workout_id)
    
    context = {
        'active_page': 'workout_library',
        'workout': template,
        'exercises': exercises,
        'goals': ['FITNESS', 'STRENGTH', 'MUSCLE_GAIN', 'ENDURANCE', 'WEIGHT_LOSS'],
        'experience_levels': ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'],
        'locations': ['HOME', 'GYM', 'OUTDOOR']
    }
    return render(request, 'admin/workout_library_edit.html', context)

@admin_required
def admin_workout_library_view(request, workout_id):
    """View workout details"""
    template = get_object_or_404(TemplateWorkout, id=workout_id)
    context = {
        'active_page': 'workout_library',
        'workout': template,
    }
    return render(request, 'admin/workout_library_view.html', context)


# ==================== MEAL MANAGEMENT ====================

@admin_required
def admin_meals(request):
    """Meal management page"""
    context = {'active_page': 'meals'}
    return render(request, 'admin/meals.html', context)

@admin_required
def admin_meal_detail(request, meal_id):
    """View meal details"""
    meal = get_object_or_404(MealItem, id=meal_id)
    context = {'active_page': 'meals', 'meal': meal}
    return render(request, 'admin/meal_detail.html', context)

@admin_required
def admin_meal_edit(request, meal_id):
    """Edit meal"""
    meal = get_object_or_404(MealItem, id=meal_id)
    
    if request.method == 'POST':
        meal.name = request.POST.get('name')
        meal.meal_type = request.POST.get('meal_type')
        meal.calories = request.POST.get('calories') or None
        meal.protein = request.POST.get('protein') or None
        meal.carbs = request.POST.get('carbs') or None
        meal.fats = request.POST.get('fats') or None
        meal.is_vegetarian = request.POST.get('is_vegetarian') == 'on'
        meal.is_vegan = request.POST.get('is_vegan') == 'on'
        meal.is_gluten_free = request.POST.get('is_gluten_free') == 'on'
        meal.is_active = request.POST.get('is_active') == 'on'
        meal.save()
        return redirect('admin_meal_detail', meal_id=meal.id)
    
    context = {'active_page': 'meals', 'meal': meal}
    return render(request, 'admin/meal_edit.html', context)

@admin_required
def admin_meal_create(request):
    """Create new meal"""
    if request.method == 'POST':
        meal = MealItem.objects.create(
            name=request.POST.get('name'),
            meal_type=request.POST.get('meal_type'),
            calories=request.POST.get('calories') or None,
            protein=request.POST.get('protein') or None,
            carbs=request.POST.get('carbs') or None,
            fats=request.POST.get('fats') or None,
            is_vegetarian=request.POST.get('is_vegetarian') == 'on',
            is_vegan=request.POST.get('is_vegan') == 'on',
            is_gluten_free=request.POST.get('is_gluten_free') == 'on',
            is_active=True
        )
        return redirect('admin_meal_detail', meal_id=meal.id)
    
    context = {'active_page': 'meals'}
    return render(request, 'admin/meal_create.html', context)


# ==================== SOCIAL MANAGEMENT ====================

@admin_required
def admin_social(request):
    """Social management page"""
    context = {'active_page': 'social'}
    return render(request, 'admin/social.html', context)

@admin_required
def admin_challenges(request):
    """Challenges management"""
    context = {'active_page': 'social'}
    return render(request, 'admin/challenges.html', context)

@admin_required
def admin_challenge_create(request):
    """Create challenge"""
    if request.method == 'POST':
        return redirect('admin_challenges')
    context = {'active_page': 'social'}
    return render(request, 'admin/challenge_create.html', context)


# ==================== PAYMENT MANAGEMENT ====================

@admin_required
def admin_payments(request):
    """Payment management page"""
    context = {'active_page': 'payments'}
    return render(request, 'admin/payments.html', context)

@admin_required
def admin_subscriptions(request):
    """Subscription management"""
    if request.method == 'POST':
        return redirect('admin_subscriptions')
    context = {'active_page': 'payments'}
    return render(request, 'admin/subscriptions.html', context)


# ==================== ANALYTICS ====================

@admin_required
def admin_analytics(request):
    """Analytics page"""
    context = {'active_page': 'analytics'}
    return render(request, 'admin/analytics.html', context)


# ==================== SETTINGS ====================

@admin_required
def admin_settings(request):
    """Settings page"""
    context = {'active_page': 'settings'}
    return render(request, 'admin/settings.html', context)

@admin_required
def admin_change_password(request):
    """Change admin's own password"""
    from django.contrib.auth import update_session_auth_hash
    
    if request.method == 'POST':
        current_password = request.POST.get('current_password')
        new_password = request.POST.get('new_password')
        confirm_password = request.POST.get('confirm_password')
        
        if not request.user.check_password(current_password):
            messages.error(request, 'Current password is incorrect')
        elif new_password != confirm_password:
            messages.error(request, 'New passwords do not match')
        elif len(new_password) < 8:
            messages.error(request, 'Password must be at least 8 characters')
        else:
            request.user.set_password(new_password)
            request.user.save()
            update_session_auth_hash(request, request.user)
            messages.success(request, 'Password changed successfully!')
        
        return redirect('admin_settings')
    
    return redirect('admin_settings')


# ==================== API ENDPOINTS (UPDATED) ====================

@admin_required
def api_dashboard_stats(request):
    """Get dashboard statistics"""
    total_users = User.objects.count()
    active_users = User.objects.filter(is_active=True).count()
    total_workouts = Workout.objects.count()
    completed_workouts = Workout.objects.filter(is_completed=True).count()
    completion_rate = round((completed_workouts / total_workouts) * 100, 1) if total_workouts > 0 else 0
    # Updated to use is_subscription_active instead of subscription_tier
    premium_users = User.objects.filter(is_subscription_active=True).count()
    total_meals = MealItem.objects.count()
    total_templates = TemplateWorkout.objects.count()
    total_exercises = Exercise.objects.count()
    exercises_with_video = Exercise.objects.exclude(video_url__isnull=True, video_file__isnull=True).count()
    
    return JsonResponse({
        'total_users': total_users,
        'active_users': active_users,
        'total_workouts': total_workouts,
        'completed_workouts': completed_workouts,
        'completion_rate': completion_rate,
        'premium_users': premium_users,
        'total_meals': total_meals,
        'total_templates': total_templates,
        'total_exercises': total_exercises,
        'exercises_with_video': exercises_with_video,
        'video_coverage': round((exercises_with_video / total_exercises * 100), 1) if total_exercises > 0 else 0,
    })

@admin_required
def api_users_list(request):
    """Get list of users with pagination"""
    from django.core.paginator import Paginator
    from django.db.models import Q
    
    search = request.GET.get('search', '')
    page = int(request.GET.get('page', 1))
    per_page = int(request.GET.get('per_page', 20))
    
    users = User.objects.all().order_by('-date_joined')
    
    if search:
        users = users.filter(
            Q(username__icontains=search) | Q(email__icontains=search)
        )
    
    total_users = User.objects.count()
    active_users = User.objects.filter(is_active=True).count()
    # Updated to use is_subscription_active
    premium_users = User.objects.filter(is_subscription_active=True).count()
    
    paginator = Paginator(users, per_page)
    page_obj = paginator.get_page(page)
    
    data = []
    for user in page_obj:
        workout_count = Workout.objects.filter(user=user, is_completed=True).count()
        
        data.append({
            'id': str(user.id),
            'username': user.username,
            'email': user.email,
            'subscription_active': user.is_subscription_active,  # Changed from subscription_tier
            'streak_days': user.streak_days,
            'date_joined': user.date_joined.strftime('%Y-%m-%d'),
            'is_active': user.is_active,
            'is_staff': user.is_staff,
            'workout_count': workout_count,
        })
    
    return JsonResponse({
        'users': data,
        'total_users': total_users,
        'active_users': active_users,
        'premium_users': premium_users,
        'total': paginator.count,
        'page': page,
        'total_pages': paginator.num_pages,
    })

@admin_required
def api_user_delete(request, user_id):
    """Delete a user"""
    try:
        user = User.objects.get(id=user_id)
        user.delete()
        return JsonResponse({'success': True})
    except User.DoesNotExist:
        return JsonResponse({'success': False, 'error': 'User not found'})

@admin_required
def api_user_ban(request, user_id):
    """Ban/unban a user"""
    try:
        user = User.objects.get(id=user_id)
        user.is_active = not user.is_active
        user.save()
        return JsonResponse({'success': True, 'is_active': user.is_active})
    except User.DoesNotExist:
        return JsonResponse({'success': False})

@admin_required
def api_user_workouts_list(request):
    """Get list of user workouts"""
    search = request.GET.get('search', '')
    
    workouts = Workout.objects.all().order_by('-date')
    
    if search:
        workouts = workouts.filter(user__username__icontains=search)
    
    total_workouts = Workout.objects.count()
    completed_workouts = Workout.objects.filter(is_completed=True).count()
    completion_rate = round((completed_workouts / total_workouts) * 100, 1) if total_workouts > 0 else 0
    unique_users = Workout.objects.values('user').distinct().count()
    
    data = []
    for workout in workouts:
        data.append({
            'id': str(workout.id),
            'user__username': workout.user.username,
            'date': workout.date.strftime('%Y-%m-%d') if workout.date else '-',
            'duration': workout.duration,
            'calories_burned': workout.calories_burned,
            'is_completed': workout.is_completed,
            'completed_at': workout.completed_at.strftime('%Y-%m-%d %H:%M') if workout.completed_at else None,
            'exercises': workout.exercises[:3] if workout.exercises else [],
        })
    
    return JsonResponse({
        'workouts': data,
        'total_workouts': total_workouts,
        'completed_workouts': completed_workouts,
        'completion_rate': completion_rate,
        'unique_users': unique_users,
    })

@admin_required
def api_user_workout_delete(request, workout_id):
    """Delete a user workout"""
    try:
        workout = Workout.objects.get(id=workout_id)
        workout.delete()
        return JsonResponse({'success': True})
    except Workout.DoesNotExist:
        return JsonResponse({'success': False, 'error': 'Workout not found'})

# NEW: Exercise Library APIs
@admin_required
def api_exercises_list(request):
    """Get list of exercises with video info"""
    search = request.GET.get('search', '')
    primary_goal = request.GET.get('goal', '')
    training_location = request.GET.get('location', '')
    
    exercises = Exercise.objects.all().order_by('name')
    
    if search:
        exercises = exercises.filter(name__icontains=search)
    if primary_goal:
        exercises = exercises.filter(primary_goal=primary_goal)
    if training_location:
        exercises = exercises.filter(training_location=training_location)
    
    data = []
    for exercise in exercises:
        data.append({
            'id': str(exercise.id),
            'name': exercise.name,
            'description': exercise.description,
            'primary_goal': exercise.primary_goal,
            'experience_level': exercise.experience_level,
            'training_location': exercise.training_location,
            'equipment_needed': exercise.equipment_needed,
            'calories_per_minute': exercise.calories_per_minute,
            'video_url': exercise.get_video_url(),
            'has_video': exercise.has_video(),
            'thumbnail': exercise.thumbnail.url if exercise.thumbnail else None,
            'is_active': exercise.is_active,
            'created_at': exercise.created_at.strftime('%Y-%m-%d %H:%M'),
        })
    
    return JsonResponse({
        'exercises': data,
        'total': len(data),
    })

@admin_required
def api_exercise_detail(request, exercise_id):
    """Get single exercise details"""
    try:
        exercise = Exercise.objects.get(id=exercise_id)
        return JsonResponse({
            'id': str(exercise.id),
            'name': exercise.name,
            'description': exercise.description,
            'primary_goal': exercise.primary_goal,
            'experience_level': exercise.experience_level,
            'training_location': exercise.training_location,
            'equipment_needed': exercise.equipment_needed,
            'calories_per_minute': exercise.calories_per_minute,
            'video_url': exercise.video_url,
            'video_file_url': exercise.video_file.url if exercise.video_file else None,
            'has_video': exercise.has_video(),
            'thumbnail': exercise.thumbnail.url if exercise.thumbnail else None,
            'is_active': exercise.is_active,
        })
    except Exercise.DoesNotExist:
        return JsonResponse({'error': 'Exercise not found'}, status=404)

@admin_required
def api_workout_library_list(request):
    """Get workout library (templates) with video info"""
    templates = TemplateWorkout.objects.all().order_by('-id')
    
    data = []
    for template in templates:
        # Count how many exercises in this template have videos
        exercises_with_video = 0
        for exercise in (template.exercises or []):
            if exercise.get('has_video', False) or exercise.get('video_url'):
                exercises_with_video += 1
        
        data.append({
            'id': str(template.id),
            'name': template.name,
            'duration': template.default_duration,
            'description': getattr(template, 'description', ''),
            'goal': getattr(template, 'goal', 'FITNESS'),
            'experience_level': getattr(template, 'experience_level', 'BEGINNER'),
            'training_location': getattr(template, 'training_location', 'HOME'),
            'exercises': template.exercises,
            'exercises_count': len(template.exercises) if template.exercises else 0,
            'exercises_with_video': exercises_with_video,
            'has_videos': exercises_with_video > 0,
            'is_active': template.is_active,
            # FIXED: Remove .url since image is now a string
            'image_url': template.image if template.image else None,
        })
    
    return JsonResponse({
        'templates': data,
        'total': len(data),
    })

@admin_required
def api_workout_library_delete(request, workout_id):
    """Delete workout from library"""
    try:
        template = TemplateWorkout.objects.get(id=workout_id)
        template.delete()
        return JsonResponse({'success': True, 'message': 'Workout deleted successfully!'})
    except TemplateWorkout.DoesNotExist:
        return JsonResponse({'error': 'Workout not found'}, status=404)

@admin_required
def api_meals_list(request):
    """Get list of meals"""
    search = request.GET.get('search', '')
    meal_type = request.GET.get('type', '')
    
    meals = MealItem.objects.all().order_by('-created_at')
    
    if search:
        meals = meals.filter(name__icontains=search)
    if meal_type:
        meals = meals.filter(meal_type=meal_type)
    
    data = []
    for meal in meals:
        data.append({
            'id': str(meal.id),
            'name': meal.name,
            'meal_type': meal.get_meal_type_display(),
            'calories': meal.calories,
            'protein': meal.protein,
            'carbs': meal.carbs,
            'fats': meal.fats,
            'is_active': meal.is_active,
        })
    
    return JsonResponse({'meals': data})

@admin_required
def api_meal_delete(request, meal_id):
    """Delete a meal"""
    try:
        meal = MealItem.objects.get(id=meal_id)
        meal.delete()
        return JsonResponse({'success': True})
    except MealItem.DoesNotExist:
        return JsonResponse({'success': False})

@admin_required
def api_social_stats(request):
    """Get social statistics"""
    return JsonResponse({
        'total_friendships': Friend.objects.filter(status='ACCEPTED').count(),
        'active_challenges': Challenge.objects.filter(is_active=True).count(),
        'pending_requests': FriendRequest.objects.filter(status='PENDING').count(),
    })

@admin_required
def api_challenges_list(request):
    """Get list of challenges"""
    challenges = Challenge.objects.filter(is_active=True).values('id', 'name', 'challenge_type', 'target_value')
    return JsonResponse({'challenges': list(challenges)})

@admin_required
def api_payments_stats(request):
    """Get payment statistics"""
    return JsonResponse({
        'total_revenue': 0,
        'monthly_revenue': 0,
        'active_subscriptions': User.objects.filter(is_subscription_active=True).count(),  # Updated
        'success_rate': 100,
    })

@admin_required
def api_plans_list(request):
    """Get subscription plans"""
    plans = SubscriptionPlan.objects.filter(is_active=True).values('id', 'name', 'amount', 'interval', 'features')
    return JsonResponse({'plans': list(plans)})

@admin_required
def api_transactions_list(request):
    """Get recent transactions"""
    transactions = PaymentTransaction.objects.all().order_by('-created_at')[:50].values(
        'user__username', 'amount', 'payment_type', 'status', 'created_at'
    )
    return JsonResponse({'transactions': list(transactions)})

@admin_required
def api_analytics_data(request):
    """Get analytics data for charts"""
    from django.db.models import Count
    from datetime import timedelta
    from django.utils import timezone
    
    thirty_days_ago = timezone.now().date() - timedelta(days=30)
    
    user_growth = []
    for i in range(30, 0, -7):
        start_date = timezone.now().date() - timedelta(days=i)
        end_date = start_date + timedelta(days=6)
        count = User.objects.filter(date_joined__date__gte=start_date, date_joined__date__lte=end_date).count()
        user_growth.append(count)
    
    return JsonResponse({
        'user_growth': {'labels': ['Week 1', 'Week 2', 'Week 3', 'Week 4'], 'values': user_growth[:4]},
        'completion_rate': {'completed': Workout.objects.filter(is_completed=True).count(), 'not_completed': Workout.objects.filter(is_completed=False).count()},
        'retention': {'day1': 0, 'day7': 0, 'day30': 0},
        'revenue': {'labels': [], 'values': []},
        'popular_workouts': {'labels': [], 'values': []},
        'meal_preferences': {'labels': [], 'values': []},
        'top_users': [],
    })

@admin_required
def api_reset_user_password(request):
    """Send password reset link to a user"""
    if request.method == 'POST':
        data = json.loads(request.body)
        email = data.get('email')
        
        try:
            user = User.objects.get(email=email)
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            token = default_token_generator.make_token(user)
            reset_link = f"{settings.FRONTEND_URL}/reset-password/{uid}/{token}"
            
            send_mail(
                'Password Reset Request',
                f'Click the link to reset your password: {reset_link}',
                settings.DEFAULT_FROM_EMAIL,
                [email],
                fail_silently=False,
            )
            return JsonResponse({'success': True})
        except User.DoesNotExist:
            return JsonResponse({'error': 'User not found'}, status=404)
    
    return JsonResponse({'error': 'Invalid method'}, status=400)

@admin_required
def api_create_admin(request):
    """Create a new admin account"""
    if request.method == 'POST':
        import secrets
        import string
        
        data = json.loads(request.body)
        email = data.get('email')
        
        if not email:
            return JsonResponse({'error': 'Email is required'}, status=400)
        
        alphabet = string.ascii_letters + string.digits
        password = ''.join(secrets.choice(alphabet) for i in range(12))
        
        try:
            user = User.objects.create_user(
                username=email.split('@')[0],
                email=email,
                password=password,
                is_staff=True,
                is_active=True
            )
            
            send_mail(
                'Admin Account Created',
                f'Your admin account has been created.\n\nEmail: {email}\nPassword: {password}\n\nPlease change your password after logging in.',
                settings.DEFAULT_FROM_EMAIL,
                [email],
                fail_silently=False,
            )
            return JsonResponse({'success': True})
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=400)
    
    return JsonResponse({'error': 'Invalid method'}, status=400)

@admin_required
def api_clear_cache(request):
    """Clear Django cache"""
    cache.clear()
    return JsonResponse({'success': True})

@admin_required
def api_clear_logs(request):
    """Clear log files"""
    import os
    import glob
    from django.conf import settings
    
    log_dir = settings.BASE_DIR / 'logs'
    if log_dir.exists():
        log_files = glob.glob(str(log_dir / '*.log'))
        for log_file in log_files:
            with open(log_file, 'w') as f:
                f.write('')
    
    return JsonResponse({'success': True})

@admin_required
def api_backup_database(request):
    """Backup database to JSON"""
    from django.core import serializers
    from django.http import HttpResponse
    
    backup_data = {}
    users = User.objects.all()
    backup_data['users'] = json.loads(serializers.serialize('json', users))
    
    response = HttpResponse(json.dumps(backup_data, indent=2), content_type='application/json')
    response['Content-Disposition'] = 'attachment; filename="riadha_backup.json"'
    return response

@admin_required
def api_exercise_delete(request, exercise_id):
    """Delete an exercise"""
    if request.method == 'DELETE':
        try:
            exercise = Exercise.objects.get(id=exercise_id)
            exercise_name = exercise.name
            exercise.delete()
            return JsonResponse({'success': True, 'message': f'Exercise "{exercise_name}" deleted successfully!'})
        except Exercise.DoesNotExist:
            return JsonResponse({'error': 'Exercise not found'}, status=404)
    return JsonResponse({'error': 'Invalid method'}, status=400)
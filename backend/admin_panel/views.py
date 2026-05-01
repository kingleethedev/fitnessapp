# admin_panel/views.py
import json
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import authenticate, login, logout
from django.contrib.admin.views.decorators import staff_member_required
from django.http import JsonResponse
from django.contrib import messages
from apps.accounts.models import User
from apps.meals.models import MealItem
from apps.workouts.models import Workout, TemplateWorkout
from apps.social.models import Friend, FriendRequest, Challenge
from apps.payments.models import SubscriptionPlan, PaymentTransaction

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

@staff_member_required
def admin_dashboard(request):
    """Admin dashboard"""
    context = {'active_page': 'dashboard'}
    return render(request, 'admin/dashboard.html', context)

# ==================== USER MANAGEMENT ====================

@staff_member_required
def admin_users(request):
    """User management page"""
    users = User.objects.all().order_by('-date_joined')
    context = {'active_page': 'users', 'users': users}
    return render(request, 'admin/users.html', context)

@staff_member_required
def admin_user_detail(request, user_id):
    """View user details"""
    user = get_object_or_404(User, id=user_id)
    context = {'active_page': 'users', 'user_data': user}
    return render(request, 'admin/user_detail.html', context)

@staff_member_required
def admin_user_edit(request, user_id):
    """Edit user"""
    user = get_object_or_404(User, id=user_id)
    
    if request.method == 'POST':
        user.username = request.POST.get('username')
        user.email = request.POST.get('email')
        user.is_active = request.POST.get('is_active') == 'on'
        user.is_staff = request.POST.get('is_staff') == 'on'
        user.save()
        return redirect('admin_user_detail', user_id=user.id)
    
    context = {'active_page': 'users', 'user_data': user}
    return render(request, 'admin/user_edit.html', context)

# ==================== USER WORKOUTS (what users have done) ====================

@staff_member_required
def admin_user_workouts(request):
    """User workouts page - shows all workouts done by users"""
    context = {'active_page': 'user_workouts'}
    return render(request, 'admin/user_workouts.html', context)

# ==================== WORKOUT LIBRARY (templates) ====================

@staff_member_required
def admin_workout_library(request):
    """Workout library page - templates created by admin"""
    context = {'active_page': 'workout_library'}
    return render(request, 'admin/workout_library.html', context)

# ==================== MEAL MANAGEMENT ====================

@staff_member_required
def admin_meals(request):
    """Meal management page"""
    meals = MealItem.objects.all().order_by('-created_at')
    context = {'active_page': 'meals', 'meals': meals}
    return render(request, 'admin/meals.html', context)

@staff_member_required
def admin_meal_detail(request, meal_id):
    """View meal details"""
    meal = get_object_or_404(MealItem, id=meal_id)
    context = {'active_page': 'meals', 'meal': meal}
    return render(request, 'admin/meal_detail.html', context)

@staff_member_required
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

@staff_member_required
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

@staff_member_required
def admin_social(request):
    """Social management page"""
    context = {'active_page': 'social'}
    return render(request, 'admin/social.html', context)

@staff_member_required
def admin_challenges(request):
    """Challenges management"""
    context = {'active_page': 'social'}
    return render(request, 'admin/challenges.html', context)

@staff_member_required
def admin_challenge_create(request):
    """Create challenge"""
    if request.method == 'POST':
        return redirect('admin_challenges')
    context = {'active_page': 'social'}
    return render(request, 'admin/challenge_create.html', context)

# ==================== PAYMENT MANAGEMENT ====================

@staff_member_required
def admin_payments(request):
    """Payment management page"""
    context = {'active_page': 'payments'}
    return render(request, 'admin/payments.html', context)

@staff_member_required
def admin_subscriptions(request):
    """Subscription management"""
    if request.method == 'POST':
        return redirect('admin_subscriptions')
    context = {'active_page': 'payments'}
    return render(request, 'admin/subscriptions.html', context)

# ==================== ANALYTICS ====================

@staff_member_required
def admin_analytics(request):
    """Analytics page"""
    context = {'active_page': 'analytics'}
    return render(request, 'admin/analytics.html', context)

# ==================== SETTINGS ====================

@staff_member_required
def admin_settings(request):
    """Settings page"""
    context = {'active_page': 'settings'}
    return render(request, 'admin/settings.html', context)

# ==================== API ENDPOINTS ====================

@staff_member_required
def api_dashboard_stats(request):
    """Get dashboard statistics"""
    total_users = User.objects.count()
    active_users = User.objects.filter(is_active=True).count()
    total_workouts = Workout.objects.filter(is_completed=True).count()
    
    return JsonResponse({
        'total_users': total_users,
        'active_users': active_users,
        'total_workouts': total_workouts,
    })

@staff_member_required
def api_users_list(request):
    """Get list of users"""
    users = User.objects.all().values('id', 'username', 'email', 'subscription_tier', 'streak_days', 'date_joined', 'is_active')
    return JsonResponse({'users': list(users)})

@staff_member_required
def api_user_delete(request, user_id):
    """Delete a user"""
    try:
        user = User.objects.get(id=user_id)
        user.delete()
        return JsonResponse({'success': True})
    except User.DoesNotExist:
        return JsonResponse({'success': False, 'error': 'User not found'})

@staff_member_required
def api_user_ban(request, user_id):
    """Ban/unban a user"""
    try:
        user = User.objects.get(id=user_id)
        user.is_active = not user.is_active
        user.save()
        return JsonResponse({'success': True, 'is_active': user.is_active})
    except User.DoesNotExist:
        return JsonResponse({'success': False})

# User Workouts API
@staff_member_required
def api_user_workouts_list(request):
    """Get list of user workouts (completed by users)"""
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
            'id': workout.id,
            'user__username': workout.user.username,
            'date': workout.date.strftime('%Y-%m-%d') if workout.date else '-',
            'duration': workout.duration,
            'calories_burned': workout.calories_burned,
            'is_completed': workout.is_completed,
            'completed_at': workout.completed_at.strftime('%Y-%m-%d %H:%M') if workout.completed_at else None,
            'exercises': workout.exercises,
        })
    
    return JsonResponse({
        'workouts': data,
        'total_workouts': total_workouts,
        'completed_workouts': completed_workouts,
        'completion_rate': completion_rate,
        'unique_users': unique_users,
    })

@staff_member_required
def api_user_workout_delete(request, workout_id):
    """Delete a user workout"""
    try:
        workout = Workout.objects.get(id=workout_id)
        workout.delete()
        return JsonResponse({'success': True})
    except Workout.DoesNotExist:
        return JsonResponse({'success': False, 'error': 'Workout not found'})

# Workout Library API
@staff_member_required
@staff_member_required
def api_workout_library_list(request):
    """Get workout library (templates)"""
    from apps.workouts.models import TemplateWorkout, Workout
    
    templates = TemplateWorkout.objects.all().order_by('-id')
    
    data = []
    for template in templates:
        usage_count = Workout.objects.filter(template_id=template.id).count()
        
        data.append({
            'id': template.id,
            'name': template.name,
            'duration': template.default_duration,
            'difficulty': getattr(template, 'difficulty_level', 'medium'),
            'category': getattr(template, 'category', 'full_body'),
            'description': getattr(template, 'description', ''),
            'exercises': template.exercises,
            'is_active': template.is_active,
            'usage_count': usage_count,
        })
    
    return JsonResponse({
        'templates': data,
        'total': len(data),
    })

@staff_member_required
def admin_workout_library_create(request):
    """Create new workout template"""
    from apps.workouts.models import TemplateWorkout
    import json
    
    if request.method == 'POST':
        try:
            # Get form data
            name = request.POST.get('name')
            duration = request.POST.get('duration', 30)
            goal = request.POST.get('goal', 'FITNESS')
            experience_level = request.POST.get('experience_level', 'BEGINNER')
            training_location = request.POST.get('training_location', 'HOME')
            description = request.POST.get('description', '')
            exercises_json = request.POST.get('exercises_json', '[]')
            is_active = request.POST.get('is_active') == 'on'
            
            # Parse exercises
            exercises = json.loads(exercises_json)
            
            # Create template
            template = TemplateWorkout.objects.create(
                name=name,
                default_duration=duration,
                goal=goal,
                experience_level=experience_level,
                training_location=training_location,
                description=description,
                exercises=exercises,
                is_active=is_active
            )
            
            # Handle image upload
            if request.FILES.get('image'):
                template.image = request.FILES['image']
                template.save()
            
            from django.contrib import messages
            messages.success(request, f'Workout "{template.name}" created successfully!')
            return redirect('admin_workout_library')
            
        except Exception as e:
            from django.contrib import messages
            messages.error(request, f'Error creating workout: {str(e)}')
            return redirect('admin_workout_library_create')
    
    context = {
        'active_page': 'workout_library',
    }
    return render(request, 'admin/workout_library_create.html', context)
@staff_member_required
def api_workout_library_list(request):
    """Get workout library (templates)"""
    from apps.workouts.models import TemplateWorkout
    
    templates = TemplateWorkout.objects.all().order_by('-id')
    
    data = []
    for template in templates:
        data.append({
            'id': template.id,
            'name': template.name,
            'duration': template.default_duration,
            'description': getattr(template, 'description', ''),
            'goal': getattr(template, 'goal', 'FITNESS'),
            'experience_level': getattr(template, 'experience_level', 'BEGINNER'),
            'training_location': getattr(template, 'training_location', 'HOME'),
            'exercises': template.exercises,
            'is_active': template.is_active,
            'image_url': template.image.url if template.image else None,
        })
    
    return JsonResponse({
        'templates': data,
        'total': len(data),
    })

@staff_member_required
def api_workout_library_create(request):
    """Create a new workout in library with image support"""
    from apps.workouts.models import TemplateWorkout
    
    if request.method == 'POST':
        try:
            # Handle form data with image
            name = request.POST.get('name')
            default_duration = request.POST.get('duration', 30)
            goal = request.POST.get('goal', 'FITNESS')
            experience_level = request.POST.get('experience_level', 'BEGINNER')
            training_location = request.POST.get('training_location', 'HOME')
            description = request.POST.get('description', '')
            exercises_json = request.POST.get('exercises_json', '[]')
            is_active = request.POST.get('is_active') == 'on'
            
            # Parse exercises
            import json
            exercises = json.loads(exercises_json)
            
            # Create template
            template = TemplateWorkout.objects.create(
                name=name,
                default_duration=default_duration,
                goal=goal,
                experience_level=experience_level,
                training_location=training_location,
                description=description,
                exercises=exercises,
                is_active=is_active
            )
            
            # Handle image upload
            if request.FILES.get('image'):
                template.image = request.FILES['image']
                template.save()
            
            return JsonResponse({
                'success': True,
                'id': template.id,
                'name': template.name,
                'message': 'Workout created successfully!'
            })
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=400)
    
    return JsonResponse({'error': 'Invalid method'}, status=400)

@staff_member_required
def admin_workout_library_edit(request, workout_id):
    """Edit workout in library"""
    from apps.workouts.models import TemplateWorkout
    import json
    from django.contrib import messages
    
    # Use get_object_or_404 with UUID string
    template = get_object_or_404(TemplateWorkout, id=workout_id)
    
    if request.method == 'POST':
        try:
            template.name = request.POST.get('name')
            template.default_duration = request.POST.get('duration', 30)
            template.goal = request.POST.get('goal', 'FITNESS')
            template.experience_level = request.POST.get('experience_level', 'BEGINNER')
            template.training_location = request.POST.get('training_location', 'HOME')
            template.description = request.POST.get('description', '')
            template.exercises = json.loads(request.POST.get('exercises_json', '[]'))
            template.is_active = request.POST.get('is_active') == 'on'
            
            # Handle image upload
            if request.FILES.get('image'):
                template.image = request.FILES['image']
            
            template.save()
            
            messages.success(request, f'Workout "{template.name}" updated successfully!')
            return redirect('admin_workout_library')
            
        except Exception as e:
            messages.error(request, f'Error updating workout: {str(e)}')
            return redirect('admin_workout_library_edit', workout_id=workout_id)
    
    context = {
        'active_page': 'workout_library',
        'workout': template,
    }
    return render(request, 'admin/workout_library_edit.html', context)

@staff_member_required
def api_workout_library_delete(request, workout_id):
    """Delete workout from library"""
    from apps.workouts.models import TemplateWorkout
    
    try:
        template = TemplateWorkout.objects.get(id=workout_id)
        template.delete()
        return JsonResponse({'success': True, 'message': 'Workout deleted successfully!'})
    except TemplateWorkout.DoesNotExist:
        return JsonResponse({'error': 'Workout not found'}, status=404)
# Meals API
@staff_member_required
def api_meals_list(request):
    """Get list of meals"""
    meals = MealItem.objects.all().values('id', 'name', 'meal_type', 'calories', 'protein', 'is_active')
    return JsonResponse({'meals': list(meals)})

@staff_member_required
def api_meal_delete(request, meal_id):
    """Delete a meal"""
    try:
        meal = MealItem.objects.get(id=meal_id)
        meal.delete()
        return JsonResponse({'success': True})
    except MealItem.DoesNotExist:
        return JsonResponse({'success': False})

# Social API
@staff_member_required
def api_social_stats(request):
    """Get social statistics"""
    return JsonResponse({
        'total_friendships': Friend.objects.filter(status='ACCEPTED').count(),
        'active_challenges': Challenge.objects.filter(is_active=True).count(),
        'pending_requests': FriendRequest.objects.filter(status='PENDING').count(),
    })

@staff_member_required
def api_challenges_list(request):
    """Get list of challenges"""
    challenges = Challenge.objects.filter(is_active=True).values('id', 'name', 'challenge_type', 'target_value')
    return JsonResponse({'challenges': list(challenges)})

# Payments API
@staff_member_required
def api_payments_stats(request):
    """Get payment statistics"""
    return JsonResponse({
        'total_revenue': 0,
        'monthly_revenue': 0,
        'active_subscriptions': User.objects.filter(subscription_tier='PREMIUM').count(),
        'success_rate': 100,
    })

@staff_member_required
def api_plans_list(request):
    """Get subscription plans"""
    plans = SubscriptionPlan.objects.filter(is_active=True).values('id', 'name', 'amount', 'interval', 'features')
    return JsonResponse({'plans': list(plans)})

@staff_member_required
def api_transactions_list(request):
    """Get recent transactions"""
    transactions = PaymentTransaction.objects.all().order_by('-created_at')[:50].values('user__username', 'amount', 'payment_type', 'status', 'created_at')
    return JsonResponse({'transactions': list(transactions)})

# Analytics API
@staff_member_required
def api_analytics_data(request):
    """Get analytics data for charts"""
    return JsonResponse({
        'user_growth': {'labels': [], 'values': []},
        'completion_rate': {'completed': 0, 'not_completed': 0},
        'retention': {'day1': 0, 'day7': 0, 'day30': 0},
        'revenue': {'labels': [], 'values': []},
        'popular_workouts': {'labels': [], 'values': []},
        'meal_preferences': {'labels': [], 'values': []},
        'top_users': [],
    })

# Image Upload
@staff_member_required
def upload_image(request):
    """Handle image uploads"""
    return JsonResponse({'location': ''})
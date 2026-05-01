# admin_panel/views.py
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
from apps.workouts.models import Workout, TemplateWorkout
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


# ==================== WORKOUT LIBRARY ====================

@admin_required
def admin_workout_library(request):
    """Workout library page - templates created by admin"""
    context = {'active_page': 'workout_library'}
    return render(request, 'admin/workout_library.html', context)

@admin_required
def admin_workout_library_create(request):
    """Create new workout template"""
    if request.method == 'POST':
        try:
            name = request.POST.get('name')
            duration = request.POST.get('duration', 30)
            goal = request.POST.get('goal', 'FITNESS')
            experience_level = request.POST.get('experience_level', 'BEGINNER')
            training_location = request.POST.get('training_location', 'HOME')
            description = request.POST.get('description', '')
            exercises_json = request.POST.get('exercises_json', '[]')
            is_active = request.POST.get('is_active') == 'on'
            
            exercises = json.loads(exercises_json)
            
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
            
            if request.FILES.get('image'):
                template.image = request.FILES['image']
                template.save()
            
            messages.success(request, f'Workout "{template.name}" created successfully!')
            return redirect('admin_workout_library')
            
        except Exception as e:
            messages.error(request, f'Error creating workout: {str(e)}')
            return redirect('admin_workout_library_create')
    
    context = {'active_page': 'workout_library'}
    return render(request, 'admin/workout_library_create.html', context)

@admin_required
def admin_workout_library_edit(request, workout_id):
    """Edit workout in library"""
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
            
            if request.FILES.get('image'):
                template.image = request.FILES['image']
            
            template.save()
            
            messages.success(request, f'Workout "{template.name}" updated successfully!')
            return redirect('admin_workout_library')
            
        except Exception as e:
            messages.error(request, f'Error updating workout: {str(e)}')
            return redirect('admin_workout_library_edit', workout_id=workout_id)
    
    context = {'active_page': 'workout_library', 'workout': template}
    return render(request, 'admin/workout_library_edit.html', context)


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


# ==================== API ENDPOINTS ====================

@admin_required
def api_dashboard_stats(request):
    """Get dashboard statistics"""
    total_users = User.objects.count()
    active_users = User.objects.filter(is_active=True).count()
    total_workouts = Workout.objects.count()
    completed_workouts = Workout.objects.filter(is_completed=True).count()
    completion_rate = round((completed_workouts / total_workouts) * 100, 1) if total_workouts > 0 else 0
    premium_users = User.objects.filter(subscription_tier='PREMIUM').count()
    total_meals = MealItem.objects.count()
    total_templates = TemplateWorkout.objects.count()
    
    return JsonResponse({
        'total_users': total_users,
        'active_users': active_users,
        'total_workouts': total_workouts,
        'completed_workouts': completed_workouts,
        'completion_rate': completion_rate,
        'premium_users': premium_users,
        'total_meals': total_meals,
        'total_templates': total_templates,
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
    premium_users = User.objects.filter(subscription_tier='PREMIUM').count()
    
    paginator = Paginator(users, per_page)
    page_obj = paginator.get_page(page)
    
    data = []
    for user in page_obj:
        workout_count = Workout.objects.filter(user=user, is_completed=True).count()
        
        data.append({
            'id': str(user.id),
            'username': user.username,
            'email': user.email,
            'subscription_tier': user.subscription_tier,
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

@admin_required
def api_workout_library_list(request):
    """Get workout library (templates)"""
    templates = TemplateWorkout.objects.all().order_by('-id')
    
    data = []
    for template in templates:
        data.append({
            'id': str(template.id),
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
        'active_subscriptions': User.objects.filter(subscription_tier='PREMIUM').count(),
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
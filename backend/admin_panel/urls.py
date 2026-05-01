# admin_panel/urls.py - Change meal_id from int to str

from django.urls import path
from . import views

urlpatterns = [
    # Authentication
    path('login/', views.admin_login, name='admin_login'),
    path('logout/', views.admin_logout, name='admin_logout'),
    
    # Dashboard
    path('', views.admin_dashboard, name='admin_dashboard'),
    
    # User Management
    path('users/', views.admin_users, name='admin_users'),
    path('users/<str:user_id>/', views.admin_user_detail, name='admin_user_detail'),
    path('users/<str:user_id>/edit/', views.admin_user_edit, name='admin_user_edit'),
    
    # User Workouts
    path('user-workouts/', views.admin_user_workouts, name='admin_user_workouts'),
    
    # Workout Library
    path('workout-library/', views.admin_workout_library, name='admin_workout_library'),
    path('workout-library/create/', views.admin_workout_library_create, name='admin_workout_library_create'),
    path('workout-library/<str:workout_id>/edit/', views.admin_workout_library_edit, name='admin_workout_library_edit'),
    
    # Meal Management - CHANGE int to str for UUID support
    path('meals/', views.admin_meals, name='admin_meals'),
    path('meals/<str:meal_id>/', views.admin_meal_detail, name='admin_meal_detail'),
    path('meals/<str:meal_id>/edit/', views.admin_meal_edit, name='admin_meal_edit'),
    path('meals/create/', views.admin_meal_create, name='admin_meal_create'),
    
    # Social Management
    path('social/', views.admin_social, name='admin_social'),
    path('challenges/', views.admin_challenges, name='admin_challenges'),
    path('challenges/create/', views.admin_challenge_create, name='admin_challenge_create'),
    
    # Payment Management
    path('payments/', views.admin_payments, name='admin_payments'),
    path('subscriptions/', views.admin_subscriptions, name='admin_subscriptions'),
    
    # Analytics & Settings
    path('analytics/', views.admin_analytics, name='admin_analytics'),
    path('settings/', views.admin_settings, name='admin_settings'),
    # Add these to urlpatterns
    path('change-password/', views.admin_change_password, name='admin_change_password'),
    path('api/reset-user-password/', views.api_reset_user_password, name='api_reset_user_password'),
    path('api/create-admin/', views.api_create_admin, name='api_create_admin'),
    path('api/clear-cache/', views.api_clear_cache, name='api_clear_cache'),
    path('api/clear-logs/', views.api_clear_logs, name='api_clear_logs'),
    path('api/backup-database/', views.api_backup_database, name='api_backup_database'),
    
    # API Endpoints
    path('api/dashboard/stats/', views.api_dashboard_stats, name='api_dashboard_stats'),
    path('api/users/list/', views.api_users_list, name='api_users_list'),
    path('api/users/<str:user_id>/delete/', views.api_user_delete, name='api_user_delete'),
    path('api/users/<str:user_id>/ban/', views.api_user_ban, name='api_user_ban'),
    path('api/user-workouts/list/', views.api_user_workouts_list, name='api_user_workouts_list'),
    path('api/user-workouts/<str:workout_id>/delete/', views.api_user_workout_delete, name='api_user_workout_delete'),
    path('api/meals/list/', views.api_meals_list, name='api_meals_list'),
    path('api/meals/<str:meal_id>/delete/', views.api_meal_delete, name='api_meal_delete'),  # Change to str
    path('api/social/stats/', views.api_social_stats, name='api_social_stats'),
    path('api/challenges/list/', views.api_challenges_list, name='api_challenges_list'),
    path('api/payments/stats/', views.api_payments_stats, name='api_payments_stats'),
    path('api/plans/list/', views.api_plans_list, name='api_plans_list'),
    path('api/transactions/list/', views.api_transactions_list, name='api_transactions_list'),
    path('api/analytics/data/', views.api_analytics_data, name='api_analytics_data'),
    
    # Workout Library APIs
    path('api/workout-library/list/', views.api_workout_library_list, name='api_workout_library_list'),
    path('api/workout-library/<str:workout_id>/delete/', views.api_workout_library_delete, name='api_workout_library_delete'),
]
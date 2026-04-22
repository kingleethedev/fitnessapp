# admin.py
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.utils.html import format_html
from import_export.admin import ExportActionMixin
from .models import User, UserProfile, UserMetric

class CustomUserAdmin(ExportActionMixin, UserAdmin):
    list_display = ('username', 'email', 'subscription_tier', 'is_premium_display', 
                   'streak_days', 'total_workouts', 'onboarding_completed', 'is_active')
    list_filter = ('subscription_tier', 'experience_level', 'goal', 'onboarding_completed', 
                  'is_active', 'date_joined')
    search_fields = ('username', 'email', 'stripe_customer_id')
    readonly_fields = ('id', 'created_at', 'updated_at', 'total_workouts', 'streak_days')
    
    fieldsets = UserAdmin.fieldsets + (
        ('Fitness Information', {
            'fields': ('height', 'weight', 'goal', 'experience_level', 
                      'training_location', 'days_per_week', 'time_available')
        }),
        ('Subscription', {
            'fields': ('subscription_tier', 'subscription_end_date', 
                      'stripe_customer_id', 'stripe_subscription_id')
        }),
        ('Stats', {
            'fields': ('streak_days', 'total_workouts', 'total_minutes', 'last_workout_date')
        }),
        ('Onboarding', {
            'fields': ('onboarding_completed', 'onboarding_completed_at')
        }),
        ('Metadata', {
            'fields': ('id', 'created_at', 'updated_at', 'last_active'),
            'classes': ('collapse',)
        }),
    )
    
    actions = ['make_premium', 'make_free', 'reset_streak']
    
    def is_premium_display(self, obj):
        if obj.is_premium():
            return format_html('<span style="color: green; font-weight: bold;">✓ Premium</span>')
        return format_html('<span style="color: gray;">Free</span>')
    is_premium_display.short_description = 'Premium Status'
    
    def make_premium(self, request, queryset):
        queryset.update(subscription_tier='PREMIUM')
        self.message_user(request, f"{queryset.count()} users upgraded to Premium")
    make_premium.short_description = "Upgrade selected users to Premium"
    
    def make_free(self, request, queryset):
        queryset.update(subscription_tier='FREE')
        self.message_user(request, f"{queryset.count()} users downgraded to Free")
    make_free.short_description = "Downgrade selected users to Free"
    
    def reset_streak(self, request, queryset):
        queryset.update(streak_days=0)
        self.message_user(request, f"Streaks reset for {queryset.count()} users")
    reset_streak.short_description = "Reset streak for selected users"

class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'push_notifications_enabled', 'profile_visibility', 'workout_reminder_time')
    list_filter = ('push_notifications_enabled', 'profile_visibility')
    search_fields = ('user__username', 'user__email')
    
    fieldsets = (
        ('User', {'fields': ('user',)}),
        ('Profile', {'fields': ('bio', 'avatar')}),
        ('Preferences', {'fields': ('push_notifications_enabled', 'email_notifications_enabled', 
                                   'workout_reminder_time')}),
        ('Privacy', {'fields': ('profile_visibility', 'show_on_leaderboard')}),
    )

class UserMetricAdmin(admin.ModelAdmin):
    list_display = ('user', 'date', 'weight', 'body_fat', 'muscle_mass')
    list_filter = ('date',)
    search_fields = ('user__username',)
    date_hierarchy = 'date'
    
    fieldsets = (
        ('User', {'fields': ('user', 'date')}),
        ('Measurements', {'fields': ('weight', 'body_fat', 'muscle_mass')}),
        ('Notes', {'fields': ('notes',)}),
    )

admin.site.register(User, CustomUserAdmin)
admin.site.register(UserProfile, UserProfileAdmin)
admin.site.register(UserMetric, UserMetricAdmin)

# Custom admin site
admin.site.site_header = "Fitness App Administration"
admin.site.site_title = "Fitness App Admin"
admin.site.index_title = "Welcome to Fitness App Admin Panel"
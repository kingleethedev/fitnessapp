# admin.py
from django.contrib import admin
from django.utils.html import format_html
from import_export.admin import ExportActionMixin
from .models import Workout, WorkoutLog, TemplateWorkout

class WorkoutLogInline(admin.TabularInline):
    model = WorkoutLog
    extra = 0
    readonly_fields = ('logged_at',)
    fields = ('exercise_name', 'target_reps', 'actual_reps', 'completed', 'difficulty_rating')

class WorkoutAdmin(ExportActionMixin, admin.ModelAdmin):
    list_display = ('user', 'date', 'duration', 'difficulty_score', 'intensity_level', 
                   'is_completed', 'calories_burned')
    list_filter = ('is_completed', 'date', 'intensity_level')
    search_fields = ('user__username', 'user__email')
    readonly_fields = ('id', 'created_at', 'updated_at')
    inlines = [WorkoutLogInline]
    date_hierarchy = 'date'
    
    fieldsets = (
        ('Workout Info', {
            'fields': ('user', 'date', 'duration', 'exercises')
        }),
        ('Metrics', {
            'fields': ('difficulty_score', 'intensity_level', 'calories_burned', 'satisfaction_rating')
        }),
        ('Status', {
            'fields': ('is_completed', 'completed_at')
        }),
        ('Metadata', {
            'fields': ('id', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    actions = ['mark_as_completed', 'mark_as_incomplete']
    
    def mark_as_completed(self, request, queryset):
        queryset.update(is_completed=True, completed_at=timezone.now())
        self.message_user(request, f"{queryset.count()} workouts marked as completed")
    mark_as_completed.short_description = "Mark selected workouts as completed"
    
    def mark_as_incomplete(self, request, queryset):
        queryset.update(is_completed=False, completed_at=None)
        self.message_user(request, f"{queryset.count()} workouts marked as incomplete")
    mark_as_incomplete.short_description = "Mark selected workouts as incomplete"

class WorkoutLogAdmin(ExportActionMixin, admin.ModelAdmin):
    list_display = ('user', 'exercise_name', 'workout_date', 'completed', 'actual_reps', 'target_reps')
    list_filter = ('completed', 'logged_at')
    search_fields = ('user__username', 'exercise_name')
    readonly_fields = ('logged_at',)
    
    def workout_date(self, obj):
        return obj.workout.date
    workout_date.short_description = 'Workout Date'
    workout_date.admin_order_field = 'workout__date'

class TemplateWorkoutAdmin(admin.ModelAdmin):
    list_display = ('name', 'goal', 'experience_level', 'training_location', 'default_duration', 'is_active')
    list_filter = ('goal', 'experience_level', 'training_location', 'is_active')
    search_fields = ('name', 'description')
    list_editable = ('is_active',)
    
    fieldsets = (
        ('Template Info', {
            'fields': ('name', 'description', 'goal', 'experience_level', 'training_location')
        }),
        ('Workout Details', {
            'fields': ('exercises', 'default_duration')
        }),
        ('Status', {
            'fields': ('is_active', 'created_by')
        }),
    )

admin.site.register(Workout, WorkoutAdmin)
admin.site.register(WorkoutLog, WorkoutLogAdmin)
admin.site.register(TemplateWorkout, TemplateWorkoutAdmin)
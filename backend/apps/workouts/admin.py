# admin.py
from django.contrib import admin
from django.utils.html import format_html
from import_export.admin import ExportActionMixin
from .models import Workout, WorkoutLog, TemplateWorkout, Exercise, TemplateWorkoutExercise
from django.utils import timezone


class WorkoutLogInline(admin.TabularInline):
    model = WorkoutLog
    extra = 0
    readonly_fields = ('logged_at',)
    fields = ('exercise_name', 'target_reps', 'actual_reps', 'completed', 'difficulty_rating')


class WorkoutAdmin(ExportActionMixin, admin.ModelAdmin):
    list_display = ('user', 'date', 'duration', 'difficulty_score', 'intensity_level', 
                   'is_completed', 'calories_burned', 'has_videos')
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
    
    def has_videos(self, obj):
        """Check if workout exercises have videos"""
        try:
            exercises_with_video = obj.get_exercises_with_videos()
            total_with_video = sum(1 for ex in exercises_with_video if ex.get('has_video', False))
            total_exercises = len(exercises_with_video)
            if total_exercises == 0:
                return format_html('<span style="color: gray;">No exercises</span>')
            percentage = (total_with_video / total_exercises) * 100
            if percentage == 100:
                return format_html('<span style="color: green;">✓ {}% ({}/{})</span>', 
                                 int(percentage), total_with_video, total_exercises)
            elif percentage > 0:
                return format_html('<span style="color: orange;">⚠ {}% ({}/{})</span>', 
                                 int(percentage), total_with_video, total_exercises)
            else:
                return format_html('<span style="color: red;">✗ No videos</span>')
        except:
            return format_html('<span style="color: gray;">Unknown</span>')
    
    has_videos.short_description = 'Videos'
    
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


class ExerciseAdmin(admin.ModelAdmin):
    list_display = ('name', 'primary_goal', 'training_location', 'experience_level', 
                   'has_video_display', 'equipment_needed', 'is_active')
    list_filter = ('primary_goal', 'training_location', 'experience_level', 'is_active')
    search_fields = ('name', 'description', 'equipment_needed')
    list_editable = ('is_active',)
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('name', 'description', 'primary_goal', 'experience_level', 'training_location')
        }),
        ('Video & Media', {
            'fields': ('video_url', 'video_file', 'thumbnail'),
            'description': '⚠️ IMPORTANT: Provide either a video URL (YouTube, Vimeo) or upload a video file. Users will see videos during workouts.'
        }),
        ('Metadata', {
            'fields': ('equipment_needed', 'calories_per_minute', 'is_active')
        }),
    )
    
    def has_video_display(self, obj):
        """Display video status with icon"""
        if obj.has_video():
            if obj.video_file:
                return format_html('<span style="color: green;">✓ Video File</span>')
            elif obj.video_url:
                return format_html('<span style="color: green;">✓ Video URL</span>')
        return format_html('<span style="color: red;">✗ No Video</span>')
    
    has_video_display.short_description = 'Video Status'
    
    def save_model(self, request, obj, form, change):
        """Override to log when exercises are created/updated"""
        if not change:
            obj.created_by = request.user
        super().save_model(request, obj, form, change)
    
    actions = ['mark_active', 'mark_inactive', 'export_with_videos']
    
    def mark_active(self, request, queryset):
        queryset.update(is_active=True)
        self.message_user(request, f"{queryset.count()} exercises marked as active")
    mark_active.short_description = "Mark selected exercises as active"
    
    def mark_inactive(self, request, queryset):
        queryset.update(is_active=False)
        self.message_user(request, f"{queryset.count()} exercises marked as inactive")
    mark_inactive.short_description = "Mark selected exercises as inactive"
    
    def export_with_videos(self, request, queryset):
        """Export exercises with video URLs"""
        import csv
        from django.http import HttpResponse
        
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="exercises_with_videos.csv"'
        
        writer = csv.writer(response)
        writer.writerow(['Name', 'Goal', 'Location', 'Level', 'Has Video', 'Video URL', 'Equipment'])
        
        for exercise in queryset:
            writer.writerow([
                exercise.name,
                exercise.primary_goal,
                exercise.training_location,
                exercise.experience_level,
                'Yes' if exercise.has_video() else 'No',
                exercise.get_video_url() or 'N/A',
                exercise.equipment_needed
            ])
        
        self.message_user(request, f"Exported {queryset.count()} exercises")
        return response
    
    export_with_videos.short_description = "Export selected exercises with video info"


class TemplateWorkoutExerciseInline(admin.TabularInline):
    """Inline for adding exercises to template workouts"""
    model = TemplateWorkoutExercise
    extra = 2
    fields = ('exercise', 'sets', 'reps', 'duration_seconds', 'rest_seconds', 'order')
    autocomplete_fields = ['exercise']
    
    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == "exercise":
            # Only show exercises that have videos
            kwargs["queryset"] = Exercise.objects.filter(is_active=True)
        return super().formfield_for_foreignkey(db_field, request, **kwargs)


class TemplateWorkoutAdmin(admin.ModelAdmin):
    list_display = ('name_with_status', 'goal', 'experience_level', 'training_location', 
                   'default_duration', 'is_active', 'exercises_count', 'videos_count')
    list_filter = ('goal', 'experience_level', 'training_location', 'is_active')
    search_fields = ('name', 'description')
    list_editable = ('is_active',)
    inlines = [TemplateWorkoutExerciseInline]
    
    fieldsets = (
        ('Template Info', {
            'fields': ('name', 'description', 'goal', 'experience_level', 'training_location', 'default_duration', 'image')
        }),
        ('JSON Exercises (Legacy)', {
            'fields': ('exercises',),
            'classes': ('collapse',),
            'description': '⚠️ Use the inline form above to add exercises. This JSON field is for backward compatibility.'
        }),
        ('Status', {
            'fields': ('is_active', 'created_by')
        }),
    )
    
    def name_with_status(self, obj):
        """Display name with video status indicator"""
        if obj.is_active:
            return format_html('<strong>{}</strong>', obj.name)
        return format_html('<span style="color: gray;">{} (inactive)</span>', obj.name)
    name_with_status.short_description = 'Template Name'
    
    def exercises_count(self, obj):
        """Count total exercises in template"""
        if hasattr(obj, 'template_exercises'):
            count = obj.template_exercises.count()
            return format_html('<span style="font-weight: bold;">{}</span> exercises', count)
        return format_html('<span style="color: orange;">Using JSON</span>')
    exercises_count.short_description = 'Exercises'
    
    def videos_count(self, obj):
        """Count how many exercises have videos"""
        if hasattr(obj, 'template_exercises'):
            total = obj.template_exercises.count()
            if total == 0:
                return format_html('<span style="color: gray;">No exercises</span>')
            
            with_video = obj.template_exercises.filter(
                exercise__video_url__isnull=False
            ).count() + obj.template_exercises.filter(
                exercise__video_file__isnull=False
            ).count()
            
            if with_video == total:
                return format_html('<span style="color: green;">✓ {}/{} with video</span>', with_video, total)
            elif with_video > 0:
                return format_html('<span style="color: orange;">⚠ {}/{} with video</span>', with_video, total)
            else:
                return format_html('<span style="color: red;">✗ No videos</span>')
        return format_html('<span style="color: gray;">Legacy format</span>')
    videos_count.short_description = 'Video Coverage'
    
    def get_inlines(self, request, obj=None):
        """Only show the inline if we're editing an existing object"""
        if obj is not None:
            return [TemplateWorkoutExerciseInline]
        return []
    
    def save_model(self, request, obj, form, change):
        """Save the created_by field"""
        if not change:
            obj.created_by = request.user
        super().save_model(request, obj, form, change)
    
    actions = ['duplicate_template', 'check_videos_status']
    
    def duplicate_template(self, request, queryset):
        """Duplicate selected templates"""
        for template in queryset:
            new_template = TemplateWorkout.objects.create(
                name=f"{template.name} (Copy)",
                description=template.description,
                goal=template.goal,
                experience_level=template.experience_level,
                training_location=template.training_location,
                exercises=template.exercises,
                default_duration=template.default_duration,
                is_active=False,
                created_by=request.user
            )
            # Copy exercises if using the new structure
            if hasattr(template, 'template_exercises'):
                for te in template.template_exercises.all():
                    TemplateWorkoutExercise.objects.create(
                        template=new_template,
                        exercise=te.exercise,
                        sets=te.sets,
                        reps=te.reps,
                        duration_seconds=te.duration_seconds,
                        rest_seconds=te.rest_seconds,
                        order=te.order
                    )
        self.message_user(request, f"Duplicated {queryset.count()} templates")
    duplicate_template.short_description = "Duplicate selected templates"
    
    def check_videos_status(self, request, queryset):
        """Check video status of selected templates"""
        results = []
        for template in queryset:
            if hasattr(template, 'template_exercises'):
                total = template.template_exercises.count()
                with_video = template.template_exercises.filter(
                    exercise__video_url__isnull=False
                ).count() + template.template_exercises.filter(
                    exercise__video_file__isnull=False
                ).count()
                results.append(f"{template.name}: {with_video}/{total} exercises have videos")
            else:
                results.append(f"{template.name}: Using legacy JSON format")
        
        from django.contrib import messages
        for result in results:
            messages.info(request, result)
    check_videos_status.short_description = "Check video coverage"


# Register the new models
admin.site.register(Exercise, ExerciseAdmin)
admin.site.register(TemplateWorkout, TemplateWorkoutAdmin)

# Unregister old TemplateWorkout if already registered
if admin.site.is_registered(TemplateWorkout):
    admin.site.unregister(TemplateWorkout)
admin.site.register(TemplateWorkout, TemplateWorkoutAdmin)
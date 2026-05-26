from django.contrib import admin
from import_export.admin import ExportActionMixin
from .models import MealCategory, MealItem, MealPlan, DailyMealLog, FavoriteMeal

class MealItemInline(admin.TabularInline):
    model = MealItem
    extra = 1
    fields = ['name', 'meal_type', 'calories', 'is_active']

class MealCategoryAdmin(admin.ModelAdmin):
    list_display = ['name', 'display_order']
    list_editable = ['display_order']
    inlines = [MealItemInline]

class MealItemAdmin(ExportActionMixin, admin.ModelAdmin):
    list_display = ['name', 'meal_type', 'category', 'calories', 'protein', 'is_vegetarian', 'is_active']
    list_filter = ['meal_type', 'is_vegetarian', 'is_vegan', 'is_gluten_free', 'is_high_protein', 'is_active']
    search_fields = ['name', 'ingredients']
    list_editable = ['is_active']
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('name', 'category', 'meal_type')
        }),
        ('Nutritional Information', {
            'fields': ('calories', 'protein', 'carbs', 'fats', 'fiber')
        }),
        ('Preparation', {
            'fields': ('preparation_time', 'ingredients', 'instructions')
        }),
        ('Dietary Tags', {
            'fields': ('is_vegetarian', 'is_vegan', 'is_gluten_free', 'is_dairy_free', 'is_high_protein', 'is_low_carb')
        }),
        ('Media', {
            'fields': ('image',)
        }),
        ('Status', {
            'fields': ('is_active',)
        }),
    )

class MealPlanAdmin(ExportActionMixin, admin.ModelAdmin):
    list_display = ['user', 'week_start_date', 'week_end_date', 'goal', 'target_calories', 'is_active']
    list_filter = ['goal', 'is_active', 'week_start_date']
    search_fields = ['user__username', 'user__email']
    date_hierarchy = 'week_start_date'
    readonly_fields = ['id', 'created_at', 'updated_at']
    
    fieldsets = (
        ('User Information', {
            'fields': ('user',)
        }),
        ('Plan Dates', {
            'fields': ('week_start_date', 'week_end_date')
        }),
        ('Goals', {
            'fields': ('goal', 'target_calories', 'target_protein', 'target_carbs', 'target_fats')
        }),
        ('Meal Data', {
            'fields': ('meals',),
            'classes': ('wide',)
        }),
        ('Status', {
            'fields': ('is_active',)
        }),
    )

class DailyMealLogAdmin(ExportActionMixin, admin.ModelAdmin):
    list_display = ['user', 'date', 'meal_type', 'meal_item', 'is_completed', 'rating']
    list_filter = ['meal_type', 'is_completed', 'rating', 'date']
    search_fields = ['user__username', 'meal_item__name', 'custom_meal_name']
    date_hierarchy = 'date'
    readonly_fields = ['id', 'created_at']
    
    fieldsets = (
        ('User Information', {
            'fields': ('user', 'meal_plan')
        }),
        ('Meal Details', {
            'fields': ('date', 'meal_type', 'meal_item', 'custom_meal_name', 'custom_calories')
        }),
        ('Completion', {
            'fields': ('is_completed', 'completed_at')
        }),
        ('Feedback', {
            'fields': ('rating', 'notes')
        }),
    )

class FavoriteMealAdmin(admin.ModelAdmin):
    list_display = ['user', 'meal_item', 'added_at']
    list_filter = ['added_at']
    search_fields = ['user__username', 'meal_item__name']
    readonly_fields = ['id', 'added_at']

admin.site.register(MealCategory, MealCategoryAdmin)
admin.site.register(MealItem, MealItemAdmin)
admin.site.register(MealPlan, MealPlanAdmin)
admin.site.register(DailyMealLog, DailyMealLogAdmin)
admin.site.register(FavoriteMeal, FavoriteMealAdmin)
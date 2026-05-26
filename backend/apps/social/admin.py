# admin.py
from django.contrib import admin
from import_export.admin import ExportActionMixin
from .models import Friend, FriendRequest, Challenge, ChallengeParticipant, ActivityFeed

class FriendAdmin(ExportActionMixin, admin.ModelAdmin):
    list_display = ['user', 'friend', 'status', 'created_at']
    list_filter = ['status', 'created_at']
    search_fields = ['user__username', 'friend__username']
    date_hierarchy = 'created_at'

class FriendRequestAdmin(ExportActionMixin, admin.ModelAdmin):
    list_display = ['from_user', 'to_user', 'status', 'created_at']
    list_filter = ['status', 'created_at']
    search_fields = ['from_user__username', 'to_user__username']
    date_hierarchy = 'created_at'

class ChallengeParticipantInline(admin.TabularInline):
    model = ChallengeParticipant
    extra = 1
    fields = ['user', 'current_value', 'completed']

class ChallengeAdmin(admin.ModelAdmin):
    list_display = ['name', 'challenge_type', 'target_value', 'start_date', 'end_date', 'participants_count', 'is_active']
    list_filter = ['challenge_type', 'is_active', 'start_date']
    search_fields = ['name', 'description']
    list_editable = ['is_active']
    inlines = [ChallengeParticipantInline]
    
    def participants_count(self, obj):
        return obj.participants.count()
    participants_count.short_description = 'Participants'

class ChallengeParticipantAdmin(admin.ModelAdmin):
    list_display = ['user', 'challenge', 'current_value', 'completed', 'joined_at']
    list_filter = ['completed', 'joined_at']
    search_fields = ['user__username', 'challenge__name']

class ActivityFeedAdmin(admin.ModelAdmin):
    list_display = ['user', 'activity_type', 'content', 'created_at']
    list_filter = ['activity_type', 'created_at']
    search_fields = ['user__username', 'content']
    date_hierarchy = 'created_at'
    readonly_fields = ['id', 'created_at']

admin.site.register(Friend, FriendAdmin)
admin.site.register(FriendRequest, FriendRequestAdmin)
admin.site.register(Challenge, ChallengeAdmin)
admin.site.register(ChallengeParticipant, ChallengeParticipantAdmin)
admin.site.register(ActivityFeed, ActivityFeedAdmin)
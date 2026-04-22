# admin.py
from django.contrib import admin
from import_export.admin import ExportActionMixin
from .models import SubscriptionPlan, PaymentTransaction, Invoice

class SubscriptionPlanAdmin(admin.ModelAdmin):
    list_display = ('name', 'tier', 'amount', 'interval', 'is_active')
    list_filter = ('tier', 'interval', 'is_active')
    search_fields = ('name', 'stripe_price_id')
    list_editable = ('is_active',)
    
    fieldsets = (
        ('Plan Details', {
            'fields': ('name', 'tier', 'amount', 'interval', 'stripe_price_id')
        }),
        ('Features', {
            'fields': ('unlimited_workouts', 'advanced_analytics', 'custom_workouts', 'priority_support')
        }),
        ('Status', {
            'fields': ('is_active',)
        }),
    )

class PaymentTransactionAdmin(ExportActionMixin, admin.ModelAdmin):
    list_display = ('user', 'amount', 'status', 'payment_type', 'created_at')
    list_filter = ('status', 'payment_type', 'created_at')
    search_fields = ('user__username', 'user__email', 'stripe_payment_intent_id')
    readonly_fields = ('id', 'created_at', 'updated_at')
    
    fieldsets = (
        ('User Info', {'fields': ('user',)}),
        ('Payment Details', {'fields': ('stripe_payment_intent_id', 'stripe_subscription_id', 
                                       'amount', 'currency', 'payment_type')}),
        ('Status', {'fields': ('status',)}),
        ('Metadata', {'fields': ('metadata', 'created_at', 'updated_at')}),
    )

class InvoiceAdmin(admin.ModelAdmin):
    list_display = ('invoice_number', 'user', 'amount_due', 'amount_paid', 'invoice_date')
    list_filter = ('invoice_date', 'due_date')
    search_fields = ('invoice_number', 'user__username', 'stripe_invoice_id')
    readonly_fields = ('id', 'created_at')

admin.site.register(SubscriptionPlan, SubscriptionPlanAdmin)
admin.site.register(PaymentTransaction, PaymentTransactionAdmin)
admin.site.register(Invoice, InvoiceAdmin)
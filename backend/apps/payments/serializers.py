# backend/apps/payments/serializers.py
from rest_framework import serializers
from .models import SubscriptionPlan, PaymentTransaction


class SubscriptionPlanSerializer(serializers.ModelSerializer):
    price_display = serializers.SerializerMethodField()
    features = serializers.SerializerMethodField()
    
    class Meta:
        model = SubscriptionPlan
        fields = ['id', 'name', 'amount', 'interval', 'stripe_price_id', 
                  'is_active', 'price_display', 'features']
    
    def get_price_display(self, obj):
        return f"${obj.amount}/{obj.interval}"
    
    def get_features(self, obj):
        # Basic features for all users (since it's a simple SaaS)
        features = [
            "Unlimited Workouts",
            "Progress Tracking",
            "Meal Plans",
            "Community Support",
            "Achievement Badges"
        ]
        return features


class PaymentTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = PaymentTransaction
        fields = ['id', 'amount', 'currency', 'status', 'payment_type', 'created_at', 'metadata']
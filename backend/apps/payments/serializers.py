# serializers.py
from rest_framework import serializers


# =========================
# SUBSCRIPTION PLAN
# =========================
class SubscriptionPlanSerializer(serializers.Serializer):
    id = serializers.IntegerField(required=False)
    name = serializers.CharField()
    price = serializers.FloatField()
    duration_days = serializers.IntegerField()
    description = serializers.CharField(required=False, allow_blank=True)


# =========================
# PAYMENT INTENT
# =========================
class PaymentIntentSerializer(serializers.Serializer):
    amount = serializers.FloatField()
    currency = serializers.CharField(default="usd")
    plan_id = serializers.IntegerField(required=False)
    user_id = serializers.IntegerField(required=False)
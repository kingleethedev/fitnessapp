# urls.py
# backend/apps/payments/urls.py
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import PaymentViewSet, PayPalWebhookView

router = DefaultRouter()
router.register(r'', PaymentViewSet, basename='payment')

urlpatterns = [
    path('', include(router.urls)),
    path('paypal-webhook/', PayPalWebhookView.as_view({'post': 'create'}), name='paypal-webhook'),
]
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from drf_yasg.views import get_schema_view
from django.views.generic import TemplateView
from drf_yasg import openapi

from django.views.generic import RedirectView

# Import viewsets
from apps.accounts.views import AuthViewSet, UserViewSet, UserMetricViewSet, PasswordResetViewSet, test_api
from apps.workouts.views import WorkoutViewSet, TemplateWorkoutViewSet
from apps.meals.views import MealViewSet
from apps.payments.views import PaymentViewSet, StripeWebhookView
from apps.social.views import SocialViewSet
from apps.analytics.views import AnalyticsViewSet

router = DefaultRouter()
router.register(r'auth', AuthViewSet, basename='auth')
router.register(r'users', UserViewSet, basename='users')
router.register(r'metrics', UserMetricViewSet, basename='metrics')
router.register(r'workouts', WorkoutViewSet, basename='workouts')
router.register(r'templates', TemplateWorkoutViewSet, basename='templates')
router.register(r'meals', MealViewSet, basename='meals')
router.register(r'payments', PaymentViewSet, basename='payments')
router.register(r'social', SocialViewSet, basename='social')
router.register(r'analytics', AnalyticsViewSet, basename='analytics')
router.register(r'password-reset', PasswordResetViewSet, basename='password-reset')

# Swagger documentation
schema_view = get_schema_view(
    openapi.Info(
        title="Fitness App API",
        default_version='v1',
        description="API documentation for Fitness App",
    ),
    public=True,
)

urlpatterns = [
    # Root URL - Welcome page
    path('', TemplateView.as_view(template_name='welcome.html'), name='welcome'),
    
    # Custom Admin Panel
    path('dashboard/', include('admin_panel.urls')),
    
    # API URLs
    path('api/test/', test_api, name='test_api'),
    path('api/', include(router.urls)),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('api/webhooks/stripe/', StripeWebhookView.as_view({'post': 'create'}), name='stripe-webhook'),
    
    # Swagger
    path('swagger/', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
    path('redoc/', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
    path('admin/login/', RedirectView.as_view(url='/dashboard/login/', permanent=False)),
    path('admin/logout/', RedirectView.as_view(url='/dashboard/logout/', permanent=False)),
    path('admin/', RedirectView.as_view(url='/dashboard/', permanent=False)),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
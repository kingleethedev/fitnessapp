from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import MealViewSet

router = DefaultRouter()
router.register(r'meals', MealViewSet, basename='meals')

urlpatterns = [
    path('', include(router.urls)),
]
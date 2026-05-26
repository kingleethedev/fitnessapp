import os
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fitness_backend.settings')
django.setup()

from django.contrib.auth import get_user_model
from apps.meals.meal_planner import MealPlanner
from apps.meals.models import MealPlan

User = get_user_model()


def run_test():
    print("🧪 Starting MealPlanner test...\n")

    # 1. Get or create test user
    user, created = User.objects.get_or_create(
        email="testuser@example.com",
        defaults={
            "username": "testuser",
            "weight": 70,
            "height": 175,
            "age": 25,
        }
    )

    print(f"👤 User ready: {user.email}")

    # 2. Generate meal plan
    try:
        print("\n🍽 Generating meal plan...")
        meal_plan = MealPlanner.generate_meal_plan(
            user=user,
            goal="WEIGHT_LOSS"
        )

        print("✅ Meal plan created successfully!")
        print(f"📅 Week start: {meal_plan.week_start_date}")
        print(f"🔥 Calories target: {meal_plan.target_calories}")

    except Exception as e:
        print("❌ ERROR while generating meal plan:")
        print(str(e))
        return

    # 3. Check stored meals
    print("\n📦 Stored meal structure:\n")
    for day, meals in meal_plan.meals.items():
        print(f"📅 {day}")
        for meal_type, meal in meals.items():
            print(f"   🍽 {meal_type}: {meal['name']} ({meal['calories']} kcal)")

    # 4. Test today's meals
    print("\n📍 Today's meals:")
    todays = MealPlanner.get_todays_meals(meal_plan)

    if todays:
        for meal_type, meal in todays.items():
            print(f"   🍽 {meal_type}: {meal['name']}")
    else:
        print("⚠️ No meals found for today")

    print("\n🎉 TEST COMPLETE SUCCESSFULLY")


if __name__ == "__main__":
    run_test()
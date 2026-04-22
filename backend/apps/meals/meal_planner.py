from datetime import datetime, timedelta
from django.utils import timezone
from .models import MealItem, MealPlan, MealCategory
import uuid
import random

class MealPlanner:
    
    # Weekly meal plan data structure (based on provided meal plan)
    WEEKLY_MEAL_PLAN = {
        'SUNDAY': {
            'BREAKFAST': {'name': 'Oatmeal with chia seeds and blueberries', 'calories': 350, 'protein': 12, 'carbs': 55, 'fats': 8},
            'SNACK': {'name': 'Apple with 10 almonds', 'calories': 150, 'protein': 3, 'carbs': 22, 'fats': 7},
            'LUNCH': {'name': 'Grilled chicken salad with olive oil and lemon', 'calories': 450, 'protein': 35, 'carbs': 15, 'fats': 28},
            'SNACK_2': {'name': 'Greek yogurt', 'calories': 120, 'protein': 15, 'carbs': 8, 'fats': 4},
            'DINNER': {'name': 'Salmon with steamed broccoli and quinoa', 'calories': 550, 'protein': 42, 'carbs': 45, 'fats': 22}
        },
        'MONDAY': {
            'BREAKFAST': {'name': 'Green smoothie (spinach, banana, protein powder, almond milk)', 'calories': 320, 'protein': 25, 'carbs': 35, 'fats': 10},
            'SNACK': {'name': 'Rice cakes with peanut butter', 'calories': 180, 'protein': 6, 'carbs': 20, 'fats': 9},
            'LUNCH': {'name': 'Turkey lettuce wraps', 'calories': 380, 'protein': 30, 'carbs': 12, 'fats': 22},
            'SNACK_2': {'name': '2 boiled eggs', 'calories': 140, 'protein': 12, 'carbs': 1, 'fats': 10},
            'DINNER': {'name': 'Chicken stir-fry with vegetables', 'calories': 480, 'protein': 38, 'carbs': 30, 'fats': 20}
        },
        'TUESDAY': {
            'BREAKFAST': {'name': 'Scrambled eggs with avocado', 'calories': 400, 'protein': 22, 'carbs': 12, 'fats': 28},
            'SNACK': {'name': 'Protein shake', 'calories': 150, 'protein': 25, 'carbs': 5, 'fats': 3},
            'LUNCH': {'name': 'Tuna salad with olive oil, cucumber and lemon', 'calories': 350, 'protein': 32, 'carbs': 8, 'fats': 20},
            'SNACK_2': {'name': 'Carrots with hummus', 'calories': 120, 'protein': 4, 'carbs': 15, 'fats': 6},
            'DINNER': {'name': 'Lean beef with zucchini and sweet potato', 'calories': 520, 'protein': 45, 'carbs': 40, 'fats': 18}
        },
        'WEDNESDAY': {
            'BREAKFAST': {'name': 'Overnight oats with strawberries', 'calories': 360, 'protein': 15, 'carbs': 50, 'fats': 10},
            'SNACK': {'name': 'Handful of mixed nuts', 'calories': 200, 'protein': 6, 'carbs': 8, 'fats': 18},
            'LUNCH': {'name': 'Grilled chicken bowl with rice and veggies', 'calories': 470, 'protein': 38, 'carbs': 45, 'fats': 15},
            'SNACK_2': {'name': 'Cottage cheese', 'calories': 110, 'protein': 13, 'carbs': 5, 'fats': 5},
            'DINNER': {'name': 'Baked salmon with asparagus', 'calories': 480, 'protein': 40, 'carbs': 15, 'fats': 28}
        },
        'THURSDAY': {
            'BREAKFAST': {'name': 'Smoothie bowl with berries, protein and seeds', 'calories': 380, 'protein': 28, 'carbs': 42, 'fats': 12},
            'SNACK': {'name': 'Banana with peanut butter', 'calories': 200, 'protein': 7, 'carbs': 30, 'fats': 9},
            'LUNCH': {'name': 'Shrimp salad', 'calories': 340, 'protein': 28, 'carbs': 12, 'fats': 18},
            'SNACK_2': {'name': 'Boiled eggs', 'calories': 140, 'protein': 12, 'carbs': 1, 'fats': 10},
            'DINNER': {'name': 'Chicken with roasted vegetables', 'calories': 450, 'protein': 35, 'carbs': 25, 'fats': 20}
        },
        'FRIDAY': {
            'BREAKFAST': {'name': 'Avocado toast with egg', 'calories': 420, 'protein': 18, 'carbs': 35, 'fats': 24},
            'SNACK': {'name': 'Apple with almonds', 'calories': 160, 'protein': 3, 'carbs': 22, 'fats': 7},
            'LUNCH': {'name': 'Turkey and rice bowl', 'calories': 440, 'protein': 35, 'carbs': 50, 'fats': 12},
            'SNACK_2': {'name': 'Protein yogurt', 'calories': 130, 'protein': 20, 'carbs': 10, 'fats': 2},
            'DINNER': {'name': 'Grilled fish with greens', 'calories': 410, 'protein': 38, 'carbs': 12, 'fats': 22}
        },
        'SATURDAY': {
            'BREAKFAST': {'name': 'Oatmeal with cinnamon and banana', 'calories': 370, 'protein': 10, 'carbs': 65, 'fats': 6},
            'SNACK': {'name': 'Protein shake', 'calories': 150, 'protein': 25, 'carbs': 5, 'fats': 3},
            'LUNCH': {'name': 'Chicken salad wrap (lettuce wrap)', 'calories': 360, 'protein': 32, 'carbs': 10, 'fats': 20},
            'SNACK_2': {'name': 'Vegetables with hummus', 'calories': 100, 'protein': 3, 'carbs': 12, 'fats': 5},
            'DINNER': {'name': 'Lean beef with broccoli', 'calories': 490, 'protein': 42, 'carbs': 20, 'fats': 25}
        }
    }
    
    @classmethod
    def _get_or_create_meal_item(cls, meal_data):
        """Get or create a meal item in the database"""
        meal_name = meal_data['name']
        
        # Try to find existing meal item
        meal_item = MealItem.objects.filter(name=meal_name).first()
        
        if not meal_item:
            # Create new meal item with UUID
            meal_item = MealItem.objects.create(
                id=uuid.uuid4(),
                name=meal_name,
                meal_type=cls._get_meal_type_from_name(meal_name),
                calories=meal_data['calories'],
                protein=meal_data.get('protein', 0),
                carbs=meal_data.get('carbs', 0),
                fats=meal_data.get('fats', 0),
                is_active=True
            )
            print(f"Created new meal item: {meal_name} with ID: {meal_item.id}")
        
        return meal_item
    
    @classmethod
    def _get_meal_type_from_name(cls, name):
        """Determine meal type from name"""
        name_lower = name.lower()
        if 'breakfast' in name_lower or 'oatmeal' in name_lower or 'smoothie' in name_lower or 'avocado toast' in name_lower:
            return 'BREAKFAST'
        elif 'salad' in name_lower or 'wrap' in name_lower or 'bowl' in name_lower:
            return 'LUNCH'
        elif 'salmon' in name_lower or 'beef' in name_lower or 'chicken' in name_lower or 'fish' in name_lower:
            return 'DINNER'
        elif 'snack' in name_lower or 'nuts' in name_lower or 'yogurt' in name_lower or 'eggs' in name_lower:
            return 'SNACK'
        else:
            return 'LUNCH'
    
    @classmethod
    def generate_meal_plan(cls, user, goal='HEALTHY_EATING', start_date=None):
        """Generate a weekly meal plan for the user"""
        if start_date is None:
            start_date = timezone.now().date()
            # Adjust to start of week (Sunday)
            start_date = start_date - timedelta(days=start_date.weekday() + 1)
        
        week_end_date = start_date + timedelta(days=6)
        
        # Check if meal plan already exists for this week
        existing_plan = MealPlan.objects.filter(
            user=user,
            week_start_date=start_date
        ).first()
        
        if existing_plan:
            return existing_plan
        
        # Calculate target calories with safe defaults
        target_calories = cls._calculate_target_calories(user, goal)
        target_protein = cls._calculate_target_protein(user, goal)
        target_carbs = cls._calculate_target_carbs(user, goal)
        target_fats = cls._calculate_target_fats(user, goal)
        
        # Build meal plan structure
        meals = cls._build_meal_plan_structure(goal)
        
        # Create meal plan
        meal_plan = MealPlan.objects.create(
            user=user,
            week_start_date=start_date,
            week_end_date=week_end_date,
            goal=goal,
            target_calories=target_calories,
            target_protein=target_protein,
            target_carbs=target_carbs,
            target_fats=target_fats,
            meals=meals
        )
        
        return meal_plan
    
    @classmethod
    def _calculate_target_calories(cls, user, goal):
        """Calculate daily calorie target based on user stats"""
        # Default values if user data is missing
        default_calories = 2000
        
        if user.weight and user.height:
            try:
                # Mifflin-St Jeor Equation for BMR
                # Default to male if gender not set
                if hasattr(user, 'gender') and user.gender == 'FEMALE':
                    bmr = 10 * user.weight + 6.25 * user.height - 5 * (user.age or 30) - 161
                else:
                    bmr = 10 * user.weight + 6.25 * user.height - 5 * (user.age or 30) + 5
                
                base_calories = bmr * 1.375  # Lightly active multiplier
            except (TypeError, ValueError):
                base_calories = default_calories
        else:
            base_calories = default_calories
        
        # Adjust based on goal
        if goal == 'WEIGHT_LOSS':
            return int(max(1200, base_calories - 500))  # Don't go below 1200
        elif goal == 'MUSCLE_GAIN':
            return int(base_calories + 300)
        else:
            return int(base_calories)
    
    @classmethod
    def _calculate_target_protein(cls, user, goal):
        """Calculate protein target in grams"""
        weight = user.weight if user.weight else 70  # Default 70kg
        
        if goal == 'MUSCLE_GAIN':
            return int(weight * 2.2)
        elif goal == 'WEIGHT_LOSS':
            return int(weight * 1.8)
        return 130
    
    @classmethod
    def _calculate_target_carbs(cls, user, goal):
        """Calculate carb target in grams"""
        if goal == 'WEIGHT_LOSS':
            return 150
        elif goal == 'MUSCLE_GAIN':
            return 300
        return 200
    
    @classmethod
    def _calculate_target_fats(cls, user, goal):
        """Calculate fat target in grams"""
        if goal == 'WEIGHT_LOSS':
            return 45
        elif goal == 'MUSCLE_GAIN':
            return 70
        return 55
    
    @classmethod
    def _build_meal_plan_structure(cls, goal):
        """Build the structured meal plan for the week with meal IDs"""
        days = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY']
        meal_plan = {}
        
        for day in days:
            day_meals = cls.WEEKLY_MEAL_PLAN.get(day, {})
            
            # Adjust portions based on goal
            adjusted_meals = {}
            for meal_type, meal_data in day_meals.items():
                adjusted_calories = meal_data['calories']
                
                if goal == 'WEIGHT_LOSS':
                    adjusted_calories = int(meal_data['calories'] * 0.9)
                elif goal == 'MUSCLE_GAIN':
                    adjusted_calories = int(meal_data['calories'] * 1.1)
                
                # Get or create meal item to ensure it has a UUID
                meal_item = cls._get_or_create_meal_item(meal_data)
                
                adjusted_meals[meal_type] = {
                    'id': str(meal_item.id),
                    'name': meal_data['name'],
                    'calories': adjusted_calories,
                    'protein': meal_data.get('protein', 0),
                    'carbs': meal_data.get('carbs', 0),
                    'fats': meal_data.get('fats', 0),
                    'completed': False
                }
            
            meal_plan[day] = adjusted_meals
        
        return meal_plan
    
    @classmethod
    def get_todays_meals(cls, meal_plan):
        """Get today's meals from the meal plan"""
        today = datetime.now().strftime('%A').upper()
        if hasattr(meal_plan, 'meals'):
            return meal_plan.meals.get(today, {})
        return meal_plan.get('meals', {}).get(today, {})
    
    @classmethod
    def customize_meal_plan(cls, meal_plan, preferences):
        """Customize meal plan based on user preferences"""
        days = ['SUNDAY', 'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY']
        
        # Get the meals dictionary
        if hasattr(meal_plan, 'meals'):
            meals_dict = meal_plan.meals
        else:
            meals_dict = meal_plan
        
        if 'vegetarian' in str(preferences.get('diet', '')).lower():
            # Replace meat meals with vegetarian alternatives
            for day in days:
                if day in meals_dict and 'LUNCH' in meals_dict[day]:
                    lunch = meals_dict[day]['LUNCH']['name'].lower()
                    if 'chicken' in lunch or 'turkey' in lunch or 'tuna' in lunch or 'shrimp' in lunch:
                        meals_dict[day]['LUNCH']['name'] = 'Vegetarian protein bowl'
                        meals_dict[day]['LUNCH']['calories'] = 380
                
                if day in meals_dict and 'DINNER' in meals_dict[day]:
                    dinner = meals_dict[day]['DINNER']['name'].lower()
                    if 'salmon' in dinner or 'beef' in dinner or 'chicken' in dinner or 'fish' in dinner:
                        meals_dict[day]['DINNER']['name'] = 'Tofu and vegetable stir-fry'
                        meals_dict[day]['DINNER']['calories'] = 420
        
        if hasattr(meal_plan, 'save'):
            meal_plan.save()
        
        return meal_plan
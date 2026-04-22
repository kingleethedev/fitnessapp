# workout_engine.py
class WorkoutGenerator:
    def generate_workout(self, user, data):
        """
        Simple starter workout generator (placeholder logic)
        You will improve this later with AI/adaptive logic.
        """

        goal = data.get("goal", "general")
        experience = data.get("experience_level", "beginner")
        location = data.get("training_location", "gym")
        duration = 45

        # Basic exercise templates (you can expand later)
        base_exercises = [
            {"name": "Push Ups", "sets": 3, "reps": 12},
            {"name": "Squats", "sets": 3, "reps": 15},
            {"name": "Plank", "sets": 3, "duration": "30s"},
        ]

        # Simple difficulty scaling
        difficulty_score = 0.5
        intensity_level = 2

        if experience == "intermediate":
            difficulty_score = 0.7
            intensity_level = 3

        elif experience == "advanced":
            difficulty_score = 0.9
            intensity_level = 4
            base_exercises.append({"name": "Burpees", "sets": 4, "reps": 10})

        return {
            "duration": duration,
            "exercises": base_exercises,
            "difficulty_score": difficulty_score,
            "intensity_level": intensity_level,
        }
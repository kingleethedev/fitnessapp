# adaptive_logic.py
class AdaptiveLogicEngine:
    """
    Simple adaptive system that adjusts user difficulty based on performance.
    This is your foundation for AI-driven workouts.
    """

    def __init__(self, user):
        self.user = user

    def update_user_difficulty(self, logs):
        """
        Adjust user difficulty based on workout performance.
        """

        if not logs:
            return

        total_score = 0
        count = 0

        for log in logs:
            # evaluate performance
            target = log.get("target_reps") or 1
            actual = log.get("actual_reps") or 0

            if target > 0:
                performance = actual / target
                total_score += performance
                count += 1

        if count == 0:
            return

        avg_performance = total_score / count

        # SIMPLE ADAPTIVE LOGIC
        if avg_performance > 1.1:
            self.user.difficulty_level = getattr(self.user, "difficulty_level", 3) + 1
        elif avg_performance < 0.7:
            self.user.difficulty_level = getattr(self.user, "difficulty_level", 3) - 1

        # clamp values
        self.user.difficulty_level = max(1, min(5, self.user.difficulty_level))

        # save if possible
        if hasattr(self.user, "save"):
            self.user.save()
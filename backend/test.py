#!/usr/bin/env python
"""
Script to check, analyze, and update exercises in the database
Run with: python manage.py shell < check_exercises.py
Or copy-paste into Django shell
"""

from apps.workouts.models import TemplateWorkout, Workout, Exercise
from django.db import models
import json
from collections import Counter

print("=" * 80)
print("EXERCISE DATABASE ANALYSIS")
print("=" * 80)

# ============================================
# 1. CHECK EXERCISE LIBRARY (Exercise model)
# ============================================
print("\n📚 1. EXERCISE LIBRARY (Exercise model)")
print("-" * 40)

total_exercises = Exercise.objects.count()
exercises_with_video = Exercise.objects.exclude(video_url__isnull=True, video_file__isnull=True).count()
exercises_without_video = total_exercises - exercises_with_video
active_exercises = Exercise.objects.filter(is_active=True).count()

print(f"   Total exercises in library: {total_exercises}")
print(f"   Exercises with videos: {exercises_with_video} ✅")
print(f"   Exercises without videos: {exercises_without_video} ⚠️")
print(f"   Active exercises: {active_exercises}")

if total_exercises > 0:
    print(f"\n   📋 First 10 exercises in library:")
    for ex in Exercise.objects.all()[:10]:
        video_status = "✓ Has video" if ex.has_video() else "✗ No video"
        print(f"      - {ex.name} | Goal: {ex.primary_goal or 'Any'} | {video_status}")

# ============================================
# 2. CHECK WORKOUT TEMPLATES (TemplateWorkout)
# ============================================
print("\n\n📋 2. WORKOUT TEMPLATES (TemplateWorkout)")
print("-" * 40)

templates = TemplateWorkout.objects.all()
all_template_exercises = set()
template_exercise_details = []

for template in templates:
    exercises = template.exercises or []
    template_exercise_names = []
    
    for ex in exercises:
        name = ex.get('name', '').strip()
        if name:
            all_template_exercises.add(name)
            template_exercise_names.append(name)
    
    template_exercise_details.append({
        'name': template.name,
        'exercises': template_exercise_names,
        'count': len(template_exercise_names)
    })
    
    print(f"   Template: {template.name} - {len(template_exercise_names)} exercises")

print(f"\n   Total unique exercises across all templates: {len(all_template_exercises)}")

# ============================================
# 3. CHECK USER WORKOUTS (Workout model)
# ============================================
print("\n\n💪 3. USER WORKOUTS (Workout model)")
print("-" * 40)

user_workouts = Workout.objects.filter(is_completed=True)
all_user_exercises = set()

for workout in user_workouts[:100]:  # Check last 100 workouts
    exercises = workout.exercises or []
    for ex in exercises:
        name = ex.get('name', '').strip()
        if name:
            all_user_exercises.add(name)

print(f"   Unique exercises from user workouts: {len(all_user_exercises)}")

# ============================================
# 4. FIND MISSING EXERCISES
# ============================================
print("\n\n🔍 4. MISSING EXERCISES (In templates but not in library)")
print("-" * 40)

library_exercise_names = set(Exercise.objects.values_list('name', flat=True))
missing_exercises = all_template_exercises - library_exercise_names

if missing_exercises:
    print(f"   ⚠️ Found {len(missing_exercises)} exercises in templates that are NOT in library:")
    for i, name in enumerate(sorted(missing_exercises), 1):
        print(f"      {i}. {name}")
else:
    print("   ✅ All exercises from templates are in the library!")

# ============================================
# 5. EXERCISES WITHOUT VIDEOS
# ============================================
print("\n\n🎥 5. EXERCISES WITHOUT VIDEOS")
print("-" * 40)

exercises_need_video = Exercise.objects.filter(
    video_url__isnull=True,
    video_file__isnull=True,
    is_active=True
)

if exercises_need_video:
    print(f"   ⚠️ {exercises_need_video.count()} exercises need videos:")
    for ex in exercises_need_video[:20]:
        print(f"      - {ex.name}")
    if exercises_need_video.count() > 20:
        print(f"      ... and {exercises_need_video.count() - 20} more")
else:
    print("   ✅ All exercises have videos!")

# ============================================
# 6. STATISTICS SUMMARY
# ============================================
print("\n\n📊 6. STATISTICS SUMMARY")
print("-" * 40)
print(f"   Exercise Library Total:     {total_exercises}")
print(f"   With Videos:                {exercises_with_video}")
print(f"   Without Videos:             {exercises_without_video}")
print(f"   Coverage:                   {(exercises_with_video/total_exercises*100) if total_exercises > 0 else 0:.1f}%")
print(f"   Template Exercises Total:   {len(all_template_exercises)}")
print(f"   Missing from Library:       {len(missing_exercises)}")
print(f"   User Exercises Total:       {len(all_user_exercises)}")

# ============================================
# 7. AUTO-FIX: CREATE MISSING EXERCISES
# ============================================
print("\n\n🔧 7. OPTION: CREATE MISSING EXERCISES")
print("-" * 40)

if missing_exercises:
    print("   Would you like to create the missing exercises in the library?")
    print("   Run this code to auto-create them:\n")
    
    print("   ```python")
    print("   # Auto-create missing exercises")
    print("   for exercise_name in missing_exercises:")
    print("       exercise, created = Exercise.objects.get_or_create(")
    print("           name=exercise_name,")
    print("           defaults={")
    print("               'description': f'Auto-created from template',")
    print("               'is_active': True")
    print("           }")
    print("       )")
    print("       if created:")
    print("           print(f'Created: {exercise_name}')")
    print("   ```")
else:
    print("   ✅ No missing exercises to create!")

# ============================================
# 8. EXPORT TO JSON (for backup/reference)
# ============================================
print("\n\n💾 8. EXPORT EXERCISE DATA")
print("-" * 40)

export_data = {
    'library_exercises': list(Exercise.objects.values('id', 'name', 'primary_goal', 'has_video', 'is_active')),
    'template_exercises': list(all_template_exercises),
    'missing_exercises': list(missing_exercises),
    'exercises_without_video': list(exercises_need_video.values_list('name', flat=True))
}

# Save to file
import json
from django.utils import timezone

filename = f"exercise_export_{timezone.now().strftime('%Y%m%d_%H%M%S')}.json"
with open(filename, 'w') as f:
    json.dump(export_data, f, indent=2)

print(f"   ✅ Export saved to: {filename}")

print("\n" + "=" * 80)
print("ANALYSIS COMPLETE!")
print("=" * 80)

# ============================================
# AUTO-FIX FUNCTION (Uncomment to run)
# ============================================
"""
# UNCOMMENT THIS SECTION TO AUTO-CREATE MISSING EXERCISES
print("\n🔄 Auto-creating missing exercises...")
created_count = 0
for exercise_name in missing_exercises:
    exercise, created = Exercise.objects.get_or_create(
        name=exercise_name,
        defaults={
            'description': f'Auto-created from workout template',
            'is_active': True,
            'primary_goal': None,
            'experience_level': 'intermediate',
            'training_location': 'home'
        }
    )
    if created:
        created_count += 1
        print(f"   ✓ Created: {exercise_name}")

print(f"\n✅ Created {created_count} new exercises in the library!")
print("   Now go to the Exercise Library admin page to add videos to these exercises.")
"""
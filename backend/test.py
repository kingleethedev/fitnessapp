#!/usr/bin/env python3
"""
Fitness App API Testing Script
"""

import requests
import json
import time
from datetime import datetime
from typing import Dict, Any
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Configuration
BASE_URL = "https://hardly-urgency-length.ngrok-free.dev/api"

# Headers to bypass ngrok warning page
DEFAULT_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Accept": "application/json",
    "ngrok-skip-browser-warning": "69420",
}

TEST_USER = {
    "username": "testuser123",
    "email": "testuser123@example.com",
    "password": "TestPass123!",
    "confirm_password": "TestPass123!"
}

class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    END = '\033[0m'
    BOLD = '\033[1m'

def print_section(title: str):
    print(f"\n{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BOLD}{Colors.HEADER}{title}{Colors.END}")
    print(f"{Colors.BLUE}{'='*60}{Colors.END}")

def print_success(message: str):
    print(f"{Colors.GREEN}✓ {message}{Colors.END}")

def print_error(message: str):
    print(f"{Colors.RED}✗ {message}{Colors.END}")

def print_info(message: str):
    print(f"{Colors.YELLOW}ℹ {message}{Colors.END}")

def print_json(data: Any):
    """Pretty print JSON data"""
    print(json.dumps(data, indent=2, default=str))

def make_request(method: str, endpoint: str, token: str = None, data: Dict = None) -> Dict:
    url = f"{BASE_URL}{endpoint}"
    headers = DEFAULT_HEADERS.copy()
    
    if token:
        headers["Authorization"] = f"Bearer {token}"
    
    try:
        if method.upper() == "GET":
            response = requests.get(url, headers=headers, verify=False, timeout=10)
        elif method.upper() == "POST":
            response = requests.post(url, headers=headers, json=data, verify=False, timeout=10)
        else:
            return {"error": f"Unknown method: {method}"}
        
        if "ngrok" in response.text and "ERR_NGROK" in response.text:
            return {"error": "Ngrok warning page - Add 'ngrok-skip-browser-warning: true' header"}
        
        if response.status_code in [200, 201, 204]:
            if response.text:
                return response.json()
            return {"status": "success", "status_code": response.status_code}
        else:
            return {
                "error": f"HTTP {response.status_code}",
                "details": response.text[:200] if response.text else "No details"
            }
    except requests.exceptions.Timeout:
        return {"error": "Request timeout"}
    except requests.exceptions.ConnectionError as e:
        return {"error": f"Connection error: {str(e)}"}
    except Exception as e:
        return {"error": str(e)}

class APITester:
    def __init__(self):
        self.access_token = None
        self.refresh_token = None
        self.user_id = None
        
    def test_connection(self) -> bool:
        print_section("Testing API Connection")
        
        print_info(f"Connecting to: {BASE_URL}")
        
        response = make_request("GET", "/test/")
        
        if "error" in response:
            print_error(f"Cannot connect: {response['error']}")
            print_info("Troubleshooting:")
            print_info("1. Make sure Django is running: python manage.py runserver 0.0.0.0:8000")
            print_info("2. Make sure ngrok is running: ngrok http 8000")
            print_info(f"3. Test this URL in browser: {BASE_URL.replace('/api', '')}/api/test/")
            return False
        
        print_success(f"Connected to API!")
        print_json(response)
        return True
    
    def test_register(self) -> bool:
        print_section("Testing User Registration")
        
        print_info(f"Registering user: {TEST_USER['email']}")
        response = make_request("POST", "/auth/register/", data=TEST_USER)
        
        if "error" in response:
            # Check if user already exists
            if "unique" in str(response).lower() or "already exists" in str(response).lower():
                print_info("User already exists, trying to login instead...")
                return self.test_login()
            print_error(f"Registration failed: {response}")
            return False
        
        if "access" in response:
            self.access_token = response["access"]
            self.refresh_token = response["refresh"]
            print_success("Registration successful!")
            return True
        else:
            print_error(f"Unexpected response: {response}")
            return False
    
    def test_login(self) -> bool:
        print_section("Testing Login")
        
        login_data = {
            "email": TEST_USER["email"],
            "password": TEST_USER["password"]
        }
        
        print_info(f"Logging in as: {TEST_USER['email']}")
        response = make_request("POST", "/auth/login/", data=login_data)
        
        if "error" in response:
            print_error(f"Login failed: {response}")
            return False
        
        if "access" in response:
            self.access_token = response["access"]
            self.refresh_token = response["refresh"]
            print_success("Login successful!")
            return True
        else:
            print_error(f"Login failed: {response}")
            return False
    
    def test_get_profile(self) -> bool:
        print_section("Testing Get Profile")
        
        if not self.access_token:
            print_error("No access token. Please login first.")
            return False
        
        response = make_request("GET", "/users/profile/", token=self.access_token)
        
        if "error" in response:
            print_error(f"Failed to get profile: {response}")
            return False
        
        print_success("Profile retrieved!")
        print_json(response)
        return True
    
    def test_complete_onboarding(self) -> bool:
        print_section("Testing Complete Onboarding")
        
        if not self.access_token:
            print_error("No access token. Please login first.")
            return False
        
        onboarding_data = {
            "goal": "FITNESS",
            "experience_level": "INTERMEDIATE",
            "training_location": "HOME",
            "days_per_week": 4,
            "time_available": 30,
            "height": 175,
            "weight": 70
        }
        
        print_info("Sending onboarding data...")
        response = make_request("POST", "/users/complete_onboarding/", 
                                token=self.access_token, data=onboarding_data)
        
        if "error" in response:
            print_error(f"Onboarding failed: {response}")
            return False
        
        print_success("Onboarding completed!")
        return True
    
    def test_generate_workout(self) -> bool:
        print_section("Testing Generate Workout")
        
        if not self.access_token:
            print_error("No access token. Please login first.")
            return False
        
        workout_data = {
            "goal": "FITNESS",
            "experience_level": "INTERMEDIATE",
            "training_location": "HOME",
            "days_per_week": 4,
            "time_available": 30
        }
        
        print_info("Generating workout...")
        response = make_request("POST", "/workouts/generate/", 
                                token=self.access_token, data=workout_data)
        
        if "error" in response:
            print_error(f"Failed: {response}")
            return False
        
        print_success("Workout generated!")
        if "duration" in response:
            print_info(f"Duration: {response.get('duration')} minutes")
            print_info(f"Exercises: {len(response.get('exercises', []))}")
        return True
    
    def test_today_workout(self) -> bool:
        print_section("Testing Today's Workout")
        
        if not self.access_token:
            print_error("No access token. Please login first.")
            return False
        
        response = make_request("GET", "/workouts/today/", token=self.access_token)
        
        if "error" in response:
            print_error(f"Failed: {response}")
            return False
        
        print_success("Today's workout retrieved!")
        if "exercises" in response:
            print_info(f"Duration: {response.get('duration')} minutes")
            print_info(f"Exercises: {len(response.get('exercises', []))}")
        return True
    
    def test_workout_history(self) -> bool:
        print_section("Testing Workout History")
        
        if not self.access_token:
            print_error("No access token. Please login first.")
            return False
        
        response = make_request("GET", "/users/workout_history/", token=self.access_token)
        
        if "error" in response:
            print_error(f"Failed: {response}")
            return False
        
        print_success("Workout history retrieved!")
        print_info(f"Total workouts: {response.get('count', 0)}")
        return True
    
    def test_meal_plan(self) -> bool:
        print_section("Testing Current Meal Plan")
        
        if not self.access_token:
            print_error("No access token. Please login first.")
            return False
        
        response = make_request("GET", "/meals/current_plan/", token=self.access_token)
        
        if "error" in response:
            print_error(f"Failed: {response}")
            return False
        
        print_success("Meal plan retrieved!")
        if "meals" in response:
            days = list(response["meals"].keys())
            print_info(f"Days in plan: {', '.join(days)}")
        return True
    
    def test_generate_meal_plan(self) -> bool:
        print_section("Testing Generate Meal Plan")
        
        if not self.access_token:
            print_error("No access token. Please login first.")
            return False
        
        meal_data = {
            "goal": "HEALTHY_EATING"
        }
        
        print_info("Generating meal plan...")
        response = make_request("POST", "/meals/generate_plan/", 
                                token=self.access_token, data=meal_data)
        
        if "error" in response:
            print_error(f"Failed: {response}")
            return False
        
        print_success("Meal plan generated!")
        return True
    
    def test_todays_meals(self) -> bool:
        print_section("Testing Today's Meals")
        
        if not self.access_token:
            print_error("No access token. Please login first.")
            return False
        
        response = make_request("GET", "/meals/todays_meals/", token=self.access_token)
        
        if "error" in response:
            print_error(f"Failed: {response}")
            return False
        
        print_success("Today's meals retrieved!")
        if "meals" in response:
            print_info(f"Meals today: {len(response['meals'])}")
        return True
    
    def test_leaderboard(self) -> bool:
        print_section("Testing Leaderboard")
        
        if not self.access_token:
            print_error("No access token. Please login first.")
            return False
        
        response = make_request("GET", "/social/leaderboard/", token=self.access_token)
        
        if "error" in response:
            print_error(f"Failed: {response}")
            return False
        
        print_success("Leaderboard retrieved!")
        return True
    
    def test_friends(self) -> bool:
        print_section("Testing Friends List")
        
        if not self.access_token:
            print_error("No access token. Please login first.")
            return False
        
        response = make_request("GET", "/social/friends/", token=self.access_token)
        
        if "error" in response:
            print_error(f"Failed: {response}")
            return False
        
        print_success("Friends list retrieved!")
        return True
    
    def run_all_tests(self):
        print(f"\n{Colors.BOLD}{Colors.HEADER}")
        print("=" * 60)
        print("FITNESS APP API TEST SUITE")
        print(f"Target: {BASE_URL}")
        print("=" * 60)
        print(f"{Colors.END}")
        
        if not self.test_connection():
            print_error("Cannot proceed without API connection.")
            return
        
        tests = [
            ("User Registration", self.test_register),
            ("User Login", self.test_login),
            ("Get Profile", self.test_get_profile),
            ("Complete Onboarding", self.test_complete_onboarding),
            ("Generate Workout", self.test_generate_workout),
            ("Today's Workout", self.test_today_workout),
            ("Workout History", self.test_workout_history),
            ("Generate Meal Plan", self.test_generate_meal_plan),
            ("Current Meal Plan", self.test_meal_plan),
            ("Today's Meals", self.test_todays_meals),
            ("Leaderboard", self.test_leaderboard),
            ("Friends List", self.test_friends),
        ]
        
        results = []
        for test_name, test_func in tests:
            print_info(f"\nRunning: {test_name}...")
            try:
                success = test_func()
                results.append((test_name, success))
                time.sleep(0.5)
            except Exception as e:
                print_error(f"Exception: {str(e)}")
                results.append((test_name, False))
        
        print_section("TEST SUMMARY")
        passed = sum(1 for _, success in results if success)
        total = len(results)
        
        print(f"\nTotal Tests: {total}")
        print(f"{Colors.GREEN}Passed: {passed}{Colors.END}")
        print(f"{Colors.RED}Failed: {total - passed}{Colors.END}")
        print(f"Success Rate: {(passed/total)*100:.1f}%\n")
        
        if total - passed > 0:
            print(f"{Colors.YELLOW}Failed Tests:{Colors.END}")
            for test_name, success in results:
                if not success:
                    print(f"  - {test_name}")

if __name__ == "__main__":
    tester = APITester()
    tester.run_all_tests()
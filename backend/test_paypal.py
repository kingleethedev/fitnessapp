# test_paypal_final.py
import paypalrestsdk
import os
from dotenv import load_dotenv

load_dotenv()

CLIENT_ID = os.getenv('PAYPAL_CLIENT_ID')
CLIENT_SECRET = os.getenv('PAYPAL_CLIENT_SECRET')
MODE = os.getenv('PAYPAL_MODE', 'sandbox')

print("=" * 50)
print("PayPal API Test")
print("=" * 50)
print(f"Mode: {MODE}")
print(f"Client ID: {CLIENT_ID[:20]}...")
print(f"Client Secret: {'SET' if CLIENT_SECRET else 'NOT SET'}")
print("=" * 50)

# Configure PayPal
paypalrestsdk.configure({
    "mode": MODE,
    "client_id": CLIENT_ID,
    "client_secret": CLIENT_SECRET
})

# Test creating a simple payment
payment = paypalrestsdk.Payment({
    "intent": "sale",
    "payer": {
        "payment_method": "paypal"
    },
    "redirect_urls": {
        "return_url": "http://localhost:8000/success",
        "cancel_url": "http://localhost:8000/cancel"
    },
    "transactions": [{
        "amount": {
            "total": "1.00",
            "currency": "USD"
        },
        "description": "Test payment"
    }]
})

if payment.create():
    print("✅ SUCCESS! Payment created!")
    print(f"Payment ID: {payment.id}")
    for link in payment.links:
        if link.rel == "approval_url":
            print(f"Approval URL: {link.href}")
else:
    print("❌ Payment creation failed")
    print(f"Error: {payment.error}")
    
    # More detailed error
    if isinstance(payment.error, dict):
        print(f"Error name: {payment.error.get('name')}")
        print(f"Error message: {payment.error.get('message')}")
        print(f"Error details: {payment.error.get('details')}")
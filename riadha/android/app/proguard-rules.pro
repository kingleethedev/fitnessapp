# android/app/proguard-rules.pro

# Stripe SDK rules
-keep class com.stripe.android.** { *; }
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.stripe.android.pushProvisioning.**

# Keep your model classes
-keep class com.example.riadha.** { *; }

# Keep React Native (if used by any dependency)
-keep class com.facebook.react.** { *; }
-dontwarn com.facebook.react.**

# Keep any classes that might be used by Stripe
-keep class com.stripe.android.model.** { *; }
-keep class com.stripe.android.view.** { *; }

# Keep the PaymentSheet classes
-keep class com.stripe.android.PaymentSheet** { *; }
-keep class com.stripe.android.PaymentSession** { *; }

# Keep the Google Pay classes if you're using them
-keep class com.google.android.gms.wallet.** { *; }
-dontwarn com.google.android.gms.wallet.**

# Keep okhttp and related
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep GSON
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
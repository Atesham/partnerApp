# Flutter ProGuard/R8 Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Geolocator Background service keep rules
-keep class com.baseflow.geolocator.** { *; }

# Firebase Keep Rules
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Androidx Keep Rules
-keep class androidx.lifecycle.** { *; }
-keep class androidx.core.** { *; }

# Keep raw resources to prevent R8 from stripping notification sounds
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Ignore missing Play Core classes if dynamic features / split compat is not used
-dontwarn com.google.android.play.core.**


# Olympus View — ProGuard / R8 keep rules for release builds.
# Goal: keep plugin entry points the Flutter engine calls via reflection.

# Flutter embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# wifi_iot
-keep class com.alternadom.wifiiot.** { *; }

# mobile_scanner (Google MLKit barcode)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# OkHttp / okio (transitive via http package on Android)
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Preserve the line number information for debugging stack traces.
-keepattributes SourceFile,LineNumberTable

# Keep the original source file name for better debugging.
-renamesourcefileattribute SourceFile

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google ML Kit rules
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep classes that are referenced from native code
-keep class com.skmonio.taaltrek.MainActivity { *; }

# Supabase rules
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Audio players
-keep class xyz.luan.audioplayers.** { *; }

# File picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Image picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Path provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Shared preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# URL launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Vibration
-keep class com.dexterous.** { *; }

# App links
-keep class com.llfbandit.app_links.** { *; }

# Device info
-keep class dev.fluttercommunity.plus.device_info.** { *; }

# Google Play Core rules (fix R8 issues)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Flutter Play Store Split Application rules
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Keep all model classes
-keep class * extends java.io.Serializable { *; }
-keep class * implements java.io.Serializable { *; }

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable classes
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable classes
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

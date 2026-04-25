# Flutter wrapper rules
-keep class io.flutter.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.embedding.** { *; }

# Prevent R8 from removing Flutter plugins
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }

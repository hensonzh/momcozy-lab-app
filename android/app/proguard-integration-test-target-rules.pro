# Applied only when Gradle targets a Flutter integration_test entry point. The
# test libraries live in the tested release APK, so keep their reflective runner
# contract while the product and MediaPipe code remain fully optimized.
-keepattributes *Annotation*
-keep class androidx.test.** { *; }
-keep interface androidx.test.** { *; }
-keep class dev.flutter.plugins.integration_test.** { *; }
-keep interface dev.flutter.plugins.integration_test.** { *; }
-keep class org.junit.** { *; }
-keep interface org.junit.** { *; }
-keep class org.hamcrest.** { *; }
-keep interface org.hamcrest.** { *; }

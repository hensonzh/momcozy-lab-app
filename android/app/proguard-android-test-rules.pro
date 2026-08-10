# The tested app remains fully minified. Keep the separate instrumentation APK
# intact so AndroidJUnitRunner, FlutterTestRunner, and JUnit's reflection-based
# discovery remain available at runtime.
-dontshrink
-dontoptimize
-dontobfuscate

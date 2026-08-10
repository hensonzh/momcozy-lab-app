# MediaPipe's JNI bridge reads this wrapper's fields by their Java names.
# Neither field is referenced from Java after R8 inlines ProtoUtil.pack().
-keepclassmembers class com.google.mediapipe.framework.ProtoUtil$SerializedMessage {
    java.lang.String typeName;
    byte[] value;
}
-keepclassmembers class com.google.mediapipe.framework.Packet {
    public static com.google.mediapipe.framework.Packet create(long);
}
-keepclassmembers class com.google.mediapipe.framework.MediaPipeException {
    <init>(int, byte[]);
}

# The same native bridge resolves callback method names dynamically. Pin only
# that JNI contract (rather than every framework method, some of which refer to
# optional proto artifacts that are intentionally absent from Tasks Vision).
-keep interface com.google.mediapipe.framework.PacketCallback { *; }
-keep interface com.google.mediapipe.framework.PacketListCallback { *; }
-keep interface com.google.mediapipe.framework.PacketWithHeaderCallback { *; }
-keep interface com.google.mediapipe.framework.TextureReleaseCallback { *; }
-keep,allowobfuscation class * implements com.google.mediapipe.framework.PacketCallback {
    public void process(com.google.mediapipe.framework.Packet);
}
-keep,allowobfuscation class * implements com.google.mediapipe.framework.PacketListCallback {
    public void process(java.util.List);
}
-keep,allowobfuscation class * implements com.google.mediapipe.framework.PacketWithHeaderCallback {
    public void process(com.google.mediapipe.framework.Packet, com.google.mediapipe.framework.Packet);
}
-keep,allowobfuscation class * implements com.google.mediapipe.framework.TextureReleaseCallback {
    public void release(com.google.mediapipe.framework.GlSyncToken);
}

# MediaPipe Tasks also inspects generated Protobuf Lite fields at runtime. R8
# may otherwise remove backing fields whose generated accessors stay reachable.
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
}

# Flogger determines its caller from concrete stack frames. Keep the logger and
# caller-finder classes so release obfuscation does not erase that contract.
-keep class com.google.common.flogger.FluentLogger { *; }
-keep class com.google.common.flogger.util.CallerFinder { *; }
-keep class com.google.common.flogger.backend.system.StackBasedCallerFinder { *; }

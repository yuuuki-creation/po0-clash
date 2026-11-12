-keep class com.sun.jna.** { *; }
-keep class * implements com.sun.jna.** { *; }
-keep class io.github.yuuukicreation.po0clash.core.** { *; }
-dontwarn java.awt.**
-keep class org.yaml.snakeyaml.** { *; }
# JavaBeans belongs to SnakeYAML's desktop-only object introspector.
-dontwarn java.beans.**

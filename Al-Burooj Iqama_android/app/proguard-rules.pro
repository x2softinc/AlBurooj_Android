# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class com.alburooj.app.data.models.** { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class com.alburooj.app.**$$serializer { *; }
-keepclassmembers class com.alburooj.app.** { *** Companion; }
# OkHttp
-dontwarn okhttp3.internal.platform.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

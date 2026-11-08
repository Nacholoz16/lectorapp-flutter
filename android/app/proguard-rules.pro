# Reglas de R8/ProGuard para el build de release.
# Flutter y la mayoría de plugins ya aportan sus propias reglas; aquí solo van las
# que necesitan los plugins que usan reflexión.

# flutter_local_notifications: serializa la configuración con Gson (usa reflexión y genéricos).
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken

# flutter_background_service: el servicio en primer plano del cronómetro.
-keep class id.flutter.flutter_background_service.** { *; }

# Flutter referencia Play Core (deferred components) aunque la app no lo use.
-dontwarn com.google.android.play.core.**

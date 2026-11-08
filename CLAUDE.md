# CLAUDE.md — LectorApp (`test_lectorapp`)

Este archivo contiene el contexto técnico, la arquitectura, las librerías y las convenciones de diseño de **LectorApp**, una aplicación móvil de seguimiento de lectura y comunidad de reseñas desarrollada en **Flutter**. Sirve como guía base para cualquier agente o desarrollador que trabaje en este repositorio.

---

## 1. Contexto General del Proyecto

**LectorApp** (*"Tu rincón de lectura acogedor"*) es una aplicación social y personal de registro de lecturas con un enfoque minimalista ("Anti-Social Reader"). Permite a los usuarios:

- **Descubrir y buscar libros** (integrado en el backend con caché local en MySQL y Open Library API).
- **Registrar lecturas (`reading_logs`)** con estados (`leyendo`, `terminado`, `abandonado`), progreso de páginas (`current_page` / `page_count`), calificaciones de 1 a 5 estrellas, fechas de inicio/fin, reseñas de texto y visibilidad pública o privada.
- **Cronometrar sesiones de lectura en segundo plano** mediante un Foreground Service con notificación persistente en tiempo real y guardado de sesiones (`duration_minutes`, `pages_read`).
- **Interactuar en un Feed Global** paginado con soporte de caché local, detección de nuevas publicaciones, *optimistic UI* para Likes y opción de compartir enlaces (`https://nacholoz3d.cl/libro/<external_id>`).
- **Gestionar su Perfil y Estadísticas**, incluyendo metas de lectura anuales (Reto del año), métricas acumuladas (tiempo total, páginas leídas, promedio de estrellas, likes recibidos), ajustes de privacidad (perfil público/privado y estadísticas públicas/privadas) y selector de temas visuales.

> **⚠️ IMPORTANTE SOBRE LA CARPETA `backend/`:**
> La carpeta `backend/` dentro de este repositorio es **únicamente un espejo de lectura/referencia** de la API en Node.js + Express + MySQL (tal como indica `backend/Intrucciones.txt`), sincronizado con el repositorio principal (`../Lectorapp API`). **NO es la carpeta activa de desarrollo del backend**: úsala para consultar cómo están implementados los controladores, modelos SQL y rutas, pero cualquier cambio real al servidor debe aplicarse en `Lectorapp API`.

---

## 2. Stack Tecnológico y Librerías (`pubspec.yaml`)

### Entorno Base

- **SDK Dart:** `^3.0.0` (Flutter Material Design habilitado)
- **Versión actual:** `1.0.0+1`
- **Linter:** `flutter_lints: ^4.0.0`

### Dependencias Principales

| Librería                       | Versión    | Uso en el proyecto                                                                                                                     |
| :------------------------------ | :---------- | :------------------------------------------------------------------------------------------------------------------------------------- |
| `http`                        | `^1.1.0`  | Peticiones REST hacia la API mediante el wrapper centralizado `ApiClient`.                                                           |
| `flutter_secure_storage`      | `^10.3.1` | Almacenamiento cifrado del JWT (`auth-token`).                                                                                       |
| `shared_preferences`          | `^2.2.2`  | Persistencia ligera: datos de usuario (`user-data`), tema activo (`app_theme`) y caché offline del feed (`cached_global_feed`). |
| `cached_network_image`        | `^3.3.1`  | Caché en disco/memoria y pre-decodificación (`precacheImage`) de portadas de libros y avatares.                                    |
| `flutter_background_service`  | `^5.0.1`  | Ejecución del cronómetro de lectura en un *isolate* separado en segundo plano (`TimerBackgroundService`).                        |
| `flutter_local_notifications` | `^17.1.2` | Canal de notificaciones en Android (`reading_timer_channel`) para el servicio en primer plano del temporizador.                      |
| `google_fonts`                | `^6.2.1`  | Tipografías del sistema de diseño: **Lora** (títulos/serif) y **Nunito** (cuerpo/sans-serif).                           |
| `intl`                        | `^0.19.0` | Formateo de fechas localizado en español (`es`).                                                                                    |
| `share_plus`                  | `^10.1.2` | Compartir reseñas y enlaces de libros de forma nativa.                                                                                |
| `flutter_displaymode`         | `^0.6.0`  | Activación de alta tasa de refresco (120Hz/90Hz) en dispositivos Android compatibles al iniciar la app.                               |

### Dependencias de Desarrollo y Recursos

- `flutter_launcher_icons: ^0.13.1` y `flutter_native_splash: ^2.3.1` configurados con fondo crema (`#FDFBF7`) y `assets/logo.png`.

---

## 3. Estructura de Directorios

```text
test_lectorapp/
├── assets/
│   ├── logo.png                      # Logo principal y splash
│   └── logo_padded.png
├── backend/                          # [SOLO LECTURA] Espejo de referencia de la API Node.js/Express
├── lib/
│   ├── main.dart                     # Punto de entrada, inicialización de servicios y auto-login JWT
│   ├── config.dart                   # Configuración global: baseUrl y navigatorKey
│   ├── book_cover.dart               # Widget reutilizable de portada con sombra, caché y fallback
│   ├── models/
│   │   ├── book.dart                 # Modelo Book (normaliza external_id/google_id y author/authors) — actualmente SIN USO (no se importa en ningún archivo)
│   │   ├── reading_log.dart          # Modelo ReadingLog (estado, progreso, likes, reseña, safeAvatarUrl)
│   │   └── user_profile.dart         # Modelo UserProfile (datos de usuario, flags de privacidad y biblioteca)
│   ├── services/
│   │   ├── api_client.dart           # Singleton HTTP client (JWT en memoria, timeout 15s, manejo de 401)
│   │   ├── auth_service.dart         # Singleton de autenticación (login, registro, validación local de JWT)
│   │   ├── book_service.dart         # Búsqueda de libros y feed de reseñas por libro (NO es singleton, se instancia con BookService())
│   │   ├── reading_service.dart      # Singleton de lecturas (feed global, caché, CRUD logs, likes, sesiones, stats)
│   │   ├── user_service.dart         # Singleton de usuarios (perfil, biblioteca paginada, stats, meta anual, privacidad)
│   │   ├── theme_service.dart        # Singleton de temas con ValueNotifier<ThemeData> y 4 paletas pastel
│   │   └── timer_background_service.dart # Isolate y controlador del cronómetro en segundo plano
│   ├── screens/
│   │   ├── login_screen.dart         # Inicio de sesión (acepta email o username)
│   │   ├── register_screen.dart      # Registro de nuevos usuarios
│   │   ├── tabs_screen.dart          # Contenedor principal con IndexedStack y BottomNavigationBar (3 tabs)
│   │   ├── home_screen.dart          # Tab 0: Feed global, caché instantánea, pre-caching de imágenes, paginación
│   │   ├── search_screen.dart        # Tab 1: Buscador con debounce (300ms, mín. 3 caracteres)
│   │   ├── profile_screen.dart       # Tab 2: Mi Biblioteca, Estadísticas, Reto Anual, Timer, Ajustes
│   │   ├── public_profile_screen.dart# Perfil de otros usuarios (respeta candados de privacidad)
│   │   └── book_detail_screen.dart   # Vista detallada de un libro con fondo blur inmersivo y reseñas
│   └── widgets/
│       ├── user_card.dart            # Tarjeta versátil para el feed ('feed') o lista de reseñas ('review')
│       ├── log_book_modal.dart       # BottomSheet para registrar una nueva lectura
│       ├── edit_book_modal.dart      # BottomSheet para editar o eliminar un registro existente
│       ├── reading_timer_modal.dart  # BottomSheet del cronómetro conectado a TimerBackgroundService
│       ├── book_stats_modal.dart     # BottomSheet con métricas específicas de un libro
│       └── book_loader.dart          # Animación 3D personalizada de páginas pasando (Custom Loader)
└── pubspec.yaml
```

---

## 4. Arquitectura y Patrones Clave

### 4.1 Gestión de Estado y Navegación

- **Estado Local + Singletons:** El proyecto no utiliza librerías externas pesadas de gestión de estado (como Bloc o Riverpod). En su lugar, emplea `StatefulWidget` para el estado de las vistas, `AutomaticKeepAliveClientMixin` en las pestañas principales (`HomeScreen`, `ProfileScreen`) dentro de un `IndexedStack` para preservar el scroll y los datos en memoria, y servicios **Singleton** (`ApiClient`, `AuthService`, `ReadingService`, `UserService`, `ThemeService`).
- **Reactividad del Tema:** `ThemeService` expone un `ValueNotifier<ThemeData> currentTheme` escuchado en la raíz (`LectorApp` en `main.dart`) mediante `ValueListenableBuilder`.
- **Navegación Global en Errores 401:** `Config.navigatorKey` (`GlobalKey<NavigatorState>`) está inyectada en `MaterialApp`. Si cualquier petición en `ApiClient` devuelve HTTP `401`, el cliente limpia automáticamente el token de `FlutterSecureStorage` y `SharedPreferences` y redirige al usuario a `LoginScreen` limpiando el stack de navegación.

### 4.2 Cliente HTTP y Autenticación (`ApiClient` & `AuthService`)

- **URL Base:** Definida exclusivamente en `lib/config.dart`:
  - Producción: `https://api.nacholoz3d.cl/api`
  - Desarrollo local (emulador Android): `http://10.0.2.2:3000/api`
- **Caché de Token en Memoria:** Al arrancar la app (`main.dart`), `ApiClient().loadToken()` lee el JWT desde `FlutterSecureStorage` una única vez y lo mantiene en `_cachedToken` para evitar bloqueos de I/O en cada petición HTTP.
- **Validación proactiva de JWT:** `AuthService.isJwtValid(token)` decodifica en base64 el payload del JWT localmente en el arranque para comprobar su fecha de expiración (`exp`) antes de decidir si mostrar `TabsScreen` o `LoginScreen`.
- **Manejo de Errores:** Todas las llamadas de `ApiClient` tienen un timeout de `15 segundos` y lanzan `ApiException` extrayendo el campo `error` o `message` del JSON del backend.
- **Excepción — Login y Registro:** `AuthService.login()` y `AuthService.register()` **no** pasan por `ApiClient`: usan `http.post` directo (sin token, con el mismo timeout de 15s) y lanzan `Exception` genérica en vez de `ApiException`. Tras el éxito, guardan el token vía `ApiClient().setToken()` y el usuario en `SharedPreferences` (`user-data`).
- **Lógica de logout duplicada:** `AuthService.forceLogout()` existe, pero `ApiClient._handle401()` reimplementa la misma limpieza + redirección en lugar de llamarlo. Si se cambia el flujo de cierre de sesión, actualizar ambos lugares.
- **Logout en backend:** El backend expone `POST /auth/logout`, pero la app no lo consume; el logout es solo local (borra token y `user-data`).

### 4.3 Normalización de Datos y Quirks del Backend

0. **Uso real de los modelos:** La mayor parte de la app (feed de `HomeScreen`, `UserCard`, búsqueda, detalle de libro, modales) trabaja directamente con `Map<String, dynamic>` crudos de la API (ej. `feed[index]['has_liked']`). Los modelos tipados solo se usan en los perfiles: `ReadingLog.fromJson` y `UserProfile.fromJson` en `ProfileScreen` / `PublicProfileScreen`. El modelo `Book` está definido pero no se usa.
1. **Discrepancias de Nombres de Campos:** El backend y las respuestas cacheadas pueden alternar entre distintos nombres de propiedades. Los modelos (`Book`, `ReadingLog`) y algunos widgets están preparados para normalizarlos:
   - Autor: `json['authors'] ?? json['author']`
   - Portada: `json['cover_url'] ?? json['cover_image']`
   - ID Externo: `json['external_id'] ?? json['google_id'] ?? json['id']` (solo en `Book`; `ReadingLog` usa únicamente `external_id`)
   - Booleanos MySQL: MySQL guarda los booleanos como `1`/`0`. El backend actual ya los convierte a `true`/`false` en las respuestas relevantes (`has_liked` con `Boolean(...)`, `is_profile_public` / `are_stats_public` con `!!`), pero `is_log_public` y respuestas antiguas/cacheadas pueden llegar como entero. **Recomendación** para código nuevo: evaluar ambos (`val == true || val == 1`). Ojo: el código existente no lo hace de forma uniforme — `ReadingLog` sí lo hace para `is_log_public` y `has_liked`, pero `UserProfile.fromJson` compara solo `== true` y usa `json['are_stats_public'] ?? true` (fallaría si llegara un `int`), y `HomeScreen` / `UserCard` comparan `has_liked == true`.
2. **Avatares DiceBear (SVG a PNG):** El backend genera avatares por defecto usando DiceBear con rutas `/svg`. Dado que `CachedNetworkImageProvider` en Flutter rasteriza imágenes bitmap y falla con SVGs directos, siempre se normaliza la URL reemplazando `/svg` por `/png` (ver getter `safeAvatarUrl` en `ReadingLog` y `UserProfile`).
3. **Retrocompatibilidad de Paginación en Perfiles:** En `ProfileScreen` y `PublicProfileScreen`, se intenta cargar `/users/:username/library?page=X&limit=10`. Si el endpoint falla, hace fallback automático al arreglo `profileData['library']` embebido en `/users/:username`.

### 4.4 Rendimiento en el Feed (`HomeScreen`)

- **Carga Instantánea Offline-First:** Muestra primero el feed guardado en `SharedPreferences` (`cached_global_feed`) tras pre-cachear en memoria las primeras 5 portadas/avatares (`_precacheVisibleCovers` con timeout de 3s), y luego consulta en segundo plano si hay publicaciones con `id` mayor al primero en caché para mostrar el banner flotante de *"X nuevas publicaciones"*.
- **Optimistic UI:** Al dar "Me gusta" (`_handleToggleLike`), el estado visual se invierte inmediatamente antes de esperar la respuesta de `POST /readings/:id/like`, revirtiéndose solo si ocurre un error de red.

### 4.5 Cronómetro en Segundo Plano (`TimerBackgroundService`)

- Corre en un **isolate independiente** (`@pragma('vm:entry-point') void onStart(ServiceInstance service)`).
- **Importante:** Dentro de `onStart` no se puede acceder a plugins de UI ni al estado de la app principal directamente; toda comunicación entre el modal (`ReadingTimerModal`) y el servicio se realiza mediante paso de mensajes:
  - UI → Servicio: `startTimer`, `pauseTimer`, `resumeTimer`, `stopTimer`, `stopService`.
  - Servicio → UI: evento `'update'` emitido cada segundo con `{ seconds, isRunning, isFinished, selectedLog }`.
- Calcula el tiempo transcurrido mediante diferencia de `DateTime.now().difference(startTime!)` más `accumulatedSeconds` para evitar desfases del `Timer.periodic` cuando el sistema operativo suspende hilos.

---

## 5. Contrato de Endpoints Consumidos por la App

Todos los endpoints cuelgan de `Config.baseUrl` (`https://api.nacholoz3d.cl/api`):

### Autenticación (`/auth`)

- `POST /auth/login` — Body: `{ email | username, password }` → Retorna `{ token, user }`.
- `POST /auth/register` — Body: `{ username, email, password }` → Retorna `{ token, user }`.
- `POST /auth/logout` — Existe en el backend pero **la app no lo consume** actualmente.

### Libros (`/books`)

- `GET /books/search?q=<query>` — Busca libros en caché local MySQL + Open Library. Retorna `{ source, count, data: [...] }`.
- `GET /books/feed?external_id=<id>` — Obtiene las reseñas públicas asociadas a un libro.

### Lecturas y Sesiones (`/readings`)

- `GET /readings/feed?page=<p>&limit=<l>` — Feed global público paginado.
- `GET /readings/my-library?page=<p>&limit=<l>` — Biblioteca completa del usuario autenticado.
- `POST /readings` — Crea un registro de lectura. Body: `{ bookData: {...}, logData: {...} }`.
- `PUT /readings/:id` — Actualiza un registro de lectura (`status`, `rating`, `review_text`, `start_date`, `finish_date`, `is_log_public`, `current_page`).
- `DELETE /readings/:id` — Elimina un registro de lectura del usuario.
- `POST /readings/:id/like` — Alterna el like sobre una reseña. Retorna `{ liked: bool, likes_count: int }`.
- `POST /readings/:id/session` — Registra una sesión de lectura cronometrada. Body: `{ duration_minutes, pages_read, current_page? }`.
- `GET /readings/:id/stats` — Estadísticas específicas de un libro (`total_minutes`, `total_sessions`, `avg_session_minutes`).

### Usuarios y Perfiles (`/users`)

- `GET /users/:username` — Obtiene perfil del usuario (`username`, `bio`, `avatar_url`, `is_profile_public`, `are_stats_public`, `is_own_profile`, `is_private_lock`, `library`).
- `GET /users/:username/library?page=<p>&limit=<l>` — Biblioteca paginada de un usuario.
- `GET /users/:username/stats` — Estadísticas globales del usuario (`total_minutes`, `total_pages`, `finished_books`, `finished_books_this_year`, `target_books_this_year`, `avg_rating`, `total_likes`, `year`).
- `POST /users/goal` — Define la meta anual de libros. Body: `{ target_books: int }`.
- `PUT /users/privacy` — Actualiza privacidad. Body: `{ is_profile_public?: bool, are_stats_public?: bool }`.

---

## 6. Sistema de Diseño y Convenciones de UI

1. **Estética "Acogedora / Pastel" (Efecto Burbuja):**
   - Bordes altamente redondeados en tarjetas, inputs y botones (`BorderRadius.circular(20)` a `24.0`).
   - Sombras difusas y suaves coloreadas con el `primaryColor` activo a baja opacidad (`primaryColor.withValues(alpha: 0.08)`).
   - Inputs sin bordes marcados (`BorderSide.none`), con relleno sutil.
2. **Tipografía Dual:**
   - **Títulos y encabezados literarios:** Fuente `Lora` (Serif, elegante, `FontWeight.bold` o `w800`).
   - **Cuerpo de texto y controles:** Fuente `Nunito` (Sans-serif redondeada de lectura suave).
   - **Cómo se aplica:** `ThemeService` carga `GoogleFonts.nunitoTextTheme()` y `GoogleFonts.lora(...)` (en `appBarTheme` y el getter `ThemeService.titleStyle`). Sin embargo, varias pantallas (`login_screen`, `profile_screen`, `public_profile_screen`, `book_detail_screen`, `book_cover`) usan `fontFamily: 'Lora'` a mano; esto funciona porque el tema ya registró la fuente vía `google_fonts`. Para código nuevo, preferir `GoogleFonts.lora(...)` o `ThemeService.titleStyle`.
3. **Las 4 Paletas de Tema (`ThemeService`):**
   - `light` (**Crema & Salvia** - Default): Primario `#8BA89F`, Fondo `#FDFBF7`, Texto `#3D4042`.
   - `pink` (**Rosa Peonía**): Primario `#FF6B8A` / `#D8A7B1`, Fondo `#FEF9FA`.
   - `blue` (**Brisa de Mar**): Primario `#A1C4D0`, Fondo `#F7FBFD`.
   - `dark` (**Café de Medianoche**): Primario `#B59E86`, Fondo `#1C1917`, Cards `#292524`, Texto `#E7E5E4`.
4. **Colores Semánticos de Estado de Lectura:**
   - `terminado`: Verde (`#2DD55B` / `#81C784` en claro, `#66BB6A` en oscuro).
   - `leyendo`: Azul (`#4995FF`) o `Theme.of(context).primaryColor`.
   - `abandonado`: Rojo coral (`#FF4961` / `#E57373`).
   - Calificaciones (Estrellas): Amarillo cálido (`#FFD54F`).
5. **API de Opacidad en Flutter Moderno:**
   - Se utiliza `.withValues(alpha: X)` en lugar del deprecado `.withOpacity(X)`. Mantener esta convención en todo código nuevo.

---

## 7. Comandos Útiles de Desarrollo

```bash
# Instalar dependencias de Flutter
flutter pub get

# Analizar código estático y reglas de linting
flutter analyze

# Ejecutar en dispositivo o emulador conectado
flutter run

# Compilar APK de producción
flutter build apk --release

# Regenerar íconos o splash screen (si se modifican en pubspec.yaml)
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

---

## 8. Reglas para Futuras Modificaciones

1. **Nunca hardcodear URLs ni tokens:** Toda llamada HTTP nueva debe pasar por `ApiClient()` y ubicarse en el servicio correspondiente dentro de `lib/services/` (la única excepción existente es login/registro en `AuthService`, ver §4.2).
2. **Respetar el tema activo:** Evitar colores fijos de fondo o texto (`Colors.white`, `Colors.black`). Nota: el código actual aún tiene usos de `Colors.white`/`Colors.black` fuera de `theme_service.dart` (ej. `book_detail_screen`, `profile_screen`, `home_screen`, `public_profile_screen`, `login_screen`, `register_screen`, `book_cover`, modales); algunos son intencionales (texto sobre fondos con blur/imagen), no los tomes como patrón para código nuevo. Usar siempre `Theme.of(context).scaffoldBackgroundColor`, `Theme.of(context).cardColor`, `Theme.of(context).primaryColor` y comprobar `Theme.of(context).brightness == Brightness.dark` cuando se requiera contraste adaptativo.
3. **Imágenes de red:** Usar siempre `CachedNetworkImage` o `CachedNetworkImageProvider` (o el widget `BookCover` para portadas) y sanitizar URLs de avatares que puedan contener `/svg`.
4. **Verificación de `mounted`:** Antes de llamar a `setState()` o usar `BuildContext` (como `ScaffoldMessenger` o `Navigator`) después de un `await`, verificar siempre `if (mounted)`.
5. **No modificar `backend/` esperando cambios en la API:** Recordar que `backend/` en este repositorio es solo de referencia; cualquier cambio real de backend debe realizarse en el repositorio `Lectorapp API`.

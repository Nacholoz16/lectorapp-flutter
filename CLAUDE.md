# CLAUDE.md — LectorApp (`test_lectorapp`)

Este archivo contiene el contexto técnico, la arquitectura, las librerías y las convenciones de diseño de **LectorApp**, una aplicación móvil de seguimiento de lectura y comunidad de reseñas desarrollada en **Flutter**. Sirve como guía base para cualquier agente o desarrollador que trabaje en este repositorio.

---

## 1. Contexto General del Proyecto

**LectorApp** (*"Tu rincón de lectura acogedor"*) es una aplicación social y personal de registro de lecturas con un enfoque minimalista ("Anti-Social Reader"). Permite a los usuarios:

- **Descubrir y buscar libros** (integrado en el backend con caché local en MySQL y Open Library API).
- **Registrar lecturas (`reading_logs`)** con estados (`leyendo`, `terminado`, `abandonado`), progreso de páginas (`current_page` / `page_count`), calificaciones de 1 a 5 estrellas, fechas de inicio/fin, reseñas de texto y visibilidad pública o privada.
- **Cronometrar sesiones de lectura en segundo plano** mediante un Foreground Service con notificación persistente en tiempo real y guardado de sesiones (`duration_minutes`, `pages_read`).
- **Interactuar en un Feed Global** paginado por cursor, con caché local, detección de nuevas publicaciones, *optimistic UI* para Likes y opción de compartir enlaces (`https://nacholoz3d.cl/libro/<external_id>`).
- **Gestionar su Perfil y Estadísticas**, incluyendo metas de lectura anuales (Reto del año), métricas acumuladas (tiempo total, páginas leídas, promedio de estrellas, likes recibidos), ajustes de privacidad (perfil público/privado y estadísticas públicas/privadas) y selector de temas visuales.

> **⚠️ IMPORTANTE SOBRE LA CARPETA `backend/`:**
> La carpeta `backend/` dentro de este repositorio es **únicamente un espejo de lectura/referencia** de la API en Node.js + Express + MySQL (tal como indica `backend/Intrucciones.txt`), sincronizado con el repositorio principal (`../Lectorapp API`). **NO es la carpeta activa de desarrollo del backend**: úsala para consultar cómo están implementados los controladores, modelos SQL y rutas, pero cualquier cambio real al servidor debe aplicarse en `Lectorapp API` y luego re-sincronizar el espejo (ver §7).

---

## 2. Stack Tecnológico y Librerías (`pubspec.yaml`)

### Entorno Base

- **SDK Dart:** `^3.0.0` (Flutter Material Design habilitado)
- **Versión actual:** `1.0.0+1`
- **Linter:** `flutter_lints: ^4.0.0` + reglas extra en `analysis_options.yaml` (`use_build_context_synchronously`, `unawaited_futures`, `cancel_subscriptions`, `close_sinks`, `prefer_const_*`, `always_declare_return_types`, `avoid_catching_errors`, …). `flutter analyze` debe quedar **sin issues**.
- **Android:** Kotlin Gradle Plugin `2.2.20`, AGP `8.7.0`, Gradle `8.10.2`.

### Dependencias Principales

| Librería                       | Versión    | Uso en el proyecto                                                                                                                     |
| :------------------------------ | :---------- | :------------------------------------------------------------------------------------------------------------------------------------- |
| `http`                        | `^1.1.0`  | Peticiones REST hacia la API mediante el wrapper centralizado `ApiClient` (un único `http.Client` reutilizado, keep-alive).          |
| `flutter_secure_storage`      | `^10.3.1` | Almacenamiento cifrado del JWT (`auth-token`).                                                                                       |
| `shared_preferences`          | `^2.2.2`  | Persistencia ligera: datos de usuario (`user-data`: solo `id`, `username`, `avatar`), tema activo (`app_theme`) y caché offline del feed (`cached_global_feed`). |
| `cached_network_image`        | `^3.3.1`  | Caché en disco/memoria y pre-decodificación (`precacheImage`) de portadas de libros y avatares.                                    |
| `flutter_background_service`  | `^5.0.1`  | Ejecución del cronómetro de lectura en un *isolate* separado en segundo plano (`TimerBackgroundService`).                        |
| `flutter_local_notifications` | `^17.1.2` | Canal de notificaciones en Android (`reading_timer_channel`) para el servicio en primer plano del temporizador.                      |
| `google_fonts`                | `^6.2.1`  | Tipografías del sistema de diseño: **Lora** (títulos/serif) y **Nunito** (cuerpo/sans-serif).                           |
| `intl`                        | `^0.19.0` | Formateo de fechas localizado en español (`es`).                                                                                    |
| `share_plus`                  | `^10.1.2` | Compartir reseñas y enlaces de libros de forma nativa.                                                                                |
| `flutter_displaymode`         | `^0.6.0`  | Activación de alta tasa de refresco (120Hz/90Hz) en dispositivos Android compatibles al iniciar la app.                               |

### Dependencias de Desarrollo y Recursos

- `flutter_launcher_icons: ^0.13.1` y `flutter_native_splash: ^2.3.1` configurados con fondo crema (`#FDFBF7`) y `assets/logo.png`.
- `flutter_test` con tests unitarios en `test/`.

---

## 3. Estructura de Directorios

```text
test_lectorapp/
├── android/
│   └── app/
│       ├── build.gradle.kts          # Release: R8 (minify + shrink), firma PENDIENTE (usa claves debug)
│       ├── proguard-rules.pro        # Keeps para flutter_local_notifications (Gson) y background_service
│       └── src/
│           ├── main/AndroidManifest.xml   # allowBackup=false, solo HTTPS, servicio no exportado
│           ├── main/res/xml/data_extraction_rules.xml
│           └── debug/                # SOLO debug: permite HTTP a 10.0.2.2/localhost (API local)
├── assets/
│   ├── logo.png                      # Logo principal y splash
│   └── logo_padded.png
├── backend/                          # [SOLO LECTURA] Espejo de referencia de la API Node.js/Express
├── lib/
│   ├── main.dart                     # Punto de entrada: inits en paralelo (Future.wait) y auto-login JWT
│   ├── config.dart                   # baseUrl (vía --dart-define API_BASE_URL) y navigatorKey
│   ├── book_cover.dart               # Widget reutilizable de portada con sombra, caché y fallback
│   ├── models/
│   │   ├── book.dart                 # Modelo Book (normaliza external_id/google_id y author/authors) — SIN USO actualmente
│   │   ├── reading_log.dart          # Modelo ReadingLog (estado, progreso, likes, reseña, safeAvatarUrl)
│   │   └── user_profile.dart         # Modelo UserProfile (datos de usuario, flags de privacidad y biblioteca)
│   ├── services/
│   │   ├── api_client.dart           # Singleton HTTP: JWT en memoria, timeout 15s, 401 → Login, errores → ApiException
│   │   ├── auth_service.dart         # Login/registro (vía ApiClient), logout con revocación, validación local de JWT
│   │   ├── book_service.dart         # Búsqueda de libros y feed de reseñas por libro (NO es singleton)
│   │   ├── reading_service.dart      # Singleton: feed por cursor, new-count, caché, CRUD logs, likes, sesiones, stats
│   │   ├── user_service.dart         # Singleton: perfil, biblioteca paginada, stats, meta anual, privacidad
│   │   ├── theme_service.dart        # Singleton de temas con ValueNotifier<ThemeData> y 4 paletas pastel
│   │   └── timer_background_service.dart # Isolate y controlador del cronómetro en segundo plano
│   ├── utils/
│   │   └── json_utils.dart           # asBool / asInt: lectura tolerante de JSON (bool o 1/0, int o String)
│   ├── screens/
│   │   ├── login_screen.dart         # Inicio de sesión (acepta email o username)
│   │   ├── register_screen.dart      # Registro con validación local (mismas reglas que la API)
│   │   ├── tabs_screen.dart          # Contenedor principal con IndexedStack y BottomNavigationBar (3 tabs)
│   │   ├── home_screen.dart          # Tab 0: Feed global, caché instantánea, pre-caching de imágenes, cursor
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
├── test/
│   └── models_and_utils_test.dart    # Tests de asBool, modelos, isJwtValid y extracción de errores
└── pubspec.yaml
```

---

## 4. Arquitectura y Patrones Clave

### 4.1 Gestión de Estado y Navegación

- **Estado Local + Singletons:** El proyecto no utiliza librerías externas pesadas de gestión de estado (como Bloc o Riverpod). En su lugar, emplea `StatefulWidget` para el estado de las vistas, `AutomaticKeepAliveClientMixin` en las pestañas principales (`HomeScreen`, `ProfileScreen`) dentro de un `IndexedStack` para preservar el scroll y los datos en memoria, y servicios **Singleton** (`ApiClient`, `AuthService`, `ReadingService`, `UserService`, `ThemeService`).
- **Reactividad del Tema:** `ThemeService` expone un `ValueNotifier<ThemeData> currentTheme` escuchado en la raíz (`LectorApp` en `main.dart`) mediante `ValueListenableBuilder`.
- **Navegación Global en Errores 401:** `Config.navigatorKey` (`GlobalKey<NavigatorState>`) está inyectada en `MaterialApp`. Si una petición de `ApiClient` devuelve `401`, el cliente ejecuta `clearSession()` (token, `user-data` y `cached_global_feed`) y redirige a `LoginScreen` limpiando el stack. Un flag evita que varias peticiones con 401 simultáneas apilen varias pantallas de login.

### 4.2 Cliente HTTP y Autenticación (`ApiClient` & `AuthService`)

- **URL Base:** `lib/config.dart` la lee de `--dart-define=API_BASE_URL=...`; si no se pasa, usa **producción** (`https://api.nacholoz3d.cl/api`). **No editar `config.dart` para desarrollo** (ver §7 y las configuraciones de `.vscode/launch.json`).
  - Emulador Android: `http://10.0.2.2:3000/api`
  - Teléfono físico: `http://localhost:3000/api` + `adb reverse tcp:3000 tcp:3000`
- **TODA llamada HTTP pasa por `ApiClient`**, incluidos login y registro. `ApiClient` tiene un único método interno `_send` y expone `get/post/put/delete`.
- **`redirectOn401: false`** en `post()` para login, registro y logout: ahí un 401 significa "credenciales inválidas" o "token ya revocado", no "sesión expirada".
- **Manejo de Errores:** timeout de 15 s. Toda falla se convierte en `ApiException(message, statusCode)`:
  - HTTP 4xx/5xx → mensaje del campo `error` (o `message`) del JSON del backend.
  - Cuerpo no-JSON (ej. HTML de Nginx en un 502) → mensaje genérico, sin `FormatException`.
  - `TimeoutException`, `SocketException`, `ClientException` → mensajes amigables con `statusCode: 0`.
- **Caché de Token en Memoria:** `ApiClient().loadToken()` lee el JWT de `FlutterSecureStorage` una sola vez al arrancar.
- **Validación proactiva de JWT:** `AuthService.isJwtValid(token)` decodifica el payload localmente para comprobar `exp` (la firma la valida siempre el backend). Si el token expiró al arrancar, `main.dart` solo hace `clearSession()` (sin llamar a la red).
- **Logout:** `AuthService.logout()` llama a `POST /auth/logout` (revoca el token en el servidor; si no hay red, no bloquea) y luego `clearSession()`.

### 4.3 Normalización de Datos y Quirks del Backend

0. **Uso real de los modelos:** La mayor parte de la app (feed de `HomeScreen`, `UserCard`, búsqueda, detalle de libro, modales) trabaja con `Map<String, dynamic>` crudos de la API. Los modelos tipados se usan en los perfiles (`ReadingLog.fromJson`, `UserProfile.fromJson`). El modelo `Book` está definido pero no se usa.
1. **Lectura tolerante:** usar siempre `asBool(...)` / `asInt(...)` de `lib/utils/json_utils.dart` al leer booleanos o enteros de un `Map` de la API. MySQL guarda booleanos como `1`/`0`; el backend actual normaliza a `true`/`false` (`has_liked`, `is_log_public`, `is_profile_public`, `are_stats_public`) y `likes_count` a número, pero la caché local o respuestas antiguas pueden traer enteros o strings.
2. **Discrepancias de Nombres de Campos** (normalizadas en modelos y algunos widgets):
   - Autor: `json['authors'] ?? json['author']`
   - Portada: `json['cover_url'] ?? json['cover_image']`
   - ID Externo: `json['external_id'] ?? json['google_id'] ?? json['id']` (solo en `Book`; `ReadingLog` usa únicamente `external_id`)
3. **Avatares DiceBear (SVG a PNG):** el backend genera avatares por defecto con rutas `/svg`; `CachedNetworkImageProvider` no rasteriza SVG, así que siempre se reemplaza `/svg` por `/png` (getter `safeAvatarUrl` en `ReadingLog` y `UserProfile`).
4. **Biblioteca en perfiles:** `GET /users/:username` ya incluye la **primera página** de la biblioteca (`library`). `ProfileScreen` y `PublicProfileScreen` la usan directamente y solo piden `/users/:username/library?page=N` para las páginas siguientes.

### 4.4 Rendimiento en el Feed (`HomeScreen`)

- **Carga Instantánea Offline-First:** muestra primero el feed guardado en `SharedPreferences` (`cached_global_feed`) tras pre-cachear las primeras 5 portadas/avatares (`_precacheVisibleCovers`, timeout de 3 s).
- **Paginación por cursor:** las páginas siguientes se piden con `before_id = id del último elemento cargado` (`GET /readings/feed?limit=10&before_id=<id>`). No usar `page`/OFFSET en el feed: duplicaba o saltaba publicaciones cuando entraban nuevas.
- **Banner "X nuevas publicaciones":** `GET /readings/feed/new-count?after_id=<id del primero>` devuelve solo `{ count }`.
- **Optimistic UI en Likes:** `_handleToggleLike` invierte el estado al instante y lo confirma o revierte con la respuesta. La publicación se actualiza **por `id`**, no por índice (el feed puede recargarse durante la petición).

### 4.5 Cronómetro en Segundo Plano (`TimerBackgroundService`)

- Corre en un **isolate independiente** (`@pragma('vm:entry-point') void onStart(ServiceInstance service)`).
- **Importante:** dentro de `onStart` no se puede acceder a plugins de UI ni al estado de la app; toda comunicación es por mensajes:
  - UI → Servicio: `startTimer`, `pauseTimer`, `resumeTimer`, `stopTimer`, `stopService`.
  - Servicio → UI: `'ready'` (una vez, cuando los listeners están registrados) y `'update'` cada segundo con `{ seconds, isRunning, isFinished, selectedLog }`.
- `TimerBackgroundService.start()` espera el evento `'ready'` (timeout 3 s) antes de enviar `startTimer`; no usar esperas fijas.
- El tiempo se calcula con `DateTime.now().difference(startTime!)` + `accumulatedSeconds` para no desfasarse cuando el SO suspende hilos.
- `ReadingTimerModal` solo reescribe el campo "página actual" cuando cambia el libro seleccionado (no en cada `'update'`).

---

## 5. Contrato de la API

Todos los endpoints cuelgan de `Config.baseUrl`. Salvo `/auth/login`, `/auth/register` y `/books/feed`, requieren `Authorization: Bearer <JWT>`.

### Formato de errores

Todas las respuestas de error tienen la forma `{ "error": string, "code": string }`:

| HTTP | `code` | Cuándo |
|---|---|---|
| 400 | `VALIDATION_ERROR`, `INVALID_JSON` | Body/query/params no cumplen el esquema Zod |
| 401 | `UNAUTHORIZED` | Falta token, token inválido/expirado/revocado, credenciales inválidas |
| 403 | `FORBIDDEN` | Recurso de otro usuario o privado |
| 404 | `NOT_FOUND` | Recurso o ruta inexistente |
| 409 | `CONFLICT` | Email/username ya registrado, libro ya registrado por el usuario |
| 429 | `RATE_LIMITED` | Demasiadas peticiones |
| 500 | `INTERNAL_ERROR` | Error no controlado (el detalle solo va al log del servidor) |

### Reglas de validación relevantes para la UI

- **Registro:** `username` `^[a-zA-Z0-9_.-]{3,30}$`; `email` válido (se guarda en minúsculas); `password` ≥ 8 caracteres y ≤ 72 bytes.
- **Lecturas:**
  - `status` ∈ `leyendo|terminado|abandonado`.
  - `rating` entero de 1 a 5, o `null` (0 equivale a `null`).
  - `review_text` ≤ 5000 caracteres.
  - Fechas en formato `YYYY-MM-DD`, con `finish_date >= start_date`.
  - `cover_url` solo de `covers.openlibrary.org` o Google Books (`https`).
- **Sesiones:** `duration_minutes` de 1 a 1440; `pages_read` de 0 a 5000.
- **Paginación:** `limit` ≤ 50.

### Autenticación (`/auth`)

- `POST /auth/login` — Body: `{ email | username, password }` → `{ token, user }`.
- `POST /auth/register` — Body: `{ username, email, password }` → `201 { token, user }`.
- `POST /auth/logout` — Requiere token. Lo revoca (blacklist por hash SHA-256) → `{ success: true }`.

### Libros (`/books`)

- `GET /books/search?q=<query>` — Caché local MySQL + Open Library (resultados de Open Library cacheados 10 min en el servidor). → `{ data: [...] }`.
- `GET /books/feed?external_id=<id>` — Reseñas públicas de un libro (público, máx. 100).

### Lecturas y Sesiones (`/readings`)

- `GET /readings/feed?limit=<l>&before_id=<id>` — Feed global público, paginado por cursor (sin `before_id` = primera página).
- `GET /readings/feed/new-count?after_id=<id>` — `{ count }` de publicaciones públicas más nuevas que `after_id`.
- `GET /readings/my-library?page=<p>&limit=<l>` — Biblioteca completa del usuario autenticado.
- `POST /readings` — Body: `{ bookData: {...}, logData: {...} }` → `201 { logId }`. 409 si el libro ya está registrado.
- `PUT /readings/:id` — **Update parcial**: solo se modifican los campos enviados (`status`, `rating`, `review_text`, `start_date`, `finish_date`, `is_log_public`, `current_page`).
- `DELETE /readings/:id` — Elimina un registro propio.
- `POST /readings/:id/like` — Alterna el like → `{ liked: bool, likes_count: int }`.
- `POST /readings/:id/session` — Body: `{ duration_minutes, pages_read, current_page? }` (en transacción).
- `GET /readings/:id/stats` — `{ total_minutes, total_sessions, avg_session_minutes, log_info }`.

### Usuarios y Perfiles (`/users`)

- `GET /users/:username` — `{ username, bio, avatar_url, is_profile_public, are_stats_public, is_own_profile, is_private_lock, library }` (`library` = primera página).
- `GET /users/:username/library?page=<p>&limit=<l>` — Biblioteca paginada.
- `GET /users/:username/stats` — `{ total_minutes, total_pages, finished_books, finished_books_this_year, target_books_this_year, avg_rating, total_likes, year, is_private }` o `{ is_private: true }`. `total_pages` = por cada lectura, `page_count` si está terminada (y se conoce), si no `current_page`.
- `POST /users/goal` — Body: `{ target_books: 1..1000 }`.
- `PUT /users/privacy` — Body: `{ is_profile_public?: bool, are_stats_public?: bool }` (al menos uno; campos extra → 400).

---

## 6. Sistema de Diseño y Convenciones de UI

1. **Estética "Acogedora / Pastel" (Efecto Burbuja):**
   - Bordes altamente redondeados en tarjetas, inputs y botones (`BorderRadius.circular(20)` a `24.0`).
   - Sombras difusas y suaves coloreadas con el `primaryColor` activo a baja opacidad (`primaryColor.withValues(alpha: 0.08)`).
   - Inputs sin bordes marcados (`BorderSide.none`), con relleno sutil.
2. **Tipografía Dual:**
   - **Títulos y encabezados literarios:** Fuente `Lora` (Serif, elegante, `FontWeight.bold` o `w800`).
   - **Cuerpo de texto y controles:** Fuente `Nunito` (Sans-serif redondeada de lectura suave).
   - **Cómo se aplica:** `ThemeService` carga `GoogleFonts.nunitoTextTheme()` y `GoogleFonts.lora(...)` (en `appBarTheme` y el getter `ThemeService.titleStyle`). Varias pantallas usan `fontFamily: 'Lora'` a mano; funciona porque el tema ya registró la fuente. Para código nuevo, preferir `GoogleFonts.lora(...)` o `ThemeService.titleStyle`.
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
# Instalar dependencias / analizar / tests
flutter pub get
flutter analyze            # debe quedar "No issues found!"
flutter test

# --- Ejecutar contra la API LOCAL (Lectorapp API con `npm run dev`) ---
# Emulador Android:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
# Teléfono físico (USB o depuración inalámbrica):
adb reverse tcp:3000 tcp:3000
flutter run -d <device-id> --dart-define=API_BASE_URL=http://localhost:3000/api
# En VS Code: configuraciones "LectorApp (API local - teléfono / emulador / producción)"
# en .vscode/launch.json (la de teléfono hace el adb reverse automáticamente).

# Ejecutar contra PRODUCCIÓN (sin dart-define)
flutter run

# Release (R8 + ofuscación Dart). Guardar build/symbols de cada versión publicada:
# sin ellos no se pueden leer los stack traces de errores de usuarios.
flutter build apk --release --obfuscate --split-debug-info=build/symbols
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols   # para Google Play

# Regenerar íconos o splash screen (si se modifican en pubspec.yaml)
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# Re-sincronizar el espejo backend/ desde el repo de la API (rama/commit actual)
git -C "../Lectorapp API" archive HEAD | tar -x -C backend
```

### API (`../Lectorapp API`)

```bash
npm run dev          # servidor con nodemon (puerto 3000)
npm test             # tests E2E (Jest + supertest) contra la BD anti_social_test
npm run test:setup   # crea/actualiza el esquema de la BD de test
npm run migrate      # migración idempotente (ejecutar en cada entorno tras desplegar)
npm run cleanup      # borra tokens revocados expirados
```

**Deploy a producción** (servidor Docker `ubuntu@155.181.180.178`, ver `../Lectorapp API/DEPLOY.md`):
`git push origin main` en el repo de la API y luego ejecutar `deploy\deploy.bat` (usa PuTTY/`plink` + la llave `.ppk`).
`deploy\deploy.bat <commit>` hace rollback. En el servidor, `~/[LECTORAPP]/api` es un clon git del repo de la API
y los secretos están en `~/[LECTORAPP]/.env` (fuera de git). El front web viejo (`lectorFront`, Ionic) no se toca.

---

## 8. Reglas para Futuras Modificaciones

1. **Nunca hardcodear URLs ni tokens:** toda llamada HTTP nueva pasa por `ApiClient()` desde el servicio correspondiente en `lib/services/`. La URL base solo cambia vía `--dart-define`.
2. **Respetar el tema activo:** evitar colores fijos de fondo o texto (`Colors.white`, `Colors.black`). El código actual aún tiene algunos usos fuera de `theme_service.dart` (varios intencionales sobre fondos con blur/imagen); no tomarlos como patrón. Usar `Theme.of(context).scaffoldBackgroundColor`, `cardColor`, `primaryColor` y comprobar `brightness == Brightness.dark` cuando se requiera contraste adaptativo.
3. **Imágenes de red:** usar siempre `CachedNetworkImage` / `CachedNetworkImageProvider` (o `BookCover`) y sanitizar URLs de avatares con `/svg`.
4. **Verificación de `mounted`:** antes de `setState()` o de usar `BuildContext` después de un `await`, comprobar `if (mounted)`. El linter (`use_build_context_synchronously`) lo vigila.
5. **Futures sin esperar:** si una llamada async se lanza sin `await` a propósito (carga en segundo plano, navegación), envolverla en `unawaited(...)` (`dart:async`). El linter (`unawaited_futures`) marca el resto como posibles errores.
6. **Leer JSON con `asBool` / `asInt`** (`lib/utils/json_utils.dart`), nunca con `== true` directo.
7. **Validación duplicada a propósito:** si cambian las reglas de validación de la API (`src/api/validators/*`), actualizar también la validación local equivalente (ej. `register_screen.dart`).
8. **No modificar `backend/` esperando cambios en la API:** los cambios reales van en `Lectorapp API`; luego re-sincronizar el espejo.
9. **App y API se despliegan juntas** cuando cambia el contrato (ej. el feed por cursor no funciona contra una API antigua).

---

## 9. Pendientes Conocidos

- **Firma de release:** `android/app/build.gradle.kts` firma el release con las claves de **debug**. Antes de publicar en Google Play hay que crear un keystore propio y configurar `signingConfigs.release` (guía: https://docs.flutter.dev/deployment/android#sign-the-app). El keystore y sus contraseñas no deben subirse al repositorio.
- **Modelos tipados en el feed:** `HomeScreen`/`UserCard` usan `Map` crudos; migrar a `ReadingLog` (con `copyWith`) daría más seguridad de tipos.
- **Búsqueda local:** `BookModel.searchLocal` usa `LIKE '%q%'` (escaneo completo). Con decenas de miles de libros, migrar a índice `FULLTEXT(title, author)`.
- **Refresh tokens:** el JWT dura 7 días sin renovación; al expirar el usuario debe volver a iniciar sesión.
- **Dependencias desactualizadas:** varios paquetes tienen versiones mayores nuevas (`flutter pub outdated`); actualizarlas con pruebas.

# CLAUDE.md — LectorApp (`test_lectorapp`)

Guía técnica para cualquier agente o desarrollador que trabaje en este repositorio: qué es la app,
cómo está construida, qué contratos respeta y qué reglas seguir al modificarla. Describe el estado
**real del código en la versión 1.1.0** (tag `v1.1.0`); lo planificado para después vive en
`BACKLOG.md` y `PENDIENTES.md` y no se describe aquí.

Última revisión completa contra el código: 2026-11-11 (`flutter analyze` sin issues, 47 tests en verde,
Flutter 3.44.7 / Dart 3.12.2).

---

## 1. Qué es LectorApp

**LectorApp** (*"Tu rincón de lectura acogedor"*) es una app móvil **Flutter** (Android como
plataforma principal) para llevar un registro personal de lecturas, con una capa social mínima
("Anti-Social Reader"): privado por defecto, un feed global de lo que la gente decide compartir y
"me gusta". No hay seguidores, comentarios ni mensajes.

Qué puede hacer el usuario hoy:

| Área | Funcionalidad |
|---|---|
| Cuenta | Registro (con aceptación obligatoria de Términos y Política de privacidad; a las cuentas anteriores se les pide antes de publicar por primera vez), login con email **o** username, sesión que se renueva sola, logout con revocación, recuperación de contraseña con código de 6 dígitos por email. Desactivar y reactivar la cuenta (pausa voluntaria: lecturas privadas y perfil oculto; con la cuenta desactivada solo se ve la biblioteca, en modo lectura). |
| Buscar | Búsqueda de libros (caché MySQL + Open Library en el servidor), detalle del libro con reseñas públicas. |
| Lecturas | Añadir/editar/eliminar una lectura (`reading_log`): estado `leyendo`/`terminado`/`abandonado`, página actual, 1–5 estrellas, fechas, texto libre y visibilidad pública/privada. Borrador automático local. |
| Cronómetro | Sesiones de lectura cronometradas en un servicio en primer plano (notificación persistente); al terminar se guardan minutos y páginas. |
| Feed | Feed global paginado por cursor, caché offline, banner de publicaciones nuevas, like optimista, compartir enlace (`https://nacholoz3d.cl/libro/<external_id>`), dos vistas (tarjetas / compacta). |
| Biblioteca | Pestaña propia con filtros por estado, contadores y acceso al cronómetro y a las estadísticas por libro. |
| Perfil | Reto anual, estadísticas acumuladas, privacidad (perfil y estadísticas), 4 temas, vista del feed. Perfiles públicos de otros usuarios respetando candados. |

### Repositorios y entornos

| Pieza | Dónde | Notas |
|---|---|---|
| App Flutter | este repo (`test_lectorapp`, rama `main`) | El paquete Dart se sigue llamando `test_lectorapp`. |
| API | repo hermano `../Lectorapp API` (Node.js + Express 5 + MySQL) | **Único lugar donde se modifica el backend.** |
| Espejo de la API | `backend/` en este repo | **Solo lectura.** Copia del repo de la API en el commit `4298c53` (= API 1.1.0). El repo de la API puede ir por delante. |
| Producción | `https://api.nacholoz3d.cl/api` | Servidor Docker; ver §9. |
| Web pública | `https://nacholoz3d.cl/libro/<external_id>` | Front web antiguo (`lectorFront`, Ionic); destino de los enlaces compartidos. No está en este repo. |

> **⚠️ `backend/` no es la carpeta de desarrollo de la API** (lo dice `backend/Intrucciones.txt`).
> Sirve para leer controladores, validadores y SQL sin salir del repo. Cualquier cambio real va en
> `../Lectorapp API` y después se re-sincroniza el espejo (§9).

### Historia resumida (hasta 1.1.0)

1. Proyecto inicial full-stack (UI Flutter + API Node) y snapshot con íconos/splash.
2. **Robustez:** `ApiClient` único, logout real, booleanos tolerantes, URL de la API por `--dart-define`, HTTP solo en debug.
3. **Rendimiento:** feed por cursor, conteo liviano de novedades, arranque en paralelo.
4. **Seguridad Android:** R8, backup desactivado, solo HTTPS, servicio del cronómetro no exportado; lints estrictos.
5. **Plataforma:** ícono adaptativo con capa monocroma, splash claro/oscuro, 90/120 Hz fiable, cambio de ID a `com.nacholoz3d.lectorapp`, vista previa en Chrome.
6. **Diseño y accesibilidad:** tokens de color de dos tonos (pastel + ink) con contraste verificado por tests, formulario único de lectura con borrador, feed/perfil accesibles, estados vacíos y de error, nueva navegación (Inicio · Biblioteca · Perfil).
7. **Cuenta:** recuperación de contraseña por email y refresh tokens rotativos → **release 1.0.0** (2026-11-08, ver `CHANGELOG.md`).
8. **Cuenta y privacidad:** términos y privacidad publicados en la web nueva, aceptación obligatoria, desactivar/reactivar, eliminar la cuenta (app y web) y tope por cuenta en los códigos por correo → **release 1.1.0** (2026-11-22).

---

## 2. Stack y dependencias (`pubspec.yaml`)

- **Dart SDK** `^3.0.0`, Material 3 (`useMaterial3: true`). Versión de la app: `1.1.0+2`.
- **Linter:** `flutter_lints ^4.0.0` + reglas extra en `analysis_options.yaml`
  (`use_build_context_synchronously`, `unawaited_futures`, `cancel_subscriptions`, `close_sinks`,
  `prefer_const_constructors`, `prefer_const_declarations`, `always_declare_return_types`,
  `avoid_catching_errors`, `unnecessary_null_checks`, `unrelated_type_equality_checks`).
  **`flutter analyze` debe quedar en "No issues found!".**
- **Android:** Kotlin Gradle Plugin `2.2.20`, AGP `8.9.1`, Gradle `8.11.1`, Java 11 con *core library desugaring*.

| Librería | Versión | Uso |
|:--|:--|:--|
| `http` | `^1.1.0` | REST, siempre a través de `ApiClient` (un `http.Client` reutilizado, keep-alive). |
| `flutter_secure_storage` | `^10.3.1` | Sesión cifrada: `auth-token` (JWT) y `refresh-token`. |
| `shared_preferences` | `^2.2.2` | Datos no sensibles (ver tabla de claves en §4.6). |
| `cached_network_image` | `^3.3.1` | Portadas y avatares con caché en disco y `precacheImage`. |
| `flutter_background_service` | `^5.0.1` | Cronómetro en un isolate aparte (servicio en primer plano). |
| `flutter_local_notifications` | `^17.1.2` | Canal `reading_timer_channel` y permiso de notificaciones. |
| `google_fonts` | `^6.2.1` | **Lora** (títulos) y **Nunito** (cuerpo). |
| `intl` | `^0.19.0` | Fechas en español (`initializeDateFormatting('es')`). |
| `share_plus` | `^10.1.2` | Compartir enlaces de libros. |
| `url_launcher` | `^6.3.3` | Abrir los Términos y la Política de privacidad (Custom Tabs o navegador; `<queries>` https en el manifest). |
| `flutter_displaymode` | `^0.6.0` | Pedir el modo de mayor refresco en Android. |
| `cupertino_icons` | `^1.0.2` | Íconos (dependencia de plantilla). |

Dev: `flutter_test`, `flutter_launcher_icons ^0.14.4` (≥ 0.14 por la capa `monochrome`),
`flutter_native_splash ^2.3.1`.

**La carpeta `assets/` no se empaqueta en la app** (no hay sección `assets:` en `pubspec.yaml`): solo
contiene las imágenes fuente de íconos y splash (`assets/icon/*`). Si la UI necesita una imagen,
declararla individualmente.

---

## 3. Estructura de directorios

```text
test_lectorapp/
├── CLAUDE.md · README.md · CHANGELOG.md
├── BACKLOG.md                        # Trabajo planificado posterior a 1.1.0
├── PENDIENTES.md                     # Tareas no bloqueantes (firma de release, iOS, deuda técnica)
├── analysis_options.yaml             # Lints del proyecto
├── docs/guia-autenticacion.md        # Receta reutilizable: refresh tokens + recuperación (API y Flutter)
├── .claude/
│   ├── agents/                       # desarrollador.md, revisor.md (flujo de §11)
│   └── skills/                       # lectorapp-design-system, -accessibility, -ux-patterns, -ui-review
├── android/app/
│   ├── build.gradle.kts              # ID com.nacholoz3d.lectorapp; release con R8; FIRMA PENDIENTE (claves debug)
│   ├── proguard-rules.pro            # Keeps: flutter_local_notifications (Gson) y background_service
│   └── src/
│       ├── main/AndroidManifest.xml  # allowBackup=false, cleartext=false, servicio dataSync no exportado
│       ├── main/res/xml/data_extraction_rules.xml
│       └── debug/                    # SOLO debug: HTTP permitido hacia 10.0.2.2 y localhost
├── ios/                              # Plantilla sin configurar (bundle ID com.example.helloWorld)
├── web/                              # Solo para vista previa de diseño en Chrome
├── assets/icon/                      # Fuentes de ícono/splash (no se empaquetan)
├── backend/                          # [SOLO LECTURA] espejo de la API (ver §8)
├── lib/
│   ├── main.dart                     # Inits en paralelo, decisión de sesión, MaterialApp con tema reactivo
│   ├── config.dart                   # Config.baseUrl (--dart-define API_BASE_URL), navigatorKey, termsUrl/privacyUrl
│   ├── book_cover.dart               # BookCover: portada con sombra, caché y placeholder con el título
│   ├── theme/lector_colors.dart      # ThemeExtension LectorColors → context.lector
│   ├── models/
│   │   ├── reading_log.dart          # ReadingLog.fromJson, safeAvatarUrl, toLogPayload
│   │   ├── user_profile.dart         # UserProfile.fromJson (incluye library: List<ReadingLog>)
│   │   ├── reading_log_draft.dart    # ReadingLogDraft (estado del formulario) + ReadingLogDraftStore
│   │   └── book.dart                 # Book — definido pero SIN USO
│   ├── services/
│   │   ├── api_client.dart           # Singleton HTTP: sesión, refresh automático, errores → ApiException
│   │   ├── auth_service.dart         # login / register / forgot / reset / logout / isJwtValid
│   │   ├── terms_service.dart        # Estado de aceptación de términos (user-data) y POST /account/terms
│   │   ├── account_service.dart      # Estado de la cuenta (isDeactivated), /account/status, desactivar, reactivar, eliminar
│   │   ├── reading_service.dart      # Feed, caché, CRUD de lecturas, likes, sesiones, stats; libraryChanges
│   │   ├── user_service.dart         # Perfil, biblioteca de un usuario, stats, meta, privacidad
│   │   ├── book_service.dart         # Búsqueda y reseñas por libro (NO es singleton)
│   │   ├── theme_service.dart        # 4 paletas, _buildTheme, ValueNotifier<ThemeData>, titleStyle, radios
│   │   ├── preferences_service.dart  # FeedLayout (cards/compact) en ValueNotifier
│   │   ├── display_mode_service.dart # 90/120 Hz tras el primer frame y en cada onResume
│   │   └── timer_background_service.dart # onStart (isolate) + fachada estática TimerBackgroundService
│   ├── ui/feedback.dart              # showSuccess / showError / friendlyError / unawaitedHaptic
│   ├── ui/account_copy.dart          # Textos de desactivar/reactivar (singular, plural y 0) y aviso de cuenta eliminada
│   ├── utils/json_utils.dart         # asBool / asInt
│   ├── screens/
│   │   ├── login_screen.dart · register_screen.dart · forgot_password_screen.dart
│   │   ├── tabs_screen.dart          # IndexedStack + BottomNavigationBar; TabsScreen.select(context, i); DeactivatedScreen si la cuenta está desactivada
│   │   ├── deactivated_screen.dart   # Modo solo lectura: biblioteca + aviso, "Reactivar mi cuenta", "Cerrar sesión", "Eliminar mi cuenta"
│   │   ├── deactivate_account_screen.dart # Perfil → ⚙ → Cuenta → Desactivar (explicación, contraseña, confirmación)
│   │   ├── delete_account_screen.dart # Perfil → ⚙ → Cuenta → Eliminar (qué se borra, alternativa desactivar, contraseña, confirmación)
│   │   ├── home_screen.dart          # Tab 0: saludo plegable, barra de búsqueda, "Sigues leyendo", feed
│   │   ├── library_screen.dart       # Tab 1: Mi biblioteca (filtros, contadores, cronómetro); readOnly para la cuenta desactivada
│   │   ├── profile_screen.dart       # Tab 2: reto anual, estadísticas, ajustes (⚙)
│   │   ├── search_screen.dart        # Pantalla apilada; función global openSearch(context)
│   │   ├── book_detail_screen.dart   # Detalle con fondo blur + reseñas + FAB "Añadir a mi biblioteca"
│   │   └── public_profile_screen.dart# Perfil ajeno: Biblioteca / Estadísticas, candados de privacidad
│   └── widgets/
│       ├── reading_log_sheet.dart    # ÚNICO formulario de lectura (añadir y editar)
│       ├── terms_acceptance.dart     # Enlaces legales, casilla del registro, hoja "Antes de compartir…"
│       ├── log_book_modal.dart · edit_book_modal.dart   # Envoltorios finos de ReadingLogSheet
│       ├── user_card.dart            # Lectura en el feed (cards/compact) o reseña ('review')
│       ├── library_book_tile.dart    # Fila de Mi biblioteca (editar / estadísticas)
│       ├── reading_timer_modal.dart  # UI del cronómetro
│       ├── book_stats_modal.dart     # Métricas de un libro
│       ├── status_chip.dart          # StatusChip, statusLabel, statusIcon
│       ├── star_rating_input.dart    # Estrellas 0–5 accesibles
│       ├── state_views.dart          # EmptyState / ErrorState
│       └── book_loader.dart          # Loader animado (páginas de un libro)
└── test/                             # 8 archivos, 105 tests (ver §10)
```

`.vscode/` (configuraciones de ejecución y la tarea `adb reverse`) **está en `.gitignore`**: existe en
la máquina del autor pero no en un clon limpio. Los comandos equivalentes están en §9.

---

## 4. Arquitectura de la app

### 4.1 Capas

```text
screens/ + widgets/   StatefulWidget con setState. Sin Bloc/Riverpod/Provider.
        │  llaman a
services/             Singletons sin estado de UI. Devuelven Map/List crudos de la API.
        │  usan
ApiClient             Único punto de salida HTTP. Sesión, renovación, errores.
        │
API REST (Config.baseUrl)
```

- **Estado:** local a cada pantalla. Lo compartido entre pantallas se expone como `ValueNotifier` en un singleton:
  - `ThemeService().currentTheme` → escuchado en la raíz (`LectorApp`) con `ValueListenableBuilder`.
  - `PreferencesService().feedLayout` → escuchado por `HomeScreen`.
  - `ReadingService().libraryChanges` (contador) → se incrementa en `createLog`, `updateLog`, `deleteLog` y `recordSession`; lo escuchan `HomeScreen` (tarjeta "Sigues leyendo"), `LibraryScreen` y `ProfileScreen` para recargar en silencio.
  - `AccountService().isDeactivated` (`bool`) → escuchado por `TabsScreen`: con la cuenta desactivada muestra `DeactivatedScreen` en lugar de las pestañas (ver §4.5 *Cuenta desactivada*).
- **Datos:** casi toda la UI trabaja con `Map<String, dynamic>` crudos (feed, `UserCard`, búsqueda, detalle, modales). Los modelos tipados se usan en `LibraryScreen`, `LibraryBookTile`, `ProfileScreen` y `PublicProfileScreen` (`ReadingLog`, `UserProfile`). Cuando un widget tipado abre un modal, reconstruye un `Map` (`LibraryBookTile._logMap`).
- **Imports:** conviven relativos (`../services/...`) y de paquete (`package:test_lectorapp/...`). En código nuevo, relativos.

### 4.2 Arranque (`main.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()`.
2. `Future.wait` de inits independientes: `TimerBackgroundService.initializeService()`, `initializeDateFormatting('es')`, `ThemeService().loadTheme()`, `PreferencesService().load()`, `ApiClient().loadToken()`, `AccountService().load()` (estado de la cuenta guardado en `user-data`, para abrir directo en modo solo lectura).
3. **Decisión de sesión sin red:** hay sesión si el JWT sigue vigente (`AuthService.isJwtValid`) **o** existe refresh token. Un token viejo vencido y sin refresh se limpia (`clearSession`).
4. `runApp(LectorApp(initialScreen: TabsScreen | LoginScreen))`.
5. `DisplayModeService.init()` (después de `runApp`: en `main()` la ventana aún no existe).

### 4.3 Navegación

- `MaterialApp` con `home:` y `Navigator.push(MaterialPageRoute(...))`. **No hay rutas con nombre ni router.**
- `TabsScreen`: `IndexedStack` con `HomeScreen`, `LibraryScreen`, `ProfileScreen` (todas con `AutomaticKeepAliveClientMixin`, conservan scroll y datos). `TabsScreen.select(context, TabsScreen.profile)` cambia de pestaña desde un hijo.
- La búsqueda no es pestaña: `openSearch(context)` (definida en `search_screen.dart`) apila `SearchScreen`.
- Formularios y paneles son `showModalBottomSheet(isScrollControlled: true, backgroundColor: Colors.transparent)`.
- `Config.navigatorKey` permite a `ApiClient` navegar a `LoginScreen` (limpiando el stack) cuando la sesión termina de verdad, y a `AccountService` cerrar las pantallas apiladas (`popUntil(isFirst)`) al recibir `403 ACCOUNT_DEACTIVATED`.
- Tras login/registro/reset: `pushReplacement` / `pushAndRemoveUntil` a `TabsScreen`.

### 4.4 `ApiClient` y sesión

- **Toda llamada HTTP pasa por `ApiClient()`** (`get/post/put/delete` → `_send` → `_request` → `_parse`), incluidos login y registro. Timeout de 15 s. Cabeceras JSON + `Authorization: Bearer` (salvo en `/auth/refresh`).
- **Sesión:** JWT de acceso (**30 min**) + refresh token opaco (**60 días**, rotativo), ambos en `FlutterSecureStorage` y cacheados en memoria (`loadToken()` al arrancar).
- **Renovación automática:**
  1. Antes de pedir: si el acceso está vencido (`isAccessTokenExpired`, margen de 30 s) y hay refresh, renueva primero.
  2. Ante un `401`: renueva una vez y reintenta la petición. **Excepción:** un `401 INVALID_PASSWORD` ("la contraseña que confirmaste no es correcta", p. ej. al desactivar) no renueva ni manda a Login.
  3. Peticiones simultáneas comparten **una** renovación (`_refreshing`).
  4. Refresh rechazado (`401`/`400`) → `clearSession()` + Login (flag `_isRedirectingToLogin` evita apilar varias pantallas) + `ApiException(401)`.
  5. Fallo de red o `5xx`/`429` al renovar → **la sesión se conserva**; sube la `ApiException`.
- **`redirectOn401: false`** (solo existe en `post`) marca la petición como no autenticada: no intenta renovar ni redirige. Se usa en login, registro, logout, forgot y reset, donde un 401 significa "credenciales inválidas".
- **Errores:** todo falla como `ApiException(message, statusCode, code)` (`code` = el `code` del JSON de error, p. ej. `TERMS_REQUIRED`; `isTermsRequired`, `isAccountDeactivated` e `isInvalidPassword` lo comprueban).
  - **Red de seguridad:** cualquier `403 ACCOUNT_DEACTIVATED` llama a `AccountService().onDeactivatedResponse()` (pasa a modo solo lectura una sola vez, sin bucles) y luego lanza la excepción como siempre.
  - 4xx/5xx → campo `error` (o `message`) del JSON.
  - Cuerpo no JSON (HTML de Nginx en un 502) → mensaje genérico, nunca `FormatException`.
  - `TimeoutException` / `SocketException` / `ClientException` → mensaje amigable, `statusCode: 0`.
- **`clearSession()`** borra ambos tokens, `user-data` y `cached_global_feed`. **No** toca `AccountService().isDeactivated`: si lo pusiera en `false`, `TabsScreen` volvería a crear las pestañas antes de llegar a Login y lanzaría peticiones sin token; el estado se fija en el siguiente login/registro/reset.
- **Logs:** solo en `kDebugMode`, método + URL + status. Nunca bodies (pueden llevar contraseñas).
- Hay dos lectores de `exp` con propósitos distintos: `AuthService.isJwtValid` (arranque, sin margen) y `ApiClient.isAccessTokenExpired` (margen de 30 s). Ninguno valida la firma: eso lo hace la API.
- **Tests:** `ApiClient().httpClientForTesting = MockClient(...)` (ver `test/api_client_refresh_test.dart`).

`AuthService`: `login(identifier, password)` envía `email` si contiene `@`, si no `username`.
`_saveSession` guarda tokens y en `user-data` **solo** `id`, `username`, `avatar`, `status` (sin el
campo → `active`) y los campos de términos (`terms_version`, `current_terms_version`, `needs_terms`);
el email no se persiste sin cifrar. Luego `AccountService().load()` aplica el estado.
`register(..., acceptedTerms:)` envía `accept_terms`. `logout()` llama a `POST /auth/logout` con el refresh token (si falla la red,
igual cierra la sesión local).

### 4.5 Flujos principales

**Feed (`HomeScreen`)**
- *Offline-first:* muestra `cached_global_feed` tras pre-decodificar portadas/avatares de los 5 primeros ítems (`_precacheVisibleCovers`, timeout 3 s); luego consulta el conteo de novedades. Sin caché → `loadFeed()`.
- *Cursor:* `GET /readings/feed?limit=10&before_id=<id del último>`. **No usar `page`/OFFSET en el feed** (duplicaba o saltaba publicaciones).
- *Banner de novedades:* `GET /readings/feed/new-count?after_id=<id del primero>` → `{count}`; tocarlo sube al inicio y recarga.
- *Like optimista:* invierte al instante y confirma/revierte con la respuesta. La publicación se localiza **por `id`**, no por índice (el feed puede recargarse durante la petición).
- *Errores:* si ya hay contenido se conserva y se avisa con SnackBar + "Reintentar"; solo sin contenido se muestra `ErrorState`.
- *Cabecera:* `SliverAppBar` con saludo según la hora que se pliega a "LectorApp" + avatar (→ pestaña Perfil); barra "¿Qué estás leyendo?" (→ `openSearch`); tarjeta **"Sigues leyendo"** = primera lectura `leyendo` de `my-library?page=1&limit=50` (→ `EditBookModal`).
- *Vistas:* `UserCard(layout: FeedLayout.cards | compact)`.

**Formulario de lectura (`ReadingLogSheet`)** — el único formulario para añadir y editar.
- `LogBookModal(book)` → devuelve `{'saved': true}`; `EditBookModal(readingLog)` → `{'action': 'updated' | 'deleted'}`.
- **Borrador automático:** cada cambio programa un guardado a 800 ms en `SharedPreferences` (`reading_draft_log_<id>` al editar, `reading_draft_book_<external_id>` al añadir). Al abrir, si hay borrador distinto del estado inicial, se restaura con un aviso y opción "Descartar". Se borra al guardar, al eliminar o al descartar.
- `PopScope` bloquea el cierre con cambios sin guardar ("¿Descartar los cambios?"). Si el guardado falla, la hoja queda abierta con todo lo escrito.
- Reglas: al añadir, por defecto `leyendo`, inicio hoy, **privado**. Página actual solo en `leyendo`; estrellas solo fuera de `leyendo`; `finish_date` solo en `terminado` (al elegirlo propone hoy y completa la página con `page_count`). Validación local: página ≤ `page_count`, término ≥ inicio, reseña ≤ 5000.
- Payload: `logData = {status, rating|null, review_text, start_date, finish_date, is_log_public, current_page}`; al crear, `{bookData: {external_id, title, authors, cover_url, isbn, page_count, published_year}, logData}`.
- **Términos antes de publicar (1.3):** si la lectura quedará pública y `TermsService().needsAcceptance()` es `true`, se muestra `showTermsSheet` ("Antes de compartir…": *Aceptar y publicar* → `POST /account/terms`; *Guardar solo para mí* → pasa a privada y guarda; *Ahora no* → no guarda y la hoja sigue abierta). Si el dato local es desconocido o viejo, un `403 TERMS_REQUIRED` abre la misma hoja y, si acepta, reintenta el guardado **una** vez.

**Términos (`TermsService`)** — el estado de aceptación llega en el `user` de login/registro/reset y en el perfil propio (`ProfileScreen` lo guarda tras cargarlo, así las sesiones de la 1.0.0 también lo conocen). Es solo una pista: la API decide. Registro: casilla `TermsCheckbox` obligatoria (sin marcar por defecto). Perfil → ⚙ → *Legal* abre ambos documentos con `openLegalDocument`.

**Cuenta (2.1, `AccountService`)** — Perfil → ⚙ → *Cuenta* (hoja con "Desactivar mi cuenta" y "Eliminar mi cuenta") → `DeactivateAccountScreen`: pide `GET /account/status` para decir *antes* cuántas lecturas públicas pasarán a privadas, contraseña (`401 INVALID_PASSWORD` se muestra junto al campo, sin cerrar la sesión) y diálogo de confirmación → `POST /account/deactivate` → `isDeactivated = true`, vuelve a la raíz con un aviso.

**Cuenta desactivada (modo solo lectura)** — `TabsScreen` muestra `DeactivatedScreen` = `LibraryScreen(readOnly: true)` con un `AppBar` fijo "Cuenta desactivada" + botón **Reactivar** (sin añadir, editar, buscar ni cronómetro; las estadísticas de cada libro sí, la API las permite) + aviso fijo arriba "Tu cuenta está desactivada" con **Reactivar mi cuenta** y **Cerrar sesión**. Al abrirse consulta `GET /account/status` (si se reactivó en otro teléfono, vuelve sola a las pestañas). Reactivar: `GET /account/status` → diálogo con "Tus N lecturas que eran públicas volverán a ser públicas" → `POST /account/reactivate` → aviso "Volvieron a ser públicas N lecturas" y vuelven las 3 pestañas (se crean de nuevo y recargan sus datos). Se entra en este modo al arrancar (`user-data`), al iniciar sesión (`user.status`), tras desactivar o por la red de seguridad del `403 ACCOUNT_DEACTIVATED`. Solo llama a endpoints permitidos, así que no puede provocar otro 403. El aviso ofrece además **Eliminar mi cuenta** (discreto, en `textSecondary`).

**Eliminar la cuenta (2.2)** — Perfil → ⚙ → *Cuenta* → **Eliminar mi cuenta** (o desde el modo solo lectura) → `DeleteAccountScreen`: explica qué se borra (lecturas, reseñas, sesiones, reto, "me gusta" dados y recibidos, perfil y sesiones; los libros del catálogo no), y si la cuenta está activa ofrece "¿Solo quieres un descanso?" → `DeactivateAccountScreen` (reemplaza la pantalla). Contraseña + diálogo "¿Eliminar tu cuenta para siempre?" (botón "Eliminar para siempre" en `danger`) → `AccountService().deleteAccount(password)` = `DELETE /account` → `clearLocalDataAfterDeletion()` (= `clearSession()` + `ReadingLogDraftStore.clearAll()`; se conservan `app_theme` y `feed_layout`, que son del teléfono) → `pushAndRemoveUntil(LoginScreen)` con el aviso "Tu cuenta y tus datos se eliminaron…". `401 INVALID_PASSWORD` → error junto al campo, sesión y teléfono intactos. El botón principal es `FilledButton` con fondo `danger` y texto `onInk` (contraste en `theme_contrast_test`).

**Biblioteca (`LibraryScreen`)** — carga la biblioteca **completa** (`my-library` en páginas de 50, tope de 20 páginas) para que filtros y contadores sean exactos en cliente. Filtros `leyendo` / `terminado` / `abandonado` con `SegmentedButton`; si no hay nada "leyendo" abre en el primer filtro con libros. Tarjeta "Empezar a leer" → `ReadingTimerModal`.

**Perfiles** — `GET /users/:username` ya trae la primera página de `library`. `ProfileScreen` (propio) la usa para el reto y las estadísticas (`/users/:username/stats`); `PublicProfileScreen` pagina el resto con `/users/:username/library?page=N` y solo pide stats si el perfil es público.

**Búsqueda (`SearchScreen`)** — debounce de 300 ms, mínimo 3 caracteres; cada resultado abre `BookDetailScreen` o, con el botón `+`, `LogBookModal`.

**Compartir** — `UserCard._share()` comparte `https://nacholoz3d.cl/libro/<external_id>`.

### 4.6 Almacenamiento local

| Dónde | Clave | Contenido |
|---|---|---|
| SecureStorage | `auth-token` | JWT de acceso |
| SecureStorage | `refresh-token` | Refresh token opaco |
| SharedPreferences | `user-data` | JSON `{id, username, avatar, status, terms_version?, current_terms_version?, needs_terms?}` (`status`: `active` o `deactivated`) |
| SharedPreferences | `cached_global_feed` | Primera página del feed (JSON) |
| SharedPreferences | `app_theme` | `light` \| `pink` \| `blue` \| `dark` |
| SharedPreferences | `feed_layout` | `cards` \| `compact` |
| SharedPreferences | `reading_draft_<id>` | Borrador de formulario (uno por libro o registro) |

No hay base de datos local. Los borradores y preferencias **no** se borran al cerrar sesión. Al **eliminar la cuenta** (2.2) se borran sesión, `user-data`, `cached_global_feed` y todos los `reading_draft_*`; `app_theme` y `feed_layout` se conservan (son del teléfono, no de la cuenta).

### 4.7 Cronómetro en segundo plano

- `onStart(ServiceInstance)` (`@pragma('vm:entry-point')`) corre en **otro isolate**: no puede usar el estado de la app ni plugins de UI. Toda comunicación es por mensajes:
  - UI → servicio: `startTimer {bookTitle, selectedLog, seconds}`, `pauseTimer`, `resumeTimer`, `stopTimer`, `stopService`.
  - Servicio → UI: `ready` (una vez, listeners registrados) y `update {seconds, isRunning, isFinished, selectedLog}` cada segundo mientras corre y tras cada comando.
- `TimerBackgroundService.start()` se suscribe a `ready` **antes** de `startService()` y espera como máximo 3 s. No usar esperas fijas.
- El tiempo se calcula con `DateTime.now().difference(startTime)` + `accumulatedSeconds` (no cuenta ticks: el SO puede suspender el hilo).
- Android: servicio en primer plano tipo `dataSync`, notificación id `888`, canal `reading_timer_channel` (importancia baja, sin sonido). `autoStart: false`. El permiso de notificaciones se pide al abrir `ReadingTimerModal`.
- `TimerBackgroundService.isSupported` es `false` en web/escritorio: el modal se dibuja pero no cuenta.
- `ReadingTimerModal`: al finalizar pide "páginas leídas" y "página actual" → `POST /readings/:id/session` con `duration_minutes = max(1, round(seg/60))` → `stopService()`. Solo reescribe el campo "página actual" cuando cambia el libro seleccionado, no en cada `update`.
- El estado vive solo en la memoria del isolate: el modal se sincroniza con el siguiente `update`, así que un cronómetro **en pausa** no se refleja si el modal se cierra y se vuelve a abrir.

### 4.8 Plataforma Android

- **ID: `com.nacholoz3d.lectorapp`** (antes `com.nacholoz3d.test_lectorapp`). Se cambió porque HyperOS (Xiaomi, *Joyose*/*PowerKeeper*) tenía el ID viejo marcado como "juego" y forzaba 60 Hz. **No cambiarlo una vez publicado en Google Play.**
- **Refresco:** `DisplayModeService` elige el modo de mayor Hz a la resolución actual (`pickBestMode`, testeado) tras el primer frame y en cada `onResume`.
  Diagnóstico: `adb shell dumpsys SurfaceFlinger | grep displayManagerPolicy` y `adb shell dumpsys activity service com.xiaomi.joyose | grep IsGameForeground`.
- **Manifest:** `allowBackup=false`, `usesCleartextTraffic=false`, `dataExtractionRules`; el servicio del plugin se redeclara con `exported=false` (`tools:replace`). Permisos: `INTERNET`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `POST_NOTIFICATIONS`, `WAKE_LOCK`.
- **Debug:** `src/debug/res/xml/network_security_config.xml` permite HTTP solo hacia `10.0.2.2` y `localhost`.
- **Release:** R8 (`isMinifyEnabled` + `isShrinkResources`) con `proguard-rules.pro`. **La firma de release sigue usando las claves de debug** (pendiente antes de Google Play).
- **Íconos/splash:** generados desde `assets/icon/` (todas con fondo transparente salvo `icon_legacy.png`). Regenerar desde una imagen opaca rompe el ícono temático y el splash.
- **iOS** no está configurado (bundle ID de plantilla) y **web** solo sirve como vista previa de diseño.

---

## 5. Datos y quirks de la API

1. **Lectura tolerante:** usar `asBool(...)` / `asInt(...)` (`lib/utils/json_utils.dart`) al leer booleanos o enteros de un `Map`. MySQL guarda booleanos como `1`/`0`; la API actual normaliza a `true`/`false`, pero la caché local o respuestas antiguas pueden traer enteros o strings.
2. **Nombres de campo que varían** (la tabla `books` usa `author`; la búsqueda devuelve `authors`):
   - Autor: `json['authors'] ?? json['author']`
   - Portada: `json['cover_url'] ?? json['cover_image']`
   - ID externo: `json['external_id'] ?? json['google_id']` (y `?? json['id']` solo para libros de búsqueda/detalle)
3. **Avatares DiceBear:** la API genera URLs `/svg`; `CachedNetworkImageProvider` no rasteriza SVG → reemplazar siempre `/svg` por `/png` (`safeAvatarUrl` en los modelos; a mano en `UserCard` y `HomeScreen`). Respaldo: `https://api.dicebear.com/7.x/bottts/png?seed=<username>`.
4. **`id` del feed** = id del `reading_log` (es el cursor y el destino del like).
5. **Fechas:** se envían `YYYY-MM-DD`; se reciben como ISO y se parsean con `DateTime.tryParse`.
6. **Etiquetas de estado:** el valor de API no cambia (`abandonado`); en pantalla es "Lo dejé" (`statusLabel`).

---

## 6. Contrato de la API (v1.1.0)

Base: `Config.baseUrl` (`https://api.nacholoz3d.cl/api`). Todo requiere `Authorization: Bearer <JWT>`
**salvo** `/auth/*`, `/books/feed`, `/account/deletion-request`, `/account/deletion-confirm` y `/health`. Body JSON máx. 100 kb.

### Errores

Siempre `{ "error": string, "code": string }`:

| HTTP | `code` | Cuándo |
|---|---|---|
| 400 | `VALIDATION_ERROR`, `INVALID_JSON` | No cumple el esquema Zod / JSON mal formado |
| 401 | `UNAUTHORIZED` | Sin token, token inválido/expirado/revocado, credenciales inválidas |
| 401 | `INVALID_PASSWORD` | La contraseña con la que se confirma una acción de la cuenta (desactivar) no es correcta. **No** es una sesión vencida |
| 403 | `FORBIDDEN` | Recurso ajeno o privado |
| 403 | `TERMS_REQUIRED` | Crear o dejar pública una lectura sin haber aceptado la versión vigente de los términos |
| 403 | `ACCOUNT_DEACTIVATED` | La cuenta está desactivada y el endpoint no está entre los permitidos (ver *Cuenta*) |
| 404 | `NOT_FOUND` | Recurso o ruta inexistente |
| 409 | `CONFLICT` | Email/username ya registrado; libro ya registrado por el usuario; desactivar una cuenta ya desactivada o reactivar una activa |
| 413 | `PAYLOAD_TOO_LARGE` | Body mayor a 100 kb |
| 429 | `RATE_LIMITED` | Límite de peticiones |
| 500 | `INTERNAL_ERROR` | Error no controlado (el detalle solo va al log) |

### Límites de peticiones (por IP)

General 300 / 15 min. Login: 10 intentos **fallidos** / 5 min. Registro: 10 / hora. Forgot: 5 / hora.
Reset: 10 / 15 min. Refresh: 60 / 15 min. Búsqueda: 30 / min. Desactivar: 5 contraseñas **incorrectas** / 15 min (por cuenta).
Eliminar desde la web: pedir código 5 / hora, confirmar 10 / 15 min.
**Por cuenta, en 24 h** (códigos por correo: recuperación y eliminación, cada uno por separado): máx. 5 códigos emitidos y 10 intentos fallidos en total; al llegar no se envían más códigos ni se acepta ninguno, con las mismas respuestas públicas (200 / 400 genérico).

### Validación relevante para la UI

- **Registro:** `username` `^[a-zA-Z0-9_.-]{3,30}$`; `email` válido (se guarda en minúsculas); `password` ≥ 8 caracteres y ≤ 72 bytes; `accept_terms` debe ser exactamente `true`.
- **Lecturas:** `status` ∈ `leyendo|terminado|abandonado`; `rating` entero 1–5 o `null` (0 ≡ `null`); `review_text` ≤ 5000; fechas `YYYY-MM-DD` con `finish_date >= start_date`; `cover_url` solo `https` de `covers.openlibrary.org` o Google Books.
- **Sesiones:** `duration_minutes` 1–1440; `pages_read` 0–5000.
- **Paginación:** `limit` ≤ 50.

### Endpoints

**Auth (`/auth`)**
- `POST /login` — `{ email | username, password }` → `{ token, refresh_token, user }`.
- `POST /register` — `{ username, email, password, accept_terms: true }` → `201 { token, refresh_token, user }`. Guarda la versión vigente y la fecha.
- En login, registro y reset, `user` incluye `terms_version` (aceptada o `null`), `current_terms_version`, `needs_terms` y `status` (`active` | `deactivated`). Una cuenta desactivada **sí** puede iniciar sesión, renovar y cerrar sesión.
- `POST /refresh` — `{ refresh_token }` → `{ token, refresh_token }`. **Rota**: el usado queda revocado; reusar uno ya rotado revoca toda la familia → 401.
- `POST /logout` — header `Authorization` (acceso vigente → blacklist por hash) y/o `{ refresh_token }` (revoca su familia). Al menos uno válido, si no 401.
- `POST /forgot-password` — `{ email }` → siempre `200 { message }` (no revela si la cuenta existe). Código de 6 dígitos, vence en 15 min, 1 por minuto por cuenta.
- `POST /reset-password` — `{ email, code, password }` → `{ token, refresh_token, user }`. Máx. 5 intentos por código y 10 fallidos por cuenta en 24 h; cierra todas las sesiones anteriores. Código inválido/vencido → 400.

**Cuenta (`/account`)**
- `POST /terms` — sin body; acepta la versión vigente (`CURRENT_TERMS_VERSION` de la API, hoy `2026-11`) → `{ terms_version, current_terms_version, needs_terms: false, terms_accepted_at }`. Idempotente (conserva la fecha de la primera aceptación).
- `GET /status` — `{ status, status_changed_at, public_readings, restorable_readings }`: lecturas públicas ahora / las que volverán a ser públicas al reactivar (sin las bloqueadas por moderación).
- `POST /deactivate` — `{ password }` → `{ status: 'deactivated', hidden_readings }`. En una transacción guarda la visibilidad de **cada** lectura (`public_before_deactivation`) y las deja todas privadas. Contraseña incorrecta → `401 INVALID_PASSWORD` (nada cambia). Ya desactivada → `409` (no pisa la visibilidad guardada).
- `POST /reactivate` — sin body ni contraseña → `{ status: 'active', restored_readings }`. Cada lectura vuelve a su visibilidad anterior salvo las que tengan `moderation_locked_at` (siguen privadas). No exige los términos vigentes (restaura, no publica). Ya activa → `409`.
- `DELETE /` — `{ password }` → `200 { deleted: true }` (200 con cuerpo, no 204: el cliente confirma el borrado). Borra en **una transacción** la cuenta y todo lo suyo: lecturas (con reseñas), "me gusta" dados **y** recibidos, sesiones del cronómetro, metas, refresh tokens y códigos de recuperación; en `admin_actions` las filas se conservan con `admin_id`/`target_id` en `NULL` si apuntaban a la cuenta o a sus lecturas. Los libros no se borran. Funciona con la cuenta activa, desactivada o suspendida. Revoca el token de acceso usado (blacklist); los de otros dispositivos dejan de valer porque el usuario ya no existe (401). Contraseña incorrecta → `401 INVALID_PASSWORD` (nada cambia; comparte con `/deactivate` el límite de 5 fallos por cuenta / 15 min). Dos borrados simultáneos → uno `200`, el otro `401`. Username y email quedan libres. La lógica es `deleteUserCompletely(userId, conn)` (`src/services/accountDeletion.service.js`), reutilizable por la web (2.3); **toda tabla nueva con datos de un usuario se registra ahí**.
- `POST /deletion-request` — **sin sesión** (tarea 2.3, la usa la web `https://lector.nacholoz3d.cl/eliminar-cuenta`; Google Play exige un enlace web) — `{ email }` (normalizado como en el registro) → **siempre** `200 { message }` idéntico, exista o no la cuenta y esté activa, desactivada o suspendida. Si existe, envía un código de 6 dígitos (HMAC en `deletion_requests`, 15 min, 1 por minuto por cuenta, pedir otro invalida el anterior); el correo sale en segundo plano. Sin enlaces en el correo, solo el código.
- `POST /deletion-confirm` — **sin sesión** — `{ email, code }` → `200 { deleted: true }` con el mismo borrado que `DELETE /account` (en una transacción, también para cuentas suspendidas), o `400 VALIDATION_ERROR` genérico ("El código no es válido o ya venció. Pide uno nuevo.") para cuenta inexistente, código incorrecto, vencido, ya usado o tras 5 intentos fallidos. Los códigos de recuperación de contraseña no sirven aquí ni al revés. La app no usa estos endpoints.
- **Con la cuenta desactivada** solo responden: `GET /readings/my-library`, `GET /readings/:id/stats` (solo de **sus** lecturas), `GET /account/status`, `POST /account/reactivate`, `POST /account/deactivate` (→ 409), `DELETE /account` y `/auth/*`. Todo lo demás → `403 ACCOUNT_DEACTIVATED`. Para los demás usuarios su perfil, biblioteca y stats responden `404` (igual que un usuario inexistente), no aparece en el feed ni en `/books/feed`, y sus "me gusta" dejan de contar en `likes_count` y `total_likes` (no se borran; vuelven al reactivar).

**Libros (`/books`)**
- `GET /search?q=` — caché MySQL + Open Library (cacheado 10 min en el servidor) → `{ data: [...] }`.
- `GET /feed?external_id=` — reseñas públicas de un libro (**sin auth**, máx. 100).

**Lecturas (`/readings`)**
- `GET /feed?limit=&before_id=` — feed global público por cursor.
- `GET /feed/new-count?after_id=` — `{ count }`.
- `GET /my-library?page=&limit=` — biblioteca del usuario autenticado.
- `POST /` — `{ bookData, logData }` → `201 { logId }`; 409 si el libro ya está registrado; `403 TERMS_REQUIRED` si es pública sin términos aceptados.
- `PUT /:id` — **parcial**: solo los campos enviados (`status`, `rating`, `review_text`, `start_date`, `finish_date`, `is_log_public`, `current_page`). `403 TERMS_REQUIRED` si tras el cambio queda pública sin términos aceptados (incluye editar una que ya lo era); hacerla privada siempre se permite.
- `DELETE /:id`
- `POST /:id/like` — alterna → `{ liked, likes_count }`.
- `POST /:id/session` — `{ duration_minutes, pages_read, current_page? }` (transacción).
- `GET /:id/stats` — `{ total_minutes, total_sessions, avg_session_minutes, log_info }`.

**Usuarios (`/users`)**
- `GET /:username` — `{ username, bio, avatar_url, is_profile_public, are_stats_public, is_own_profile, is_private_lock, library }`; si `is_own_profile`, además `terms_version`, `current_terms_version`, `needs_terms` y `status`. Usuario inexistente **o no activo** → 404 (también en `/library` y `/stats`).
- `GET /:username/library?page=&limit=`
- `GET /:username/stats` — `{ total_minutes, total_pages, finished_books, finished_books_this_year, target_books_this_year, avg_rating, total_likes, year, is_private }` o `{ is_private: true }`. `total_pages` = por lectura, `page_count` si está terminada (y se conoce), si no `current_page`.
- `POST /goal` — `{ target_books: 1..1000 }`.
- `PUT /privacy` — `{ is_profile_public?, are_stats_public? }` (al menos uno; campos extra → 400).

**Salud:** `GET /health` → `{ status: 'OK', db: 'Connected' }` o 503.

---

## 7. Sistema de diseño y UI

> **Skills (`.claude/skills/`)** — usarlas al tocar UI: `lectorapp-design-system` (tokens, tipografía,
> componentes), `lectorapp-accessibility` (TalkBack, 48 dp, texto al 200 %, contraste),
> `lectorapp-ux-patterns` (voz, estados, borradores, privacidad), `lectorapp-ui-review` (auditoría de una pantalla).

1. **Estética acogedora/pastel:** radios grandes (`ThemeService.radiusCard = 20`, `radiusSmall = 12`), sombras suaves teñidas con el color del tema, inputs rellenos sin borde (el foco sí muestra borde `ink`).
2. **Tipografía:** **Lora** para títulos (`ThemeService.titleStyle` o `GoogleFonts.lora(...)`), **Nunito** para el resto (`GoogleFonts.nunitoTextTheme()` en el tema). **Nunca `fontFamily: 'Lora'`**: no aplica (google_fonts registra la fuente con otro nombre).
3. **Dos tonos por tema** (`LectorColors`, accesible con `context.lector`):
   - `accent` = pastel: fondos tintados, chips, decoración. **Nunca como color de texto.**
   - `ink` = tono legible (≥ 4.5:1): texto de marca, íconos activos, fondo de botones. `primaryColor` y `colorScheme.primary` **= ink**.
   - Además: `onInk`, `textPrimary`, `textSecondary`, `iconInactive`, `outline`, `success`, `danger`, `reading`, `star`.

   | Tema (`app_theme`) | accent | ink | fondo |
   |---|---|---|---|
   | `light` — Crema & Salvia (default) | `#8BA89F` | `#4F7A70` | `#FDFBF7` |
   | `pink` — Rosa Peonía | `#D8A7B1` | `#B5536A` | `#FEF9FA` |
   | `blue` — Brisa de Mar | `#A1C4D0` | `#3F7186` | `#F7FBFD` |
   | `dark` — Café de Medianoche | `#B59E86` | `#B59E86` (texto encima `#1C1917`) | `#1C1917`, tarjetas `#292524` |

   Claros: texto `#3D4042`, secundario `#6B6F72`. Oscuro: texto `#E7E5E4`, secundario `#A8A29E`.
   `test/theme_contrast_test.dart` verifica los contrastes de `ThemeService.palettes`: **si cambias un color, corre los tests.**
4. **Estados de lectura:** `context.lector.statusColor(status)` → `terminado` = `success`, `leyendo` = `reading` (= ink), `abandonado` = `danger`. Estrellas = `star`. Mostrar siempre con `StatusChip` (ícono + texto, no solo color).
5. **Colores en código nuevo:** `context.lector.xxx` o `Theme.of(context).colorScheme`. Nada de `Colors.grey/red/...` ni hex sueltos. Opacidad con `.withValues(alpha: x)`, no `.withOpacity`.
6. **Feedback:** `showSuccess(context, msg)` y `showError(context, error, fallback:, onRetry:)` de `lib/ui/feedback.dart`. `friendlyError` nunca muestra `toString()` de excepciones internas. Listas vacías y errores de carga: `EmptyState` / `ErrorState`.
7. **Accesibilidad:** objetivos táctiles ≥ 48 dp, `tooltip` en todo `IconButton`, `Semantics` agrupando tarjetas en frases legibles, encabezados con `header: true`, letra mínima 12.
8. **Voz:** español cercano, tuteo, sin mayúsculas sostenidas ("Guardado en tu biblioteca", "No pudimos cargar esto").

---

## 8. Backend (espejo `backend/`, solo lectura)

Node.js + **Express 5** + **MySQL** (`mysql2`), CommonJS. Capas: `routes → validate (Zod) → controllers → services → models (SQL)`.

```text
backend/src/
├── app.js                 # helmet, CORS, compression, json 100kb, pino-http, rate limit, rutas, 404 y error handler
├── config/                # db.js (pool), env.js (falla al arrancar si falta config o JWT_SECRET < 32)
├── api/routes|controllers|validators|middlewares   # auth, book, reading, user; protect + validate
├── services/              # lógica de negocio
├── models/                # SQL por entidad
└── utils/                 # errors (AppError), tokens, mailer, openLibrary, ttlCache, logger (pino)
backend/scripts/           # migrate.js (idempotente), setup_test_db.js, cleanup_tokens.js, add_indexes.js
backend/tests/             # Jest + supertest (E2E contra la BD anti_social_test)
backend/deploy/            # deploy.bat (plink) + remote-deploy.sh; ver backend/DEPLOY.md
```

- **Tablas:** `users` (incluye `terms_version`, `terms_accepted_at` desde la 1.3; `status` `active|deactivated|suspended` y `status_changed_at` desde la 2.1), `books` (`external_id` único), `reading_logs` (único `user_id + book_id`; `public_before_deactivation` y `moderation_locked_at` desde la 2.1), `reading_likes`, `reading_sessions`, `reading_goals`, `token_blacklist`, `refresh_tokens` (hash SHA-256, `family_id`), `password_resets`.
- **Middleware de sesión:** `authenticate` (JWT válido, no revocado, usuario existente) y `protect` = `authenticate` + `requireActive` (cuenta `active`, si no `403 ACCOUNT_DEACTIVATED`). `protect` es el de por defecto: las pocas rutas permitidas a una cuenta desactivada se montan con `authenticate` **antes** del `router.use(protect)`.
- **Seguridad:** JWT HS256 con `jti` único, blacklist por hash, refresh rotativo con detección de reuso, `users.password_changed_at` invalida sesiones anteriores, bcrypt, respuestas de login/forgot que no revelan qué cuentas existen.
- **CORS:** `https://nacholoz3d.cl`, `https://www.nacholoz3d.cl`, `http://localhost:3000`, `http://localhost:4200` (por eso la vista previa web usa `--web-port=4200`).
- La receta completa de autenticación (API + Flutter) está en `docs/guia-autenticacion.md`.

---

## 9. Comandos

```bash
flutter pub get
flutter analyze            # debe quedar "No issues found!"
flutter test               # 105 tests

# --- Contra la API LOCAL (../Lectorapp API con `npm run dev`, puerto 3000) ---
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api                    # emulador Android
adb reverse tcp:3000 tcp:3000                                                       # teléfono físico…
flutter run -d <device-id> --dart-define=API_BASE_URL=http://localhost:3000/api    # …y luego esto

# Vista previa de diseño en Chrome. --web-port=4200 es obligatorio (origen permitido por CORS).
# El cronómetro no funciona en web; el resto de la UI sí.
flutter run -d chrome --web-port=4200 --dart-define=API_BASE_URL=http://localhost:3000/api

# Contra PRODUCCIÓN (sin dart-define)
flutter run

# Release (R8 + ofuscación Dart). Guardar build/symbols de cada versión publicada:
# sin ellos no se pueden leer los stack traces.
flutter build apk --release --obfuscate --split-debug-info=build/symbols
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols

# Íconos y splash (fuentes en assets/icon/, con fondo transparente)
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# Re-sincronizar el espejo backend/ desde el repo de la API (commit actual)
git -C "../Lectorapp API" archive HEAD | tar -x -C backend
```

En la máquina del autor, `.vscode/launch.json` (no versionado) tiene estas mismas configuraciones;
la de teléfono ejecuta el `adb reverse` como tarea previa.

**API (`../Lectorapp API`)**

```bash
npm run dev          # nodemon, puerto 3000
npm test             # E2E (Jest + supertest) contra la BD anti_social_test
npm run test:setup   # crea/actualiza el esquema de la BD de test
npm run migrate      # migración idempotente (en cada entorno tras desplegar)
npm run cleanup      # borra tokens revocados expirados
```

**Deploy a producción** (servidor Docker `ubuntu@155.181.180.178`, ver `../Lectorapp API/DEPLOY.md`):
`git push origin main` en el repo de la API y luego `deploy\deploy.bat` (PuTTY/`plink` + llave `.ppk`);
`deploy\deploy.bat <commit>` hace rollback. En el servidor, `~/[LECTORAPP]/api` es un clon del repo y
los secretos están en `~/[LECTORAPP]/.env` (fuera de git). **Deploys, cambios en el servidor y pushes:
solo con confirmación explícita del usuario.**

---

## 10. Tests

| Archivo | Qué cubre |
|---|---|
| `test/api_client_refresh_test.dart` | Renovación antes de pedir, reintento tras 401, renovación única compartida, refresh rechazado cierra sesión, 503 no la cierra, margen de 30 s. |
| `test/models_and_utils_test.dart` | `asBool`, `UserProfile.fromJson`, `ReadingLog.fromJson`, `AuthService.isJwtValid`, `ApiClient.extractErrorMessage`. |
| `test/reading_log_form_test.dart` | `ReadingLogDraft` (igualdad, JSON, store) y `StarRatingInput` (toque, semántica, tamaño táctil). |
| `test/theme_contrast_test.dart` | Contraste WCAG de las 4 paletas (incluido `onInk` sobre `danger`, botón destructivo). |
| `test/display_mode_service_test.dart` | `DisplayModeService.pickBestMode`. |
| `test/terms_test.dart` | `TermsService` (necesita aceptar, guardar estado, `accept`), `ApiException.code`/`isTermsRequired`, registro con `accept_terms`, `TermsCheckbox` (semántica, 48 dp) y la hoja "Antes de compartir…" (incluido que no se cierra durante la petición). |
| `test/account_deletion_test.dart` | `ReadingLogDraftStore.clearAll`, limpieza del teléfono tras eliminar (se quedan tema y vista), `deleteAccount` (DELETE con contraseña; `INVALID_PASSWORD` y 500 no tocan sesión ni datos), `DeleteAccountScreen` (explicación, alternativa desactivar solo si está activa, botón `danger`, contraseña incorrecta junto al campo, cancelar no envía nada, éxito → Login con aviso) y la entrada desde `DeactivatedScreen`. |
| `test/account_deactivation_test.dart` | Textos de `account_copy`, parseo de `status`/`AccountStatusInfo`, `user-data` y login con `status`, red de seguridad del `403 ACCOUNT_DEACTIVATED` (una vez, cierra pantallas apiladas), `401 INVALID_PASSWORD` sin renovar ni cerrar sesión, desactivar/reactivar (incluido 409), `TabsScreen` en modo solo lectura, `DeactivatedScreen` (reactivar con confirmación) y `DeactivateAccountScreen` (contraseña incorrecta junto al campo). |

Salvo `DeactivatedScreen`, `DeactivateAccountScreen` y `DeleteAccountScreen`, no hay tests de pantallas completas ni de integración en la app. Para testear servicios, inyectar un
`MockClient` en `ApiClient` y usar `SharedPreferences.setMockInitialValues`.

---

## 11. Reglas para modificar el código

1. **HTTP solo por `ApiClient()`**, desde un servicio de `lib/services/`. Nunca URLs ni tokens escritos a mano; la URL base solo cambia con `--dart-define` (no editar `config.dart`).
2. **`mounted` después de cada `await`** antes de `setState()` o de usar `BuildContext`.
3. **Futures sin esperar a propósito → `unawaited(...)`** (`dart:async`).
4. **JSON con `asBool` / `asInt`**, nunca `== true` ni casts directos.
5. **Respetar el tema:** colores desde `context.lector` / `colorScheme`; títulos con `ThemeService.titleStyle`.
6. **Imágenes de red:** `CachedNetworkImage` / `CachedNetworkImageProvider` / `BookCover`, con avatares `/svg` → `/png`.
7. **Mensajes al usuario** con `showSuccess` / `showError`; estados vacíos y de error con `EmptyState` / `ErrorState`.
8. **Un solo formulario de lectura:** cualquier campo nuevo va en `ReadingLogSheet` **y** en `ReadingLogDraft` (igualdad, `toJson`/`fromJson`) para que el borrador y el aviso de descarte sigan funcionando.
9. **Si cambia la biblioteca del usuario**, el método del servicio debe llamar a `_notifyLibraryChanged()`.
10. **Validación duplicada a propósito:** si cambian las reglas de la API (`src/api/validators/*`), actualizar la validación local equivalente (`register_screen.dart`, `forgot_password_screen.dart`, `reading_log_sheet.dart`).
11. **No modificar `backend/`**: los cambios van en `../Lectorapp API`; luego re-sincronizar el espejo.
12. **App y API se despliegan juntas** cuando cambia el contrato.
13. **Dentro de `onStart` (isolate del cronómetro)** no usar servicios ni estado de la app: solo mensajes.
14. **Antes de dar algo por terminado:** `flutter analyze` sin issues y `flutter test` en verde. Actualizar este archivo, `CHANGELOG.md` y `PENDIENTES.md` si cambia la arquitectura, el contrato o la lista de pendientes.

### Deuda conocida (no copiar como patrón)

- `ReadingLog.fromJson` y `Book.fromJson` comparan booleanos con `== true || == 1` en vez de `asBool`.
- `PublicProfileScreen` muestra `e.toString()` como error y compara `is_private == true`.
- Colores fijos en los íconos de estadísticas (`#4995FF`, `#66BB6A`, `#AB47BC`, `#FFB74D`) en `profile_screen.dart`, `public_profile_screen.dart` y `book_stats_modal.dart`; `Colors.black/white` con alpha en sombras y en `book_detail_screen.dart` (estos últimos, sobre blur, son intencionales).
- `ReadingTimerModal` y `BookStatsModal` aún no siguen las skills de diseño (textos en mayúsculas, bordes propios).
- La clave `cached_global_feed` está declarada dos veces (`ApiClient.feedCacheKey` y `ReadingService._feedCacheKey`).
- `_buildStatsContent` / `_buildMetricCard` están duplicados entre `ProfileScreen` y `PublicProfileScreen`.
- `Book` (modelo) y `AuthService.isTokenValid()` no se usan.

---

## 12. Flujo de trabajo con agentes

Las tareas de `BACKLOG.md` se implementan con dos subagentes definidos en `.claude/agents/`, coordinados
por la sesión principal (**orquestador**). Un subagente no puede invocar a otro: toda entrega pasa por el orquestador.

1. **Orquestador → `desarrollador`** (modelo heredado): un encargo por tarea con ID, historia, criterios de
   aceptación, decisiones relevantes, repos/archivos implicados y restricciones. Nada de producción.
2. **`desarrollador`** implementa, corre analyze/tests y responde con su **informe de entrega**. No hace commits.
3. **Orquestador → `revisor`** (modelo **opus**, solo lectura + Bash): pasarle **solo** esa tarea — criterios,
   lista de archivos tocados / diff, cómo probar y número de ronda —, no el backlog entero ni el historial.
4. **`revisor`** responde `APROBADO`, `CAMBIOS REQUERIDOS` o (ronda 3) `ESCALAR AL USUARIO`.
5. Con cambios: reenviar los hallazgos al **mismo** desarrollador (`SendMessage`, conserva contexto) y volver al paso 3.
   **Máximo 3 rondas** por tarea; si no aprueba a la 3.ª, detener esa tarea y escalar al usuario con el resumen.
6. Con `APROBADO`: el orquestador hace el commit (mensaje con el ID de la tarea), marca `[x]` en `BACKLOG.md` y sigue.
7. Deploys, cambios en el servidor y pushes: solo el orquestador y con confirmación del usuario.

Commits: estilo *conventional* en inglés (`feat(ui): …`, `fix(app): …`, `docs: …`, `build(android): …`).

---

## 13. Dónde está cada cosa

| Documento | Contenido |
|---|---|
| [`README.md`](README.md) | Puesta en marcha para desarrolladores. |
| [`CHANGELOG.md`](CHANGELOG.md) | Qué incluye cada versión publicada. |
| [`PENDIENTES.md`](PENDIENTES.md) | Tareas no bloqueantes: firma de release, bundle ID de iOS, rotar clave SMTP, deuda de código y de diseño. Actualizarla al cerrar o descubrir tareas. |
| [`BACKLOG.md`](BACKLOG.md) | Trabajo planificado posterior a 1.1.0. |
| [`docs/guia-autenticacion.md`](docs/guia-autenticacion.md) | Sistema de sesión explicado paso a paso (API + Flutter). |
| `backend/DEPLOY.md` | Infraestructura y despliegue de la API. |

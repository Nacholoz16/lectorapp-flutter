# LectorApp

*Tu rincón de lectura acogedor.* App móvil en **Flutter** para registrar lo que lees, cronometrar
tus sesiones y, solo si quieres, compartirlo en un feed de lectores. Privada por defecto, sin
seguidores ni comentarios.

- **Versión:** 1.0.0 ([CHANGELOG](CHANGELOG.md))
- **Plataforma:** Android (ID `com.nacholoz3d.lectorapp`). iOS está sin configurar y web se usa solo como vista previa de diseño.
- **Backend:** API REST en Node.js + Express + MySQL, en un repositorio aparte (`Lectorapp API`).

## Funcionalidades

- **Cuenta:** registro, login con email o usuario, sesión que se renueva sola (JWT de 30 min + refresh token rotativo de 60 días) y recuperación de contraseña con código por email.
- **Lecturas:** añadir, editar y eliminar con estado (*Leyendo*, *Terminado*, *Lo dejé*), página actual, estrellas, fechas, notas y visibilidad. El formulario guarda un borrador automático: nada de lo escrito se pierde.
- **Cronómetro:** sesiones de lectura en segundo plano con notificación persistente.
- **Feed:** paginado por cursor, con caché sin conexión, aviso de publicaciones nuevas, "me gusta" instantáneo y dos vistas (tarjetas o compacta).
- **Biblioteca y perfil:** filtros por estado, estadísticas por libro y acumuladas, reto anual, ajustes de privacidad y 4 temas de color.
- **Accesibilidad:** contraste WCAG AA verificado por tests, soporte de TalkBack y objetivos táctiles de 48 dp.

## Requisitos

| Herramienta | Versión |
|---|---|
| Flutter (canal stable) | Probado con 3.44.7 (Dart 3.12.2). Mínimo Dart 3.0. |
| Android SDK + `adb` | Para emulador o teléfono físico |
| JDK | 11 o superior |
| Node.js + MySQL | Solo si vas a levantar la API en local |

## Puesta en marcha

```bash
git clone <url-del-repo> test_lectorapp
cd test_lectorapp
flutter pub get
flutter run            # usa la API de producción
```

Sin más configuración, la app apunta a producción (`https://api.nacholoz3d.cl/api`).

### Contra una API local

La URL de la API se elige **al compilar** con `--dart-define`; no edites `lib/config.dart`.
Levanta primero la API (`npm run dev` en el repo `Lectorapp API`, puerto 3000).

```bash
# Emulador Android (10.0.2.2 = localhost de tu PC)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api

# Teléfono físico (USB o depuración inalámbrica)
adb reverse tcp:3000 tcp:3000
flutter run -d <device-id> --dart-define=API_BASE_URL=http://localhost:3000/api
```

HTTP sin TLS solo está permitido en builds de **debug** y solo hacia `10.0.2.2` y `localhost`.
En release la app exige HTTPS.

### Vista previa en Chrome

Para iterar diseño sin teléfono. El puerto **4200 es obligatorio**: es el origen que la API permite por CORS.

```bash
flutter run -d chrome --web-port=4200 --dart-define=API_BASE_URL=http://localhost:3000/api
```

El cronómetro en segundo plano no funciona en web; el resto de la interfaz sí.

### VS Code

`.vscode/` está en `.gitignore`. Si quieres configuraciones de ejecución, crea `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "LectorApp (API local - emulador)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define=API_BASE_URL=http://10.0.2.2:3000/api"]
    },
    {
      "name": "LectorApp (API producción)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart"
    }
  ]
}
```

## Calidad

```bash
flutter analyze   # debe terminar en "No issues found!"
flutter test      # 47 tests
```

Ambos deben pasar antes de cada commit. Los lints del proyecto (`analysis_options.yaml`) son más
estrictos que los de Flutter por defecto: vigilan el uso de `BuildContext` tras un `await`, los
`Future` sin esperar y las suscripciones sin cancelar.

Los tests cubren la renovación de sesión del cliente HTTP, los modelos y utilidades, el borrador del
formulario de lectura, el selector de estrellas, el contraste de las cuatro paletas y la elección de
tasa de refresco.

## Arquitectura

```text
lib/
├── main.dart            Arranque: inicializaciones en paralelo y decisión de sesión
├── config.dart          URL base de la API y clave global de navegación
├── screens/             Pantallas (login, pestañas Inicio · Biblioteca · Perfil, búsqueda, detalle)
├── widgets/             Componentes y hojas inferiores (formulario de lectura, cronómetro, tarjetas)
├── services/            Singletons: ApiClient, Auth, Reading, User, Book, Theme, Preferences, Timer
├── models/              ReadingLog, UserProfile, ReadingLogDraft
├── theme/               Tokens de color (LectorColors → context.lector)
├── ui/                  Mensajes al usuario (showSuccess / showError)
└── utils/               Lectura tolerante de JSON (asBool / asInt)
```

Decisiones que conviene conocer antes de tocar código:

- **Sin librería de estado.** Cada pantalla usa `setState`; lo que comparten varias pantallas se expone como `ValueNotifier` en un servicio singleton (tema, vista del feed, cambios en la biblioteca).
- **Todo el HTTP pasa por `ApiClient`.** Añade el token, renueva la sesión cuando el acceso vence o llega un 401, y convierte cualquier fallo en `ApiException` con un mensaje listo para mostrar.
- **La UI trabaja sobre `Map` crudos de la API** en el feed, la búsqueda y los modales; los modelos tipados se usan en biblioteca y perfiles. Los booleanos y enteros se leen con `asBool` / `asInt` porque MySQL puede devolver `1`/`0`.
- **Un solo formulario de lectura** (`ReadingLogSheet`) sirve para añadir y editar, con borrador local automático.
- **El cronómetro corre en otro isolate** (`flutter_background_service`) y se comunica con la UI solo por mensajes.
- **Colores por tokens.** Cada tema tiene un pastel (`accent`, decorativo) y un tono legible (`ink`, para texto y botones). Usa `context.lector` o `colorScheme`, nunca colores fijos.

El detalle completo (flujos, contrato de la API, almacenamiento local, reglas y deuda conocida) está
en [CLAUDE.md](CLAUDE.md).

## Backend

La API vive en el repositorio hermano `Lectorapp API`. La carpeta [`backend/`](backend/) de este repo
es un **espejo de solo lectura** de esa API en su versión 1.0.0, para consultar controladores,
validadores y SQL sin cambiar de proyecto. **No la modifiques**: los cambios van en el repo de la API
y luego se re-sincroniza el espejo:

```bash
git -C "../Lectorapp API" archive HEAD | tar -x -C backend
```

Cuando cambia el contrato, app y API se despliegan juntas. El despliegue de la API está documentado
en [`backend/DEPLOY.md`](backend/DEPLOY.md).

## Build de release

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols   # Google Play
```

- Guarda `build/symbols` de cada versión publicada: sin ellos no se pueden leer los stack traces.
- **La firma de release todavía usa las claves de debug.** Antes de publicar en Google Play hay que configurar un keystore propio (ver [PENDIENTES.md](PENDIENTES.md)). El keystore nunca va al repositorio.
- No cambies el ID de Android una vez publicada la app.

### Íconos y splash

Las fuentes están en `assets/icon/` y deben tener fondo transparente (salvo `icon_legacy.png`).

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Convenciones

- Commits en inglés, estilo *conventional*: `feat(ui): …`, `fix(app): …`, `docs: …`, `build(android): …`.
- Textos de la interfaz en español, tuteo, sin mayúsculas sostenidas.
- Comprueba `mounted` después de cada `await` antes de usar el contexto o llamar a `setState`.
- Envuelve en `unawaited(...)` los `Future` que no esperas a propósito.
- Títulos con `ThemeService.titleStyle` (Lora); no uses `fontFamily: 'Lora'`, no aplica la fuente.
- Opacidad con `.withValues(alpha: x)`, no `.withOpacity`.
- Si cambias una regla de validación en la API, cambia también la validación local equivalente.

## Documentación

| Documento | Para qué |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Referencia técnica completa: arquitectura, contrato de la API, reglas. Pensada también para agentes de IA. |
| [CHANGELOG.md](CHANGELOG.md) | Qué incluye cada versión. |
| [PENDIENTES.md](PENDIENTES.md) | Tareas no bloqueantes y deuda técnica. |
| [BACKLOG.md](BACKLOG.md) | Trabajo planificado para las próximas versiones. |
| [docs/guia-autenticacion.md](docs/guia-autenticacion.md) | Cómo funciona la sesión con refresh tokens y la recuperación de contraseña. |
| `.claude/skills/` | Guías de diseño, accesibilidad, UX y revisión de UI. |

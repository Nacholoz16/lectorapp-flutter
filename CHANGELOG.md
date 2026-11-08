# Changelog

## 1.0.0 — 2026-11-08

Primera versión estable de LectorApp (app Flutter + API `Lectorapp API` desplegadas juntas).

### Lectura y comunidad
- Inicio con saludo personal que se pliega al hacer scroll, barra de búsqueda
  ("¿Qué estás leyendo?") y tarjeta **"Sigues leyendo"** para retomar el libro actual.
- Feed de la comunidad paginado por cursor, con caché sin conexión, aviso de publicaciones
  nuevas y "me gusta" instantáneo.
- Dos vistas del feed: **tarjetas** (portada protagonista, por defecto) o **compacta**
  (Perfil → ⚙ → Vista del feed).
- Pestaña **Mi biblioteca** con filtros Leyendo · Terminados · Lo dejé y acceso al cronómetro.
- Formulario único para añadir/editar lecturas: **borrador automático** (lo escrito no se
  pierde), aviso antes de descartar, fechas propuestas, validación en línea y privacidad explícita.
- Cronómetro de lectura en segundo plano con notificación.
- Perfil con reto anual y estadísticas; perfiles públicos con candados de privacidad.

### Cuenta y seguridad
- **Sesión que no caduca mientras se use la app**: token de acceso de 30 min + refresh token
  rotativo de 60 días; detección de reutilización de tokens robados.
- **"¿Olvidaste tu contraseña?"** con código de 6 dígitos por email (ZeptoMail,
  `noreply@lectorapp.nacholoz3d.cl`). Cambiar la contraseña cierra las demás sesiones.
- API endurecida: validación con Zod, errores `{error, code}`, rate limiting, JWT HS256 fijo,
  blacklist por hash, dependencias sin vulnerabilidades conocidas.

### Diseño y accesibilidad
- Sistema de diseño con tokens: cada tema tiene un tono pastel y uno "ink" con contraste
  WCAG AA verificado por tests; 4 temas (Crema y salvia, Rosa peonía, Brisa de mar,
  Café de medianoche); tipografía Lora + Nunito.
- TalkBack: tarjetas legibles como frases, botones con nombre, estrellas como control
  ajustable, objetivos táctiles de 48 dp, letra mínima 12.
- Estados vacíos, de error y de carga en todas las pantallas; mensajes de error humanos.
- Ícono adaptativo con capa monocroma (íconos temáticos de Android 13+/HyperOS) y splash
  que sigue el modo claro/oscuro del sistema; 120 Hz en pantallas compatibles.

### Desarrollo
- Vista previa en Chrome (`flutter run -d chrome --web-port=4200`).
- Skills de diseño, accesibilidad, UX y revisión de UI en `.claude/skills/`.
- Tareas no bloqueantes en [`PENDIENTES.md`](PENDIENTES.md).

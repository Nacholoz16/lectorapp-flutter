# Backlog — LectorApp 1.1.0 · "Lista para Google Play"

Objetivo de la versión: cumplir las políticas de Google Play (cuentas, contenido generado por usuarios,
privacidad) y dar herramientas de moderación, con una web propia en **https://lectorapp.nacholoz3d.cl**.

Creado: 2026-11-09. Estimaciones: **S** ≈ medio día · **M** ≈ 1–2 días · **L** ≈ 3+ días.
Estado: `[ ]` por hacer · `[~]` en curso · `[x]` hecho.

> Fuera de este backlog (siguen en [`PENDIENTES.md`](PENDIENTES.md)): firma de release, gestos 1.0.1,
> Google Sign-In (1.2), bundle ID de iOS, modelos tipados, FULLTEXT, dependencias.

---

## Decisiones (confirmar antes de empezar)

| ID | Decisión | Recomendación |
|---|---|---|
| D1 | Tecnología de la web | **Vite + React + TypeScript**, compilada a estáticos y servida por un contenedor **Nginx**. Las páginas legales se pre-renderizan como HTML (rápidas, indexables); el panel de administración es una SPA bajo `/admin`. |
| D2 | Sesión del administrador en la web | Solo **token de acceso de 30 min en memoria** (sin refresh en el navegador): al recargar o tras 30 min, se vuelve a iniciar sesión. Más simple y más seguro para un panel con pocos usos. |
| D3 | ¿Quién es administrador? | Columna `users.role` (`user` / `admin`). El primer admin se asigna por SQL en el servidor; no hay endpoint para auto-promoverse. |
| D4 | Ocultar automáticamente por denuncias | Una reseña con **3 denuncias de usuarios distintos** se oculta hasta que un admin la revise. |
| D5 | Inhabilitar cuenta (usuario) | Reversible: ocultar perfil y contenido; **volver a iniciar sesión la reactiva** (con confirmación). No sustituye a "Eliminar" (Google exige borrado real). |
| D6 | Apelaciones | **Una** por baneo. Resolución del admin: *aceptar* (se levanta el baneo) o *rechazar* (definitivo). |

---

## Modelo de datos (resumen)

```sql
ALTER TABLE users
  ADD COLUMN role ENUM('user','admin') NOT NULL DEFAULT 'user',
  ADD COLUMN status ENUM('active','deactivated','banned') NOT NULL DEFAULT 'active',
  ADD COLUMN status_changed_at BIGINT UNSIGNED NULL,
  ADD COLUMN terms_version VARCHAR(20) NULL,          -- versión aceptada (p. ej. '2026-11')
  ADD COLUMN terms_accepted_at DATETIME NULL;

ALTER TABLE reading_logs ADD COLUMN hidden_at DATETIME NULL;   -- oculta por moderación

CREATE TABLE user_blocks (blocker_id, blocked_id, created_at, PRIMARY KEY (blocker_id, blocked_id));

CREATE TABLE reports (
  id, reporter_id, target_type ENUM('reading','user'), target_id, reason ENUM('spam','ofensivo',
  'acoso','spoiler','otro'), details VARCHAR(500), status ENUM('open','dismissed','actioned'),
  resolved_by, resolved_at, created_at,
  UNIQUE (reporter_id, target_type, target_id)        -- una denuncia por persona y objetivo
);

CREATE TABLE bans (id, user_id, admin_id, reason VARCHAR(500), report_id NULL, created_at, lifted_at NULL);

CREATE TABLE ban_appeals (id, ban_id UNIQUE, message VARCHAR(1000), status ENUM('pending','accepted',
  'rejected'), admin_id NULL, admin_note VARCHAR(500) NULL, created_at, resolved_at NULL);

CREATE TABLE admin_actions (id, admin_id, action, target_type, target_id, note, created_at); -- auditoría

CREATE TABLE deletion_requests (id, email_hash, code_hash, expires_at, attempts, used_at, created_at); -- web
```

Todo con **migración idempotente** (`npm run migrate`) y en el setup de la BD de tests.

## Endpoints nuevos (resumen)

| Método y ruta | Quién | Para qué |
|---|---|---|
| `POST /account/deactivate` | usuario | Inhabilitar mi cuenta (revoca sesiones) |
| `DELETE /account` | usuario | Eliminar mi cuenta (con contraseña) |
| `POST /account/deletion-request` · `POST /account/deletion-confirm` | público (web) | Borrado por email + código de 6 dígitos |
| `POST /account/terms` | usuario | Aceptar la versión vigente de los términos |
| `POST /reports` | usuario | Denunciar reseña o usuario |
| `GET/POST/DELETE /blocks` | usuario | Listar, bloquear, desbloquear |
| `POST /appeals` | baneado (con `appeal_token`) | Enviar la única apelación |
| `GET /admin/reports` · `POST /admin/reports/:id/resolve` | admin | Cola de denuncias y resolución |
| `POST /admin/users/:id/ban` · `/unban` | admin | Banear / levantar baneo |
| `POST /admin/readings/:id/hide` · `/unhide` | admin | Ocultar / mostrar reseña |
| `GET /admin/appeals` · `POST /admin/appeals/:id/resolve` | admin | Apelaciones |
| `GET /admin/stats` | admin | Contadores del panel |

---

## Épica 1 — Términos y Política de privacidad · *Prioridad 1*

### 1.1 Redactar Términos y Condiciones básicos · S
Como usuario, quiero saber qué reglas aplican a lo que publico.
- [ ] Texto en español, versión `2026-11`: qué es el servicio, requisitos (edad mínima 13 años),
  cuenta y seguridad, **conducta y contenido prohibido** (odio, acoso, spam, contenido sexual o ilegal,
  suplantación), propiedad del contenido y licencia para mostrarlo, **moderación** (denuncias, ocultar,
  baneo, una apelación), inhabilitar y eliminar la cuenta, limitación de responsabilidad, cambios en
  los términos, contacto.
- **Aceptación:** cubre los puntos que pide la política de contenido generado por usuarios de Google;
  lenguaje claro; fecha y versión visibles.

### 1.2 Redactar Política de privacidad · S
- [ ] Qué datos se recogen (email, usuario, bio, avatar, lecturas, reseñas, sesiones de lectura,
  "me gusta"), para qué, base legal, dónde se guardan (servidor propio), con quién se comparten
  (ZeptoMail solo para enviar correos; Open Library/Google Books para buscar libros), retención,
  derechos (acceso, corrección, **eliminación** con el enlace), seguridad (HTTPS, contraseñas con hash),
  menores, contacto.
- **Aceptación:** coincide con lo que se declare en el formulario "Seguridad de los datos" de Play Console.

### 1.3 Aceptación obligatoria en la app · M
Como plataforma, necesito que nadie publique sin aceptar los términos.
- [ ] API: `users.terms_version/terms_accepted_at`; registro exige `accept_terms: true`;
  `POST /account/terms`; crear/editar una lectura **pública** sin la versión vigente aceptada → `403 TERMS_REQUIRED`.
- [ ] App: casilla obligatoria en Registro con enlaces a ambos documentos; para cuentas existentes,
  hoja "Antes de compartir…" la primera vez que publiquen; enlaces en Perfil → ⚙ → Legal.
- **Aceptación:** no se puede crear contenido público sin aceptar; queda registrada versión y fecha.

---

## Épica 2 — Inhabilitar y eliminar la cuenta · *Prioridad 1*

### 2.1 Inhabilitar mi cuenta (usuario) · M
Como usuario, quiero tomarme un descanso sin perder mi biblioteca.
- [ ] API: `POST /account/deactivate` (pide contraseña) → `status = 'deactivated'`, revoca refresh
  tokens y marca `status_changed_at`; perfil, reseñas y "me gusta" dejan de verse para otros
  (feed, reseñas por libro, perfiles, contadores).
- [ ] Login de una cuenta inhabilitada → respuesta `409 ACCOUNT_DEACTIVATED`; la app pregunta
  "¿Reactivar tu cuenta?" y al confirmar `POST /auth/login` con `reactivate: true` la reactiva.
- [ ] App: Perfil → ⚙ → Cuenta → "Inhabilitar mi cuenta", con explicación y confirmación.
- **Aceptación:** tras inhabilitar, otro usuario no encuentra nada de la cuenta; al volver, todo reaparece.

### 2.2 Eliminar mi cuenta desde la app · M
Como usuario, quiero borrar mi cuenta y mis datos para siempre.
- [ ] API: `DELETE /account` con contraseña (o código por email si en el futuro no tiene contraseña)
  → borra en transacción: lecturas, sesiones de lectura, metas, "me gusta" dados, bloqueos, denuncias
  hechas, refresh tokens, códigos; luego el usuario (`ON DELETE CASCADE` donde exista). Los libros
  (catálogo compartido) no se borran.
- [ ] App: Perfil → ⚙ → Cuenta → "Eliminar mi cuenta": pantalla que explica qué se borra, campo de
  contraseña y botón destructivo; al terminar, vuelve al Login con un aviso.
- [ ] Test E2E: tras borrar, ningún rastro del usuario en ninguna tabla.
- **Aceptación:** borrado real (no desactivación), irreversible y avisado.

### 2.3 Solicitar eliminación desde la web · M · *depende de Épica 5*
Google exige un enlace web para pedir el borrado.
- [ ] Web `/eliminar-cuenta`: email → código de 6 dígitos por correo → confirmar → mismo borrado que 2.2.
  Misma protección que la recuperación (respuesta idéntica, HMAC, 15 min, 5 intentos, rate limit).
- **Aceptación:** la URL se puede registrar en Play Console; funciona sin la app instalada.

---

## Épica 3 — Denunciar y bloquear · *Prioridad 1*

### 3.1 Denunciar reseña o usuario · M
Como usuario, quiero avisar de contenido inapropiado.
- [ ] API: `POST /reports` (`target_type`, `target_id`, `reason`, `details?`); 1 por persona y objetivo;
  no se puede denunciar a uno mismo; rate limit; correo al admin con el resumen (sin datos sensibles).
- [ ] Ocultado automático (D4): 3 denuncias distintas abiertas sobre una reseña → `hidden_at = NOW()`.
- [ ] App: menú **⋯** en cada tarjeta del feed, en reseñas de un libro y en perfiles públicos →
  "Denunciar" → hoja con motivos → confirmación "Gracias, lo revisaremos".
- **Aceptación:** controles visibles y claramente etiquetados (requisito de Google); accesibles con TalkBack.

### 3.2 Bloquear y desbloquear usuarios · M
Como usuario, no quiero ver nada de una persona.
- [ ] API: `user_blocks`; `POST/DELETE /blocks/:userId`, `GET /blocks`. Filtrar en **ambas direcciones**
  en: feed (incluido `new-count`), reseñas por libro, perfil público (→ 404 para quien bloqueó/fue bloqueado),
  biblioteca pública y "me gusta" (no se puede dar "me gusta" entre bloqueados).
- [ ] App: "Bloquear usuario" en el mismo menú ⋯ (con confirmación) y Perfil → ⚙ → **Usuarios bloqueados**
  para desbloquear. Al bloquear, desaparece su contenido al instante (sin recargar).
- **Aceptación:** tests E2E de cada punto de filtrado; feed por cursor sigue sin duplicados.

---

## Épica 4 — Moderación: baneo y apelación · *Prioridad 2*

### 4.1 Rol de administrador y auditoría · S
- [ ] `users.role`; middleware `requireAdmin` (después de `protect`); tabla `admin_actions` y registro
  de cada acción de admin (quién, qué, a quién, cuándo, nota).
- [ ] Rate limit propio para `/admin/*`; ningún endpoint permite cambiar `role`.
- **Aceptación:** un usuario normal recibe 403 en todo `/admin/*` (test).

### 4.2 Banear y levantar baneo · M
Como administrador, quiero expulsar a quien incumple las reglas.
- [ ] API: `POST /admin/users/:id/ban` (`reason`, `report_id?`) → `status = 'banned'`, fila en `bans`,
  revoca todas las sesiones (refresh + `status_changed_at` para invalidar accesos vigentes), oculta su
  contenido; `POST /admin/users/:id/unban`. No se puede banear a otro admin.
- [ ] `protect` rechaza cuentas baneadas o inhabilitadas.
- [ ] Login de una cuenta baneada → `403 ACCOUNT_BANNED` con `{ reason, banned_at, can_appeal, appeal_token }`
  (`appeal_token`: JWT corto y de un solo propósito, solo si aún no apeló).
- [ ] Correo al usuario: motivo y cómo apelar.
- **Aceptación:** un baneado no puede usar la API de ninguna forma; su contenido no se ve.

### 4.3 Apelar un baneo (una sola vez) · M
Como usuario baneado, quiero pedir que se revise mi caso.
- [ ] API: `POST /appeals` con `appeal_token` + `message` (≤ 1000) → `ban_appeals` (único por baneo);
  segunda apelación → `409`.
- [ ] App: al intentar iniciar sesión baneado, pantalla "Tu cuenta fue suspendida" con el motivo y
  botón **Apelar** (si `can_appeal`) → formulario → "Recibimos tu apelación"; si ya apeló, muestra el estado.
- [ ] Web: misma pantalla en `/apelar` (login → formulario).
- [ ] Correo al usuario con la resolución.
- **Aceptación:** exactamente una apelación por baneo; la decisión de rechazo es definitiva.

---

## Épica 5 — Web lectorapp.nacholoz3d.cl · *Prioridad 1 (base) / 2 (panel)*

### 5.1 Reemplazar el front viejo por la web nueva · M
- [ ] Respaldar el servicio `frontend` actual (`lectorFront`, Ionic/Angular) y su configuración en
  `backups/` del servidor; **eliminar** el contenedor y su servicio del `docker-compose.yml`.
- [ ] Nuevo repo `lectorapp-web` (D1), con el diseño de la app (tokens de color, Lora + Nunito,
  modo claro/oscuro). Contenedor **Nginx** que sirve los estáticos; cabeceras de seguridad
  (HSTS, CSP, `X-Content-Type-Options`, `Referrer-Policy`).
- [ ] Nginx Proxy Manager: `lectorapp.nacholoz3d.cl` → nuevo contenedor, con certificado TLS.
- [ ] API: agregar `https://lectorapp.nacholoz3d.cl` a CORS.
- [ ] Deploy con un `deploy.bat` como el de la API (git pull + build + recrear solo ese contenedor).
- **Aceptación:** la web carga por HTTPS con nota A en las cabeceras de seguridad; la API y la BD no se reinician.

### 5.2 Páginas públicas · S
- [ ] `/` presentación breve de la app · `/terminos` · `/privacidad` · `/eliminar-cuenta` (2.3) ·
  `/apelar` (4.3) · `/contacto`.
- **Aceptación:** HTML estático accesible (contraste AA, navegable con teclado), funciona en móvil.

### 5.3 Panel de administración `/admin` · L
Como administrador, quiero moderar desde el navegador.
- [ ] Login (solo `role = admin`; D2) y cierre de sesión.
- [ ] **Resumen**: denuncias abiertas, apelaciones pendientes, baneos activos, usuarios nuevos (7 días).
- [ ] **Denuncias**: lista filtrable (abiertas/resueltas, tipo, motivo), detalle con el contenido
  denunciado y el historial del usuario; acciones: *Descartar*, *Ocultar reseña*, *Banear usuario*
  (con motivo), cada una con confirmación y nota.
- [ ] **Apelaciones**: pendientes con el baneo original y el mensaje; *Aceptar* / *Rechazar* con nota.
- [ ] **Usuarios**: buscar por usuario/email, ver estado, banear / levantar baneo.
- [ ] **Auditoría**: listado de `admin_actions`.
- **Aceptación:** todo el flujo denuncia → baneo → apelación → resolución se puede hacer sin SQL.

---

## Épica 6 — Protección de datos · *Prioridad 2*

### 6.1 Respaldos cifrados · S
- [ ] Script de respaldo diario (`mysqldump` → `gzip` → cifrado con `age` o `gpg` con clave pública;
  la privada **fuera** del servidor); retención 14 días.
- [ ] Borrar el volcado en texto plano de `backups/` (2026-11-08) tras verificar un respaldo cifrado.
- [ ] Probar una restauración en local (documentada en `DEPLOY.md`).

### 6.2 Contraseña root de MySQL · S
- [ ] Generar una larga y aleatoria, `ALTER USER` dentro de `lectorDB`, actualizar `.env`; respaldo antes.

### 6.3 Email cifrado en la base de datos · M
- [ ] Columnas `email_enc` (AES-256-GCM) y `email_idx` (HMAC para buscar y para UNIQUE); clave
  `DATA_ENCRYPTION_KEY` en `.env` (respaldada fuera del servidor); migración que cifra los existentes
  y elimina la columna en claro al final; registro, login, recuperación, borrado y panel usan las nuevas.
- **Aceptación:** un volcado de la BD no muestra ningún email; todos los tests de auth siguen pasando.

---

## Épica 7 — Preparación de la ficha de Google Play · *Prioridad 2* (sin código, con guía)

- [ ] Cuenta de Play Console (personal) y verificación de identidad.
- [ ] Firma de release + `flutter build appbundle` (está en `PENDIENTES.md`; se vuelve bloqueante aquí).
- [ ] Ficha: textos, ícono 512 px, gráfico destacado, capturas.
- [ ] Formularios: clasificación de contenido, público objetivo, **Seguridad de los datos**, acceso
  a la app (cuenta de prueba para el revisor), declaración del servicio en primer plano del cronómetro
  (revisar si `dataSync` es el tipo correcto).
- [ ] URLs: privacidad, eliminación de cuenta (Épica 5).
- [ ] Prueba cerrada: ≥ 12 testers durante 14 días seguidos → solicitar acceso a producción.

---

## Orden propuesto (sprints)

| Sprint | Contenido | Resultado |
|---|---|---|
| **1** | D1–D6 · 1.1 · 1.2 · 4.1 · 5.1 · 5.2 | Web nueva en `lectorapp.nacholoz3d.cl` con términos y privacidad publicados |
| **2** | 1.3 · 2.1 · 2.2 · 2.3 | Aceptación de términos, inhabilitar y eliminar (app + web) |
| **3** | 3.1 · 3.2 · 4.2 · 4.3 | Denunciar, bloquear, banear y apelar |
| **4** | 5.3 | Panel de administración completo |
| **5** | 6.1 · 6.2 · 6.3 | Datos protegidos |
| **6** | Épica 7 | App enviada a prueba cerrada en Google Play |

Al cerrar 1.1.0: actualizar `CHANGELOG.md`, `CLAUDE.md` (contrato de la API, nuevas pantallas),
la skill `auth-sesiones-seguras` si cambian los flujos de cuenta, y etiquetar `v1.1.0` en los repos.

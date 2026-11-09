# Backlog — LectorApp 1.1.0 · "Lista para Google Play"

Objetivo de la versión: cumplir las políticas de Google Play (cuentas, contenido generado por usuarios,
privacidad) y dar herramientas de moderación, con una web propia en **https://lectorapp.nacholoz3d.cl**.

Creado: 2026-11-09 · Decisiones confirmadas: 2026-11-09. Estimaciones: **S** ≈ medio día · **M** ≈ 1–2 días · **L** ≈ 3+ días.
Estado: `[ ]` por hacer · `[~]` en curso · `[x]` hecho.

> Fuera de este backlog (siguen en [`PENDIENTES.md`](PENDIENTES.md)): firma de release, gestos 1.0.1,
> Google Sign-In (1.2), bundle ID de iOS, modelos tipados, FULLTEXT, dependencias.

---

## Decisiones (confirmadas el 2026-11-09)

| ID | Decisión |
|---|---|
| D1 | **Web con Vite + React + TypeScript**, compilada a estáticos y servida por un contenedor **Nginx**. Páginas legales pre-renderizadas como HTML; panel de administración como SPA bajo `/admin`. (Primera vez con estas herramientas: explicar cada pieza al construirla.) |
| D2 | Sesión del administrador en la web: solo **token de acceso de 30 min en memoria**, sin refresh en el navegador. Al recargar o tras 30 min se vuelve a iniciar sesión. |
| D3 | El administrador es **`test001`**: `users.role = 'admin'` asignado por SQL en el servidor (comprobar que la cuenta existe en producción). Ningún endpoint permite cambiar el rol. |
| D4 | Una reseña con **3 denuncias de personas distintas** pasa a **privada de forma permanente** (`moderation_locked_at`): sale del feed y de las reseñas del libro, y su autor **no puede volver a hacerla pública**. Se **avisa al autor** (correo + aviso en la app). Solo un admin puede revertirlo (si descarta las denuncias). |
| D5 | **Inhabilitar = banear (sanción): la cuenta queda suspendida y no puede entrar.** Dos orígenes: **manual** (un admin la banea) o **automático** (acumula **10 denuncias de personas distintas** sobre la cuenta o su contenido). En ambos casos la persona puede **exportar su biblioteca** y **apelar una vez**. |
| D7 | **Desactivar = voluntario del usuario** (distinto de inhabilitar). Botón + confirmación para desactivar y lo mismo para reactivar. Mientras está desactivada: el usuario **sí entra**, pero solo ve **su biblioteca en modo lectura** (sin feed, sin perfiles ajenos, sin buscar) y **no puede hacer acciones** (crear, editar, dar "me gusta", denunciar, cronómetro). Para los demás su perfil está **oculto**. Al desactivar, **todas sus lecturas y opiniones públicas pasan a privadas**; al reactivar, **vuelven a su visibilidad anterior** (salvo las bloqueadas por moderación, que siguen privadas), y se le **recuerda** antes y después de confirmar. "Eliminar mi cuenta" sigue existiendo aparte (lo exige Google). |
| D6 | **Una apelación** por suspensión. El admin la *acepta* (se reactiva la cuenta) o la *rechaza* (definitivo). |

## Modelo de datos (resumen)

```sql
ALTER TABLE users
  ADD COLUMN role ENUM('user','admin') NOT NULL DEFAULT 'user',
  ADD COLUMN status ENUM('active','deactivated','suspended') NOT NULL DEFAULT 'active',
  ADD COLUMN status_changed_at BIGINT UNSIGNED NULL,
  ADD COLUMN terms_version VARCHAR(20) NULL,          -- versión aceptada (p. ej. '2026-11')
  ADD COLUMN terms_accepted_at DATETIME NULL;

ALTER TABLE reading_logs
  ADD COLUMN moderation_locked_at DATETIME NULL,          -- privada permanente (D4)
  ADD COLUMN public_before_deactivation TINYINT(1) NULL;  -- visibilidad a restaurar al reactivar (D7)

CREATE TABLE user_blocks (blocker_id, blocked_id, created_at, PRIMARY KEY (blocker_id, blocked_id));

CREATE TABLE reports (
  id, reporter_id, target_type ENUM('reading','user'), target_id, reason ENUM('spam','ofensivo',
  'acoso','spoiler','otro'), details VARCHAR(500), status ENUM('open','dismissed','actioned'),
  resolved_by, resolved_at, created_at,
  UNIQUE (reporter_id, target_type, target_id)        -- una denuncia por persona y objetivo
);

CREATE TABLE suspensions (id, user_id, source ENUM('admin','reports'), admin_id NULL,
  reason VARCHAR(500), report_id NULL, created_at, lifted_at NULL);

CREATE TABLE suspension_appeals (id, suspension_id UNIQUE, message VARCHAR(1000), status ENUM('pending',
  'accepted','rejected'), admin_id NULL, admin_note VARCHAR(500) NULL, created_at, resolved_at NULL);

CREATE TABLE user_notices (id, user_id, type ENUM('reading_locked','suspended','appeal_resolved'),
  payload JSON, created_at, read_at NULL);           -- avisos dentro de la app

CREATE TABLE admin_actions (id, admin_id, action, target_type, target_id, note, created_at); -- auditoría

CREATE TABLE deletion_requests (id, email_hash, code_hash, expires_at, attempts, used_at, created_at); -- web
```

Todo con **migración idempotente** (`npm run migrate`) y en el setup de la BD de tests.

## Endpoints nuevos (resumen)

| Método y ruta | Quién | Para qué |
|---|---|---|
| `POST /account/deactivate` · `POST /account/reactivate` | usuario | Desactivar / reactivar mi cuenta (D7) |
| `DELETE /account` | usuario | Eliminar mi cuenta (con contraseña) |
| `POST /account/deletion-request` · `POST /account/deletion-confirm` | público (web) | Borrado por email + código de 6 dígitos |
| `POST /account/terms` | usuario | Aceptar la versión vigente de los términos |
| `POST /reports` | usuario | Denunciar reseña o usuario |
| `GET/POST/DELETE /blocks` | usuario | Listar, bloquear, desbloquear |
| `GET /account/notices` · `POST /account/notices/:id/read` | usuario | Avisos (reseña hecha privada, etc.) |
| `GET /suspended/export` | suspendido (con `suspension_token`) | Exportar mi biblioteca (CSV y JSON) |
| `POST /suspended/appeal` | suspendido (con `suspension_token`) | Enviar la única apelación |
| `GET /admin/reports` · `POST /admin/reports/:id/resolve` | admin | Cola de denuncias y resolución |
| `POST /admin/users/:id/suspend` · `/reactivate` | admin | Banear / reactivar |
| `POST /admin/readings/:id/lock` · `/unlock` | admin | Hacer privada permanente / revertir |
| `GET /admin/appeals` · `POST /admin/appeals/:id/resolve` | admin | Apelaciones |
| `GET /admin/stats` | admin | Contadores del panel |

---

## Épica 1 — Términos y Política de privacidad · *Prioridad 1*

### 1.1 Redactar Términos y Condiciones básicos · S
Como usuario, quiero saber qué reglas aplican a lo que publico.
- [ ] Texto en español, versión `2026-11`: qué es el servicio, requisitos (edad mínima 13 años),
  cuenta y seguridad, **conducta y contenido prohibido** (odio, acoso, spam, contenido sexual o ilegal,
  suplantación), propiedad del contenido y licencia para mostrarlo, **moderación** (denuncias, ocultar,
  inhabilitación por sanción, una apelación), desactivación voluntaria y eliminación de la cuenta,
  limitación de responsabilidad, cambios en
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

## Épica 2 — Desactivar y eliminar la cuenta · *Prioridad 1*

> Ojo con los términos: **desactivar** es voluntario y reversible (esta épica); **inhabilitar**
> es una sanción del sistema o de un admin (Épica 4).

### 2.1 Desactivar y reactivar mi cuenta (voluntario) · M
Como usuario, quiero tomarme un descanso: ocultar mi perfil sin perder mi biblioteca.
- [ ] API `POST /account/deactivate` (con contraseña), en una transacción:
  guardar en `public_before_deactivation` la visibilidad actual de **cada** lectura, poner todas en
  privadas (`is_log_public = 0`), `status = 'deactivated'`, `status_changed_at`.
- [ ] Estando desactivada:
  - `protect` deja pasar, pero un middleware `requireActive` responde `403 ACCOUNT_DEACTIVATED` en todo
    lo que **no** sea: ver mi biblioteca y mis estadísticas, reactivar, cerrar sesión, eliminar la cuenta.
  - Para los demás: perfil → 404, nada suyo en feed, reseñas por libro ni contadores públicos.
- [ ] API `POST /account/reactivate` (botón + confirmación): restaura cada lectura a
  `public_before_deactivation` (las que tengan `moderation_locked_at` siguen privadas), limpia la
  columna, `status = 'active'`. Devuelve cuántas volvieron a ser públicas.
- [ ] App, desactivar: Perfil → ⚙ → Cuenta → **Desactivar mi cuenta** → pantalla que explica qué pasa
  ("Tus N lecturas públicas pasarán a privadas; cuando vuelvas, regresarán como estaban") →
  confirmación.
- [ ] App, estado desactivado: al entrar, modo **solo lectura**: solo la pestaña Biblioteca (sin Inicio,
  sin buscar, sin botones de añadir/editar/cronómetro), con un aviso fijo "Tu cuenta está desactivada" y el
  botón **Reactivar mi cuenta**.
- [ ] App, reactivar: confirmación que **recuerda** "Tus N lecturas que eran públicas volverán a ser
  públicas" → tras reactivar, aviso "Volvieron a ser públicas N lecturas" y la app vuelve a la normalidad.
- [ ] Tests E2E: visibilidad guardada y restaurada exactamente; bloqueadas por moderación siguen privadas;
  cada acción prohibida devuelve 403; otro usuario no ve nada del desactivado.
- **Aceptación:** desactivar y reactivar dejan cada lectura exactamente como estaba; el usuario siempre
  sabe qué va a pasar antes de confirmar.

### 2.2 Eliminar mi cuenta desde la app · M
Como usuario, quiero borrar mi cuenta y mis datos para siempre.
- [ ] API: `DELETE /account` con contraseña (o código por email si en el futuro no tiene contraseña)
  → borra en transacción: lecturas, sesiones de lectura, metas, "me gusta" dados, bloqueos, denuncias
  hechas, refresh tokens, códigos; luego el usuario (`ON DELETE CASCADE` donde exista). Los libros
  (catálogo compartido) no se borran. Disponible también para cuentas suspendidas (desde la web, 2.3):
  Google exige que cualquiera pueda borrar su cuenta.
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
- [ ] **Privada permanente automática (D4):** 3 denuncias abiertas de personas distintas sobre una reseña →
  `is_log_public = 0` + `moderation_locked_at = NOW()`; `PUT /readings/:id` con `is_log_public: true` en una
  reseña bloqueada → `403 MODERATION_LOCKED`. Aviso al autor: correo + `user_notices`.
- [ ] App: al abrir, si hay avisos sin leer, mostrar "Una de tus reseñas pasó a privada" con el libro y el
  motivo; en el formulario de edición, el interruptor "Compartir en el feed" aparece deshabilitado y
  explica por qué.
- [ ] **Suspensión automática (D5):** al recibir una denuncia, contar personas distintas que denunciaron
  a la cuenta o a su contenido (denuncias no descartadas); al llegar a **10** → suspender con
  `source = 'reports'` (ver 4.2) y avisar al admin por correo.
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

### 4.2 Suspender (banear) y reactivar · M
Como administrador, quiero expulsar a quien incumple las reglas; y el sistema debe hacerlo solo ante
abuso evidente (D5).
- [ ] API: `POST /admin/users/:id/suspend` (`reason`, `report_id?`) y suspensión automática
  (`source = 'reports'`) comparten la misma función: `status = 'suspended'`, fila en `suspensions`,
  revoca todas las sesiones (refresh tokens + `status_changed_at` para invalidar accesos vigentes),
  su contenido deja de verse. `POST /admin/users/:id/reactivate`. No se puede suspender a un admin.
- [ ] `protect` rechaza cuentas suspendidas.
- [ ] Login de una cuenta suspendida → `403 ACCOUNT_SUSPENDED` con
  `{ reason, source, suspended_at, can_appeal, appeal_status, suspension_token }`
  (`suspension_token`: JWT corto y de propósito único; solo sirve para exportar y apelar).
- [ ] Correo al usuario: motivo, cómo exportar sus libros y cómo apelar.
- **Aceptación:** una cuenta suspendida no puede usar la API normal de ninguna forma; su contenido no se ve.

### 4.3 Exportar mi biblioteca estando suspendido · S
Como usuario suspendido, quiero llevarme mis libros y mis pensamientos.
- [ ] API: `GET /suspended/export?format=csv|json` con `suspension_token` → lecturas (título, autor,
  ISBN, estado, fechas, página, calificación, reseña, pública/privada) y sesiones de lectura.
- [ ] App: botón "Descargar mis libros" en la pantalla de cuenta suspendida (guardar/compartir el archivo).
- [ ] Web: mismo botón en `/apelar`.
- **Aceptación:** el archivo se abre en Excel/Sheets con tildes correctas (CSV UTF-8 con BOM).

### 4.4 Apelar una suspensión (una sola vez) · M
Como usuario suspendido, quiero pedir que se revise mi caso.
- [ ] API: `POST /suspended/appeal` con `suspension_token` + `message` (≤ 1000) → `suspension_appeals`
  (única por suspensión); segunda apelación → `409`.
- [ ] App: al intentar iniciar sesión, pantalla "Tu cuenta está suspendida" con el motivo (y si fue
  automática, que se debió a denuncias acumuladas), **Descargar mis libros** y **Apelar** (si
  `can_appeal`) → formulario → "Recibimos tu apelación"; si ya apeló, muestra el estado.
- [ ] Web: misma pantalla en `/apelar` (login → formulario).
- [ ] Correo al usuario con la resolución.
- **Aceptación:** exactamente una apelación por suspensión; el rechazo es definitivo.

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
  `/apelar` (4.3 y 4.4) · `/contacto`.
- **Aceptación:** HTML estático accesible (contraste AA, navegable con teclado), funciona en móvil.

### 5.3 Panel de administración `/admin` · L
Como administrador, quiero moderar desde el navegador.
- [ ] Login (solo `role = admin`; D2) y cierre de sesión.
- [ ] **Resumen**: denuncias abiertas, apelaciones pendientes, suspensiones activas (manuales y
  automáticas), reseñas bloqueadas, usuarios nuevos (7 días).
- [ ] **Denuncias**: lista filtrable (abiertas/resueltas, tipo, motivo), detalle con el contenido
  denunciado y el historial del usuario; acciones: *Descartar* (si la reseña estaba bloqueada por
  denuncias, se puede *desbloquear*), *Hacer privada permanente*, *Suspender usuario* (con motivo),
  cada una con confirmación y nota.
- [ ] **Apelaciones**: pendientes con la suspensión original (manual o automática, con sus denuncias) y
  el mensaje; *Aceptar* (reactiva) / *Rechazar* (definitivo) con nota.
- [ ] **Usuarios**: buscar por usuario/email, ver estado y denuncias recibidas, suspender / reactivar.
- [ ] **Auditoría**: listado de `admin_actions`.
- **Aceptación:** todo el flujo denuncia → privada / suspensión → apelación → resolución se hace sin SQL.

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
| **2** | 1.3 · 2.1 · 2.2 · 2.3 | Aceptación de términos, desactivar/reactivar y eliminar la cuenta (app + web) |
| **3** | 3.1 · 3.2 · 4.2 · 4.3 · 4.4 | Denunciar, bloquear, reseñas privadas, suspensión (manual y automática), exportar y apelar |
| **4** | 5.3 | Panel de administración completo |
| **5** | 6.1 · 6.2 · 6.3 | Datos protegidos |
| **6** | Épica 7 | App enviada a prueba cerrada en Google Play |

Al cerrar 1.1.0: actualizar `CHANGELOG.md`, `CLAUDE.md` (contrato de la API, nuevas pantallas),
la skill `auth-sesiones-seguras` si cambian los flujos de cuenta, y etiquetar `v1.1.0` en los repos.

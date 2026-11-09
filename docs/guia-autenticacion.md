# Guía: autenticación con refresh tokens y recuperación de contraseña

Receta para replicar en otros proyectos el sistema de sesión de LectorApp (v1.0.0):
**API Node.js + Express + MySQL** y **cliente Flutter**. Cada pieza explica *qué* hace y *por qué*,
para poder adaptarla a otro stack sin perder las garantías de seguridad.

> Código de referencia real: repo `Lectorapp API` (tag `v1.0.0`) y `test_lectorapp` (tag `v1.0.0`).
> Archivos clave: `src/services/auth.service.js`, `src/utils/tokens.js`, `src/utils/mailer.js`,
> `src/api/middlewares/auth.middleware.js`, `lib/services/api_client.dart`, `lib/services/auth_service.dart`.

---

## 1. Qué consigue

| Para el usuario | Para la seguridad |
|---|---|
| No vuelve a ver el login mientras use la app al menos una vez cada 60 días | Si roban un token de acceso, sirve como mucho 30 minutos |
| Un corte de red nunca lo saca de la sesión | Si roban un refresh token y se usa, se detecta y se cierra esa sesión completa |
| Puede recuperar la cuenta con un código por email | Nadie puede averiguar qué emails están registrados |
| Cerrar sesión funciona aunque el token ya haya vencido | Cambiar la contraseña cierra la sesión en todos los dispositivos |

## 2. El modelo en una imagen

```
LOGIN ──► { token (JWT, 30 min), refresh_token (opaco, 60 días), user }

App ── petición con token ──► API
          │ 401 o token vencido
          ▼
App ── POST /auth/refresh {refresh_token: R1} ──► API
          ◄── { token nuevo, refresh_token: R2 }      (R1 queda revocado: ROTACIÓN)

Si alguien presenta R1 otra vez ──► 401 + se revoca toda la "familia" (R1, R2, …)
                                    (el ladrón y el usuario deben volver a entrar)
```

- **Token de acceso**: JWT HS256 firmado, corto (30 min). Va en `Authorization: Bearer`.
  La API lo valida sin tocar la BD (salvo blacklist y usuario existente).
- **Refresh token**: 32 bytes aleatorios (`base64url`), **no es JWT**. En la BD solo se guarda su
  **SHA-256**. Solo sirve para pedir un acceso nuevo.
- **Familia**: todos los refresh que nacen de un mismo login comparten `family_id`. Es lo que
  permite revocar "la sesión" entera al detectar un reuso.

## 3. Base de datos (MySQL)

```sql
-- Sesiones largas
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  token_hash CHAR(64) NOT NULL UNIQUE,          -- SHA-256 del token, nunca el token
  family_id CHAR(36) NOT NULL,                  -- UUID por login
  expires_at DATETIME NOT NULL,
  revoked_at DATETIME NULL,
  replaced_by_id INT NULL,                      -- != NULL => fue rotado (reuso = robo)
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_refresh_user (user_id),
  INDEX idx_refresh_family (family_id),
  INDEX idx_refresh_expires (expires_at),
  CONSTRAINT fk_refresh_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Logout de tokens de acceso aún vigentes
CREATE TABLE IF NOT EXISTS token_blacklist (
  token VARCHAR(500) PRIMARY KEY,               -- SHA-256 del JWT
  expires_at DATETIME NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_blacklist_expires (expires_at)
);

-- Recuperación de contraseña
CREATE TABLE IF NOT EXISTS password_resets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  code_hash CHAR(64) NOT NULL,                  -- HMAC del código, nunca el código
  expires_at DATETIME NOT NULL,
  attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  used_at DATETIME NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_resets_user (user_id, used_at),
  CONSTRAINT fk_resets_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- Cuándo cambió la contraseña (SEGUNDOS UNIX, ver §9 "zona horaria")
ALTER TABLE users ADD COLUMN password_changed_at BIGINT UNSIGNED NULL;
```

Ejecutar esto con una **migración idempotente** (que se pueda correr varias veces: `CREATE TABLE IF NOT
EXISTS`, comprobar columnas en `information_schema` antes de `ALTER`) y lanzarla en cada deploy.

## 4. Contrato de la API

| Endpoint | Body | Respuesta | Notas |
|---|---|---|---|
| `POST /auth/register` | `{username, email, password}` | `201 {token, refresh_token, user}` | |
| `POST /auth/login` | `{email \| username, password}` | `{token, refresh_token, user}` | Mismo tiempo de respuesta exista o no el usuario |
| `POST /auth/refresh` | `{refresh_token}` | `{token, refresh_token}` | Rota. Reuso de uno rotado → 401 y familia revocada |
| `POST /auth/logout` | `{refresh_token?}` + `Authorization?` | `{success: true}` | Basta **uno** válido; si ninguno → 401 |
| `POST /auth/forgot-password` | `{email}` | `200 {message}` **siempre igual** | Envía código de 6 dígitos |
| `POST /auth/reset-password` | `{email, code, password}` | `{token, refresh_token, user}` | Cierra todas las demás sesiones |

Errores siempre como `{ "error": "mensaje para el usuario", "code": "UNAUTHORIZED" | "VALIDATION_ERROR" | "RATE_LIMITED" | ... }`.

**Rate limits** (por IP, con `express-rate-limit` y `app.set('trust proxy', 1)` detrás de Nginx):

| Ruta | Límite |
|---|---|
| login | 10 intentos **fallidos** / 5 min (`skipSuccessfulRequests`) |
| register | 10 / hora |
| refresh | 60 / 15 min |
| forgot-password | 5 / hora (+ enfriamiento de 60 s por cuenta) |
| reset-password | 10 / 15 min (+ máx. 5 intentos por código) |

## 5. API (Node.js + Express 5)

Dependencias: `jsonwebtoken`, `bcryptjs`, `zod`, `express-rate-limit`, `mysql2`, `nodemailer`.

### 5.1 Tokens — `src/utils/tokens.js`

```js
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const JWT_ALGORITHM = 'HS256';
const JWT_EXPIRES_IN = '30m';
const REFRESH_TOKEN_TTL_DAYS = 60;

// jti aleatorio: sin él, dos tokens del mismo usuario emitidos en el mismo segundo son IDÉNTICOS
// y revocar uno (blacklist por hash) revoca el otro.
const signToken = (userId) =>
  jwt.sign({ id: userId }, process.env.JWT_SECRET, {
    algorithm: JWT_ALGORITHM, expiresIn: JWT_EXPIRES_IN, jwtid: crypto.randomUUID(),
  });

// Fijar el algoritmo evita ataques de confusión de algoritmo.
const verifyToken = (token) =>
  jwt.verify(token, process.env.JWT_SECRET, { algorithms: [JWT_ALGORITHM] });

const hashToken = (token) => crypto.createHash('sha256').update(token).digest('hex');
const generateRefreshToken = () => crypto.randomBytes(32).toString('base64url');

const extractBearerToken = (req) => {
  const h = req.headers.authorization || '';
  return h.startsWith('Bearer ') ? h.slice(7).trim() || null : null;
};

module.exports = { signToken, verifyToken, hashToken, generateRefreshToken,
  extractBearerToken, REFRESH_TOKEN_TTL_DAYS };
```

`JWT_SECRET`: mínimo 32 caracteres aleatorios; validar al arrancar y **no** levantar la API si es corto
(`node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"`).

### 5.2 Emitir una sesión

```js
async function issueSession(userId, { conn = db, familyId = crypto.randomUUID() } = {}) {
  const refreshToken = generateRefreshToken();
  const [r] = await conn.execute(
    `INSERT INTO refresh_tokens (user_id, token_hash, family_id, expires_at)
     VALUES (?, ?, ?, NOW() + INTERVAL ? DAY)`,
    [userId, hashToken(refreshToken), familyId, REFRESH_TOKEN_TTL_DAYS]
  );
  return { session: { token: signToken(userId), refresh_token: refreshToken }, refreshId: r.insertId };
}
```

Login, registro y reset devuelven `{ user, ...session }`.

### 5.3 Login sin filtrar qué usuarios existen

```js
// Hash falso: bcrypt.compare se ejecuta SIEMPRE, así el login tarda lo mismo exista o no la cuenta.
const DUMMY_HASH = bcrypt.hashSync('dummy-password-for-timing-safety', 10);

const user = email ? await Users.findByEmail(email) : await Users.findByUsername(username);
const ok = await bcrypt.compare(password, user ? user.password_hash : DUMMY_HASH);
if (!user || !ok) throw new UnauthorizedError('Credenciales inválidas'); // mismo mensaje en ambos casos
```

Normalizar el email (`trim().toLowerCase()`) en el validador de registro **y** de login/recuperación.
Contraseña: mínimo 8 caracteres y **máximo 72 bytes** (bcrypt ignora en silencio lo que pase de ahí).

### 5.4 Refresh con rotación y detección de robo

```js
async refresh({ refresh_token }) {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [rows] = await conn.execute(
      `SELECT id, user_id, family_id, revoked_at, replaced_by_id, expires_at > NOW() AS alive
       FROM refresh_tokens WHERE token_hash = ? FOR UPDATE`,          // FOR UPDATE: sin carreras
      [hashToken(refresh_token)]
    );
    const cur = rows[0];
    if (!cur || !cur.alive || cur.revoked_at) {
      if (cur && cur.revoked_at && cur.replaced_by_id) {            // ya rotado => alguien lo copió
        await conn.execute(
          'UPDATE refresh_tokens SET revoked_at = NOW() WHERE family_id = ? AND revoked_at IS NULL',
          [cur.family_id]);
      }
      await conn.commit();
      throw new UnauthorizedError('Tu sesión expiró. Inicia sesión de nuevo.');
    }
    const user = await Users.findById(cur.user_id);
    if (!user) { await conn.commit(); throw new UnauthorizedError('Tu sesión expiró. Inicia sesión de nuevo.'); }

    const { session, refreshId } = await issueSession(user.id, { conn, familyId: cur.family_id });
    await conn.execute('UPDATE refresh_tokens SET revoked_at = NOW(), replaced_by_id = ? WHERE id = ?',
      [refreshId, cur.id]);
    await conn.commit();
    return session;
  } catch (e) {
    await conn.rollback().catch(() => {});
    throw e;
  } finally {
    conn.release();
  }
}
```

### 5.5 Middleware `protect`

```js
const token = extractBearerToken(req);
if (!token) return next(new UnauthorizedError('No autorizado, falta token'));
let decoded;
try { decoded = verifyToken(token); }                 // 1. barato, sin BD
catch { return next(new UnauthorizedError('Token no autorizado o expirado')); }
try {
  const [revoked] = await db.execute('SELECT 1 FROM token_blacklist WHERE token = ? LIMIT 1',
    [hashToken(token)]);                                // 2. ¿logout?
  if (revoked.length) return next(new UnauthorizedError('Token revocado'));
  const user = await Users.findById(decoded.id);       // 3. ¿existe?
  if (!user) return next(new UnauthorizedError('Usuario no encontrado'));
  if (user.password_changed_at && decoded.iat < Number(user.password_changed_at)) {   // 4. ¿cambió la clave?
    return next(new UnauthorizedError('La contraseña cambió. Inicia sesión de nuevo.'));
  }
  delete user.password_changed_at;
  req.user = user; req.token = token; next();
} catch (e) { next(e); }   // error de BD => 500, NO 401 (una caída de MySQL no debe cerrar sesiones)
```

### 5.6 Logout que funciona con el acceso vencido

```js
async logout({ accessToken, refreshToken }) {
  let did = false;
  if (accessToken) {
    try {
      verifyToken(accessToken);
      const { exp } = jwt.decode(accessToken);
      await db.execute('INSERT IGNORE INTO token_blacklist (token, expires_at) VALUES (?, ?)',
        [hashToken(accessToken), new Date(exp * 1000)]);
      did = true;
    } catch { /* vencido: basta el refresh */ }
  }
  if (refreshToken) {
    const [r] = await db.execute('SELECT family_id FROM refresh_tokens WHERE token_hash = ?', [hashToken(refreshToken)]);
    if (r[0]) {
      await db.execute('UPDATE refresh_tokens SET revoked_at = NOW() WHERE family_id = ? AND revoked_at IS NULL', [r[0].family_id]);
      did = true;
    }
  }
  if (!did) throw new UnauthorizedError('No autorizado, falta token'); // nadie llena la blacklist con basura
  return { success: true };
}
```

La ruta `/auth/logout` **no** lleva `protect` (por eso funciona con el acceso vencido).

### 5.7 Recuperación de contraseña

```js
const RESET_TTL_MIN = 15, MAX_ATTEMPTS = 5, COOLDOWN_S = 60;
const INVALID = 'El código no es válido o ya venció. Pide uno nuevo.';

// HMAC con el secreto del servidor: si se filtra la tabla, 6 dígitos no se pueden adivinar offline.
const hashResetCode = (userId, code) =>
  crypto.createHmac('sha256', process.env.JWT_SECRET).update(`${userId}:${code}`).digest('hex');

async requestPasswordReset({ email }) {
  const user = await Users.findByEmail(email);
  if (!user) return;                                     // el controlador responde lo MISMO siempre
  const [recent] = await db.execute(
    'SELECT 1 FROM password_resets WHERE user_id = ? AND created_at > (NOW() - INTERVAL ? SECOND) LIMIT 1',
    [user.id, COOLDOWN_S]);
  if (recent.length) return;
  const code = crypto.randomInt(0, 1_000_000).toString().padStart(6, '0');
  await db.execute('UPDATE password_resets SET used_at = NOW() WHERE user_id = ? AND used_at IS NULL', [user.id]);
  await db.execute(
    'INSERT INTO password_resets (user_id, code_hash, expires_at) VALUES (?, ?, NOW() + INTERVAL ? MINUTE)',
    [user.id, hashResetCode(user.id, code), RESET_TTL_MIN]);
  // SIN await: el tiempo de respuesta no delata si la cuenta existe.
  sendMail({ to: user.email, ...resetEmail(user.username, code) })
    .catch((e) => logger.error({ err: e, userId: user.id }, 'No se pudo enviar el correo'));
}

async resetPassword({ email, code, password }) {
  const user = await Users.findByEmail(email);
  if (!user) throw new ValidationError(INVALID);
  const [rows] = await db.execute(
    `SELECT id, code_hash, attempts FROM password_resets
     WHERE user_id = ? AND used_at IS NULL AND expires_at > NOW() ORDER BY id DESC LIMIT 1`, [user.id]);
  const reset = rows[0];
  if (!reset || reset.attempts >= MAX_ATTEMPTS) throw new ValidationError(INVALID);
  const a = Buffer.from(reset.code_hash, 'hex'), b = Buffer.from(hashResetCode(user.id, code), 'hex');
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    await db.execute('UPDATE password_resets SET attempts = attempts + 1 WHERE id = ?', [reset.id]);
    throw new ValidationError(INVALID);
  }
  const hash = await bcrypt.hash(password, 10);
  // En UNA transacción: nueva clave + password_changed_at (segundos Unix) + códigos usados
  //                     + revocar TODOS los refresh_tokens del usuario.
  // Luego: return { user, ...(await issueSession(user.id)).session };
}
```

**Correo** (`nodemailer`, SMTP genérico): `SMTP_HOST`, `SMTP_PORT` (465 = TLS directo), `SMTP_USER`,
`SMTP_PASS`, `MAIL_FROM`. En tests no se envía nada (se guarda en un array `outbox` que los tests leen);
en desarrollo sin SMTP se escribe el correo en el log. Para correos de app usar un servicio
transaccional (ZeptoMail, Brevo, Resend, SES) con un **subdominio verificado por DNS**
(p. ej. `noreply@app.tudominio.cl`), no un buzón personal.

### 5.8 Mantenimiento

Tarea periódica (cron o `node scripts/cleanup_tokens.js`):

```sql
DELETE FROM token_blacklist WHERE expires_at < NOW();
DELETE FROM refresh_tokens WHERE expires_at < NOW() OR revoked_at < (NOW() - INTERVAL 30 DAY);
-- (los revocados se guardan 30 días para poder detectar el reuso de uno rotado)
```

## 6. Cliente Flutter

Dependencias: `http`, `flutter_secure_storage`, `shared_preferences`.

### 6.1 `ApiClient`: renovación automática

Reglas que importan:

1. **Toda** petición pasa por un único cliente (`ApiClient`, singleton).
2. Tokens en `FlutterSecureStorage` (`auth-token`, `refresh-token`) y **cacheados en memoria** (se leen una vez al arrancar).
3. **Antes** de una petición autenticada: si el JWT venció (leer `exp`, con 30 s de margen) y hay refresh → renovar primero.
4. Si llega **401**: renovar **una** vez y reintentar la petición **una** vez.
5. **Single-flight**: si 5 peticiones fallan a la vez, se hace **una** sola renovación (un `Future` compartido).
6. Solo si la API **rechaza** el refresh (401/400) → borrar sesión e ir a Login. Si falla la **red** o el servidor (5xx/429) → lanzar error normal y **conservar** la sesión.
7. Login/registro/logout/recuperación usan `redirectOn401: false` (ahí un 401 es "credenciales inválidas").

```dart
Future<bool>? _refreshing;

Future<dynamic> _send(String method, String path,
    {Map<String, dynamic>? body, bool redirectOn401 = true}) async {
  final authenticated = redirectOn401;

  if (authenticated && isAccessTokenExpired(await getToken()) && await getRefreshToken() != null) {
    try { await _refreshSession(); } on ApiException { /* sin red: se intenta igual */ }
  }

  var response = await _request(method, path, body);

  if (response.statusCode == 401 && authenticated) {
    if (await _refreshSession()) response = await _request(method, path, body); // red caída => lanza
    if (response.statusCode == 401) {
      await _handleSessionExpired();   // clearSession + Login (con guard contra dobles navegaciones)
      throw ApiException('Tu sesión expiró. Inicia sesión de nuevo.', statusCode: 401);
    }
  }
  return _parse(response);
}

Future<bool> _refreshSession() =>
    _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

Future<bool> _doRefresh() async {
  final rt = await getRefreshToken();
  if (rt == null) return false;
  final res = await _request('POST', '/auth/refresh', {'refresh_token': rt}); // sin Authorization
  if (res.statusCode == 200) {
    final d = json.decode(res.body);
    await setSession(token: d['token'], refreshToken: d['refresh_token']);
    return true;
  }
  if (res.statusCode == 401 || res.statusCode == 400) return false;   // sesión terminada de verdad
  throw ApiException(extractErrorMessage(res.statusCode, res.body), statusCode: res.statusCode);
}
```

`_request` convierte `TimeoutException`, `SocketException` y `ClientException` en `ApiException`
con `statusCode: 0` y un mensaje amable. Timeout: 15 s. Un único `http.Client` reutilizado (keep-alive).

### 6.2 Arranque sin esperar a la red

```dart
await ApiClient().loadToken();
final token = await ApiClient().getToken();
final refresh = await ApiClient().getRefreshToken();
final hasSession = AuthService.isJwtValid(token) || refresh != null;
if (token != null && !hasSession) await ApiClient().clearSession();
runApp(App(initialScreen: hasSession ? const HomeScreen() : const LoginScreen()));
// La primera petición renueva sola si hace falta.
```

### 6.3 `AuthService`

- `login` / `register` / `resetPassword` → `ApiClient().setSession(token: d['token'], refreshToken: d['refresh_token'])`.
  Guardar en `SharedPreferences` solo lo mínimo para la UI (id, username, avatar), **nunca** el email ni tokens.
- `logout`: `POST /auth/logout` con `{'refresh_token': …}` y `redirectOn401: false`; si falla la red, igual
  `clearSession()` local.
- Pantalla "¿Olvidaste tu contraseña?": paso 1 email → paso 2 código (teclado numérico,
  `AutofillHints.oneTimeCode`) + contraseña nueva con mostrar/ocultar; error del código **junto al campo**;
  "Reenviar código" con cuenta atrás de 60 s; al terminar, entrar directo a la app.

## 7. Tests a replicar

**API (E2E con Jest + supertest contra una BD de test):**
- login devuelve `refresh_token` y el JWT dura 30 min (`exp - iat === 1800`)
- dos logins seguidos dan tokens **distintos**; logout de uno no afecta al otro
- refresh rota (token nuevo distinto) y el acceso nuevo funciona
- reusar un refresh ya rotado → 401 **y** el más nuevo de la familia también queda revocado
- logout solo con refresh (acceso vencido) → 200 y el refresh deja de servir
- refresh inexistente → 401; con formato inválido → 400
- forgot-password: email inexistente responde igual y no envía nada; email existente envía 6 dígitos;
  segundo pedido antes de 60 s no envía
- reset: código malo → 400; correcto → sesión nueva, el token viejo da 401, la clave vieja ya no
  sirve, el código no se reutiliza; tras 5 fallos el código queda bloqueado aunque luego se acierte
- reset revoca los refresh tokens anteriores

**Flutter (con `MockClient` de `package:http/testing.dart`, `FlutterSecureStorage.setMockInitialValues`):**
- acceso vencido + refresh → renueva **antes** (ningún 401 de por medio) y guarda el refresh rotado
- 401 → renueva y reintenta una vez
- 3 peticiones simultáneas → **1** sola llamada a `/auth/refresh`
- refresh rechazado (401) → sesión local borrada
- servidor caído al renovar (503) → la sesión se conserva

Truco: hacer el `http.Client` del singleton reemplazable con un setter `@visibleForTesting`, y crear el
singleton **dentro** de cada test (no en `main()` del archivo de test: falla por la zona de pruebas).

## 8. Variables de entorno

| Variable | Uso |
|---|---|
| `JWT_SECRET` | ≥ 32 caracteres aleatorios. Cambiarlo invalida todos los tokens de acceso |
| `TRUST_PROXY=1` | IP real detrás de Nginx (sin esto el rate limit ve una sola IP) |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `MAIL_FROM` | Correo de recuperación |
| `NODE_ENV=production` | Sin detalles de errores al cliente |

Secretos en un `.env` fuera de git (`chmod 600`). En Docker Compose, pasarlos explícitamente en
`environment:` del servicio de la API.

## 9. Errores que ya cometimos (y cómo se evitan)

| Problema | Síntoma | Solución |
|---|---|---|
| JWT sin `jti` | Dos tokens emitidos en el mismo segundo son idénticos; un logout cierra la sesión de otro dispositivo; tests intermitentes | `jwtid: crypto.randomUUID()` |
| Fecha de cambio de clave como `DATETIME` | Si MySQL y Node usan zonas horarias distintas, el token nuevo tras el reset se rechaza durante horas | Guardar `password_changed_at` en **segundos Unix** desde Node y comparar con `iat` |
| Logout protegido con `protect` | Con el acceso vencido no se puede cerrar sesión en el servidor | Logout acepta el refresh token sin `protect` |
| Renovaciones simultáneas | Dos peticiones renuevan a la vez, la segunda usa un refresh ya rotado → se revoca la sesión | Single-flight en el cliente (`_refreshing`) |
| Cerrar sesión ante cualquier error | Un corte de red o un 502 saca al usuario | Solo 401/400 del refresh cierran sesión |
| `await` del envío de correo | El tiempo de respuesta revela si el email existe | Enviar sin esperar (`.catch` + log) |
| Error de BD en `protect` como 401 | Una caída de MySQL desconecta a todos | Propagar como 500 |
| Express 5 sin body | `req.body` es `undefined` y la validación falla | `schema.parse(req.body ?? {})` |
| Mensajes distintos para "no existe" / "clave mala" | Enumeración de usuarios | Un solo mensaje: "Credenciales inválidas" |

## 10. Checklist para un proyecto nuevo

- [ ] Tablas `refresh_tokens`, `token_blacklist`, `password_resets` y `users.password_changed_at` (migración idempotente)
- [ ] `tokens.js` con `jti`, HS256 fijo, acceso 30 min, refresh opaco + SHA-256
- [ ] `issueSession` usado por register, login y reset
- [ ] `/auth/refresh` con transacción `FOR UPDATE`, rotación y revocación de familia
- [ ] `/auth/logout` sin `protect`, acepta acceso y/o refresh
- [ ] `protect`: firma → blacklist → usuario → `password_changed_at`; errores de BD = 500
- [ ] Recuperación: respuesta idéntica, cooldown, HMAC, TTL, intentos, uso único, envío sin `await`
- [ ] Rate limits por ruta + `trust proxy`
- [ ] Validación con Zod (email normalizado, contraseña 8–72 bytes)
- [ ] SMTP transaccional con subdominio verificado
- [ ] Limpieza periódica de tokens
- [ ] Cliente: un solo `ApiClient`, tokens en almacenamiento seguro + memoria, renovación proactiva y ante 401, single-flight, no cerrar sesión por errores de red
- [ ] Arranque: sesión = JWT vigente **o** refresh guardado
- [ ] Todos los tests de §7

# Pendientes de LectorApp

Tareas conocidas que **no bloquean el desarrollo** y se retoman más adelante.
Última revisión: 2026-11-08.

## Antes de publicar (no urgentes mientras estemos en desarrollo)

- [ ] **Rotar la clave de ZeptoMail.** La "Contraseña 1" (Send Mail token) quedó escrita en una conversación.
  1. ZeptoMail → Agent *lectorapp* → SMTP/API → "Contraseña 1" → **+** (crear una nueva).
  2. Reemplazar `SMTP_PASS` en `/home/ubuntu/[LECTORAPP]/.env` del servidor (mantener `chmod 600`).
  3. Redesplegar la API (`deploy\deploy.bat` en el repo de la API) y comprobar el envío.
  4. Borrar la clave anterior (ícono rojo).
- [ ] **Firma de release de Android.** `android/app/build.gradle.kts` firma con las claves de *debug*.
  Crear un keystore propio y configurar `signingConfigs.release` antes de subir a Google Play
  ([guía de Flutter](https://docs.flutter.dev/deployment/android#sign-the-app)).
  El keystore y sus contraseñas **nunca** van al repositorio.
- [ ] **Contraseña root de MySQL en producción.** Tiene 5 caracteres. La BD solo escucha en `127.0.0.1`,
  así que el riesgo es bajo, pero conviene cambiarla por una larga y aleatoria (`.env` del servidor →
  `MYSQL_ROOT_PASSWORD` + `ALTER USER 'root'@...` dentro de `lectorDB`; respaldar antes).
- [ ] **Bundle ID de iOS.** Sigue siendo `com.example.helloWorld` (plantilla). Cambiarlo a
  `com.nacholoz3d.lectorapp` (como Android) en `ios/Runner.xcodeproj` antes de compilar para iPhone.

## Código (sprint)

- [ ] **Refresh tokens.** Hoy el JWT dura 7 días sin renovación: al vencer, el usuario debe volver a
  iniciar sesión aunque use la app a diario. Ver plan propuesto en la conversación del 2026-11-08
  (token de acceso corto + refresh token rotativo guardado como hash en BD).
- [ ] **Modelos tipados en el feed.** `HomeScreen` / `UserCard` usan `Map` crudos; migrar a `ReadingLog`
  (con `copyWith`) daría más seguridad de tipos.
- [ ] **Búsqueda local en la API.** `BookModel.searchLocal` usa `LIKE '%q%'` (escaneo completo).
  Con decenas de miles de libros, migrar a índice `FULLTEXT(title, author)`.
- [ ] **Dependencias de Flutter desactualizadas.** Varias tienen versión mayor nueva (`flutter pub outdated`);
  actualizar de a una, con pruebas.

## Diseño / UX (ideas para una próxima etapa)

- [ ] Colores fijos de los íconos de Estadísticas (azul/morado/naranja) → tokens del tema.
- [ ] Revisar la pantalla del cronómetro con las skills de diseño y accesibilidad (`/lectorapp-ui-review`).
- [ ] Aviso de "Sin conexión" sobre el contenido en caché.
- [ ] Opción "Usar el tema del sistema" además de los 4 temas.
- [ ] Tests automáticos de accesibilidad (`meetsGuideline`) en pantallas completas.

# Pendientes de LectorApp

Tareas conocidas que **no bloquean el desarrollo** y se retoman más adelante.
El trabajo planificado de la versión 1.1.0 (Google Play, moderación, web, cifrado) está en [`BACKLOG.md`](BACKLOG.md).
Última revisión: 2026-11-22.

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
- [ ] **Crear el buzón `contacto@nacholoz3d.cl`** en Zoho Mail: es el único contacto de Términos, Privacidad y `/contacto`.
- [ ] **Avatares y fuentes sin terceros.** La app pide avatares a DiceBear con el username (Play lo cuenta como
  compartir un ID de usuario) y descarga Google Fonts en tiempo de ejecución (Google recibe la IP). Generar
  avatares en el dispositivo y empaquetar Lora/Nunito (`GoogleFonts.config.allowRuntimeFetching = false`);
  luego quitarlo de la Política de privacidad y del formulario "Seguridad de los datos".
- [ ] **Mantenimiento del servidor:** programar `npm run cleanup` (cron; hoy `refresh_tokens` solo se limpia
  a mano), limpiar también `password_resets` (nunca se borran) y poner `max-size`/`max-file` al log de
  `lectorAPI`. Después, dar plazos concretos en `#conservacion` de la Política de privacidad.
- [ ] **Enlaces compartidos rotos.** La app comparte `https://nacholoz3d.cl/libro/<id>`, pero `nacholoz3d.cl`
  apunta a `landing_ventas` (404). Crear `/libro/<id>` en la web nueva y apuntar la app a `lector.nacholoz3d.cl`.
- [ ] **Textos legales vivos:** al terminar 1.3, 2.1–2.3, 3.x, 4.x, 5.3, 6.1 y 6.3, actualizar las frases de
  `/terminos` y `/privacidad` que hoy remiten al correo (lista en el informe de la tarea 1.1/1.2).
  Hecho para 2.1 (desactivar: `/terminos#desactivar` y la sección de derechos de `/privacidad`) y 2.2
  (eliminar desde la app: `/terminos` §8, `/privacidad` derechos/conservación y `/contacto`; el correo
  queda como alternativa) y 2.3 (`/eliminar-cuenta` enlazada en `/terminos` (suspensión y §8), `/privacidad`
  §3 —ahora menciona su único formulario—, encargados, conservación, derechos y seguridad, `/contacto`
  y el pie; versión 2026-11 sin cambio).
- [ ] **Eliminar cuenta, detalles (revisión 2.2):** (a) `admin_actions.note` se conserva al anonimizar;
  en la Épica 4 vaciarla o exigir que no identifique a la persona, para que la Privacidad siga siendo
  cierta. (b) Si se pierde la respuesta 200 del `DELETE /account`, la app muestra error y no limpia
  los borradores locales; separar la llamada HTTP de la limpieza local.
- [ ] **Códigos por correo (revisión 2.3):** un tercero puede bloquear 24 h (renovables) la recuperación
  y el borrado web de otra persona pidiendo 5 códigos al día (compromiso del tope por cuenta; desbloqueo
  manual en DEPLOY.md de la API). Si hay abuso, contar solo códigos con intentos fallidos. Además,
  `mailer.js` escribe el email en el log de error si falta SMTP.
- [ ] **Bundle ID de iOS.** Sigue siendo `com.example.helloWorld` (plantilla). Cambiarlo a
  `com.nacholoz3d.lectorapp` (como Android) en `ios/Runner.xcodeproj` antes de compilar para iPhone.

## Versión 1.0.1 — gestos de deslizamiento

- [ ] **Deslizar entre pestañas principales (Inicio · Biblioteca · Perfil)**, estilo Instagram.
  Cambiar el `IndexedStack` de `lib/screens/tabs_screen.dart` por un `PageView` con `PageController`:
  `onPageChanged` actualiza la barra inferior y tocar la barra hace `animateToPage`. Las pantallas ya
  conservan estado y scroll (`AutomaticKeepAliveClientMixin`). `PageView` decide la dirección del gesto
  al empezar, así que el scroll vertical del feed no cambia de pestaña por accidente; el gesto "atrás"
  de Android solo actúa desde el borde. `TabsScreen.select()` debe seguir funcionando (usar el controller).
- [ ] **Deslizar entre filtros de Mi biblioteca (Leyendo · Terminados · Lo dejé).**
  En `lib/screens/library_screen.dart`, cambiar el `SegmentedButton` por `TabBar` + `TabBarView`
  (o un `PageView` sincronizado con los segmentos). Dentro de Biblioteca el gesto lo toman los filtros:
  al llegar al último filtro no se pasa a Perfil (igual que un carrusel dentro de Instagram).
  Mantener los contadores en las etiquetas y la tarjeta "Empezar a leer" en el filtro Leyendo.
- Probar ambos en el teléfono (no solo en Chrome): diagonales al hacer scroll, gesto atrás desde el
  borde y TalkBack (las pestañas deben seguir siendo botones con nombre).

## Código (sprint)

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

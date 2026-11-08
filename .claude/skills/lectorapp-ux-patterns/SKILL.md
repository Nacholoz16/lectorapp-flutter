---
name: lectorapp-ux-patterns
description: Experiencia de usuario y escritura de interfaz (UX writing) de LectorApp — voz y tono en español, mensajes de error/éxito, estados vacíos, de carga y sin conexión, formularios de registro y reseña que nunca pierden lo escrito, privacidad por defecto, confirmaciones y "deshacer", navegación y feedback háptico. Usar al diseñar o cambiar un flujo (registrar lectura, editar, borrar, buscar, perfil, cronómetro, login), al escribir cualquier texto visible para el usuario (títulos, botones, SnackBars, diálogos, placeholders), o cuando se pida que la app sea "intuitiva", "amigable" o "cómoda".
---

# Patrones de UX de LectorApp

LectorApp es **un lugar para guardar lo que piensas de lo que lees**. Cada decisión responde a tres preguntas:
1. **¿Se siente seguro?** Nada de lo que escribo se pierde y nada se publica sin que yo quiera.
2. **¿Se siente tranquilo?** Sin presión, sin ruido, sin culpa (el "reto anual" anima, no regaña).
3. **¿Es obvio qué hacer?** Una acción principal por pantalla, con nombres claros.

## 1. Voz y tono

- **Tuteo, cálido y breve.** Como una amiga librera: cercana pero que sabe de lo que habla. Ni corporativo ("Se ha producido un error en la operación") ni infantil ("¡Ups! 🙈").
- **Verbos concretos en botones:** "Guardar lectura", "Publicar reseña", "Empezar a leer" en lugar de "Aceptar", "OK" o "Enviar".
- **Español neutro**, sin anglicismos innecesarios ("Compartir", no "Share"; "Me gusta", no "Like").
- **Mayúscula solo inicial** en títulos y botones ("Mi biblioteca", no "Mi Biblioteca" ni "MI BIBLIOTECA").
- **Emojis:** como mucho uno, en momentos de celebración (terminar un libro, cumplir el reto). Nunca en errores.
- **No culpar al usuario:** "No pudimos guardar tu reseña" en vez de "Ingresaste datos inválidos".

| En vez de | Escribe |
|---|---|
| `Error al guardar: Exception: …` | No pudimos guardar tu lectura. Revisa tu conexión e inténtalo de nuevo. |
| `Error: $e` | (mensaje humano + botón **Reintentar**) |
| LEYENDO / TERMINADO / ABANDONADO | Leyendo · Terminado · Lo dejé (solo la etiqueta visible: el valor enviado a la API sigue siendo `leyendo`/`terminado`/`abandonado`) |
| Registrar Lectura | Añadir a mi biblioteca |
| ¿Qué te pareció? Comparte tu opinión... | ¿Qué te dejó este libro? Escribe lo que quieras recordar… |
| Privado / Público (switch) | Solo para mí / Compartir en el feed |
| Sin resultados | No encontramos "{q}". Prueba con el autor o menos palabras. |

## 2. Mensajes y feedback

- **Un solo helper** para mensajes (p. ej. `lib/ui/feedback.dart`: `showSuccess(context, msg)`, `showError(context, error, {onRetry})`), con un estilo común (flotante, radio 12, colores de tokens). Hoy hay 28 `SnackBar` armados a mano, con `Colors.red` y `$e` crudo.
- **Errores:** nunca mostrar `e.toString()` de una excepción que no sea `ApiException`. Traducir según el tipo: sin conexión (statusCode 0), 409 ("Ya tienes este libro en tu biblioteca"), 429 ("Vas muy rápido; espera un momento") y el genérico como respaldo. Siempre ofrecer **Reintentar** si tiene sentido.
- **Éxito:** confirmación breve y específica ("Guardado en tu biblioteca"), sin modales que haya que cerrar.
- **Háptica sutil:** `HapticFeedback.lightImpact()` al dar me gusta, guardar o terminar un libro; `selectionClick()` al elegir estrellas o estado. Nunca en scroll.
- **Optimistic UI** (ya existe en los me gusta): extenderla a editar estado y página, revirtiendo con un mensaje si falla.

## 3. Proteger lo que el usuario escribe

Es la regla más importante para una app de pensamientos:
- **Borrador automático** de reseñas: guardar en `SharedPreferences` (clave por `external_id`/`logId`) con un debounce de unos 1 s y restaurar al reabrir el modal ("Recuperamos tu borrador" + Descartar).
- **Al cerrar con cambios sin guardar** (X, gesto atrás, deslizar la hoja): preguntar "¿Descartar los cambios?" con las opciones **Seguir editando** (principal) y Descartar. En Flutter: `PopScope(canPop: !dirty, onPopInvokedWithResult: …)` y `isDismissible`/`enableDrag` condicionados en la hoja.
- **Si falla el guardado, el texto se queda** en el formulario; nunca cerrar la hoja ante un error.
- Mostrar el contador de caracteres cerca del límite (`maxLength: 5000`, visible a partir de unos 4500).
- Campo de reseña amplio (`minLines: 5`, `maxLines: null`), con `textCapitalization: TextCapitalization.sentences`.

## 4. Privacidad por defecto y explícita

- Las lecturas nuevas son **privadas por defecto** (ya es así). El switch dice qué significa cada estado: "Solo para mí" (🔒) y "Visible en el feed y en tu perfil" (🌐).
- Antes de publicar por primera vez, explicar una sola vez qué verá la gente.
- En el perfil, mostrar claramente qué es público y qué no, con candado.
- Compartir (`share_plus`) solo lleva el enlace del libro, nunca la reseña privada.

## 5. Acciones destructivas

- **Borrar un registro:** preferir **"Deshacer"** (SnackBar de unos 6 s) a un diálogo. Si se usa diálogo, el título dice qué se pierde ("¿Eliminar *El nombre del viento* de tu biblioteca? Se borrarán tu reseña y tus sesiones de lectura.") y el botón destructivo dice "Eliminar", en color `danger`, sin ser el estilo principal.
- **Cerrar sesión:** confirmación ligera; no borrar borradores locales sin avisar.

## 6. Estados de pantalla (todas las listas y cargas)

Cada pantalla que carga datos contempla los **5 estados**:

| Estado | Qué mostrar |
|---|---|
| Cargando por primera vez | *Skeletons* con la forma de las tarjetas (no un spinner centrado en pantalla vacía). `BookLoader` solo en cargas largas o pantallas completas. |
| Con datos | El contenido. Cargas posteriores: indicador pequeño al final de la lista. |
| Vacío | Ícono o ilustración + título amable + una acción. Feed vacío: "Aún no hay lecturas compartidas" + **Buscar un libro**. Biblioteca vacía: "Tu biblioteca está esperando su primer libro" + **Buscar libros**. |
| Error | Mensaje humano + **Reintentar**, conservando los datos en caché si los hay. |
| Sin conexión | Banner discreto "Sin conexión · mostrando lo último guardado" sobre la caché (el feed ya tiene caché). |

- `RefreshIndicator` en todas las listas principales.
- No mover el contenido bajo el dedo: los "X publicaciones nuevas" se ofrecen con un banner que el usuario toca; no se insertan solas.

## 7. Formularios (registrar o editar lectura, login, registro)

- **Pedir solo lo necesario primero.** Para registrar basta con el estado. Página, fechas, calificación y reseña son opcionales y se pueden completar después. El botón Guardar siempre está habilitado.
- **Mostrar solo lo que aplica:** calificación para terminado/abandonado; página actual para leyendo; fecha de fin para terminado (ya se hace).
- **Valores por defecto inteligentes:** fecha de inicio = hoy al elegir "Leyendo"; fecha de fin = hoy al marcar "Terminado".
- **Validación en línea, al salir del campo,** no al pulsar Guardar: página > total, fin < inicio, formato de email, contraseña ≥ 8.
- **Botón principal abajo** dentro del alcance del pulgar (no solo un "Guardar" pequeño en el AppBar), con estado de carga dentro del botón.
- Teclado: `TextInputAction.next` entre campos y `done` en el último; en login, `AutofillGroup` + `autofillHints`.

## 8. Navegación e intuición

- **Tres pestañas claras** (Inicio · Buscar · Perfil), con ícono **y** etiqueta siempre visibles. Volver a tocar la pestaña activa sube al inicio de la lista.
- Lo que se puede tocar parece tocable (avatar → perfil, portada → detalle), con feedback de pulsación (`InkWell`).
- Profundidad máxima de 2 niveles desde una pestaña. Las tareas cortas van en hojas inferiores; las vistas de contenido, en pantallas.
- **El gesto atrás siempre funciona** y nunca pierde datos sin preguntar (ver §3).
- **Primera vez (onboarding mínimo):** después de registrarse, una pantalla de bienvenida con la acción "Busca el libro que estás leyendo". Nada de carruseles de 5 pasos.

## 9. Comodidad de lectura

- Las reseñas largas se leen en un ancho cómodo (máx. ~65 caracteres por línea en tablets: `ConstrainedBox(maxWidth: 600)`), con interlineado 1.5–1.6 y sin cursiva en bloques.
- El tema oscuro es cálido (Café de Medianoche) para leer de noche; ofrecer "Usar el tema del sistema" como opción además de los 4 temas.
- El reto anual habla en positivo: "Llevas 7 de 12 libros 🌱", nunca "Vas atrasado".

## 10. Checklist de UX para cada cambio

- [ ] Los textos siguen la voz (tuteo, verbos concretos, sin errores técnicos crudos).
- [ ] Contempla carga, vacío, error y sin conexión.
- [ ] Lo escrito por el usuario no se pierde al cerrar, al fallar ni al ir atrás.
- [ ] Hay una sola acción principal, clara y alcanzable con el pulgar.
- [ ] Lo destructivo tiene Deshacer o confirmación explícita.
- [ ] Lo público y lo privado se ven claramente.
- [ ] Cumple la skill `lectorapp-accessibility`.

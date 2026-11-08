---
name: lectorapp-accessibility
description: Accesibilidad en LectorApp (Flutter, Android) — lectores de pantalla (TalkBack) con Semantics, objetivos táctiles de 48 dp, texto escalable al 200 %, contraste WCAG 2.2 AA, no depender solo del color, foco visible, movimiento reducido y tests automáticos con meetsGuideline. Usar al crear o revisar cualquier widget interactivo (botones de ícono, estrellas, me gusta, chips, switches, sliders, cronómetro, gestos) o cuando se pida "accesibilidad", "TalkBack", "lector de pantalla", "letra grande" o "contraste".
---

# Accesibilidad en LectorApp

Objetivo: **WCAG 2.2 nivel AA** y las guías de accesibilidad de Android. Una persona con TalkBack, con letra al 200 % o con baja visión debe poder registrar un libro, escribir su reseña y leer el feed sin ayuda.

Estado medido (2026-11): 0 widgets `Semantics`, 2 tooltips para 13 `IconButton`, 6 `GestureDetector` sobre avatares/nombres (sin rol de botón ni tamaño mínimo), estrellas de calificación sin etiqueta, colores de texto bajo 4.5:1 (ver `lectorapp-design-system` §1) y foco de inputs invisible.

## 1. Lector de pantalla (TalkBack)

Reglas:
- **Todo `IconButton` lleva `tooltip:`.** Flutter lo usa como etiqueta accesible y además muestra la ayuda al mantener pulsado.
  ```dart
  IconButton(icon: const Icon(Icons.close), tooltip: 'Cerrar', onPressed: …)
  ```
- **Íconos decorativos** (adornos junto a un texto que ya dice lo mismo): `excludeFromSemantics` o `ExcludeSemantics`.
- **Imágenes con significado:** portada → `semanticLabel: 'Portada de $title'`; avatar → `'Foto de perfil de $username'`.
- **Agrupar lo que es una sola cosa.** Una tarjeta del feed debe leerse como una frase y no como 12 fragmentos:
  ```dart
  MergeSemantics(child: …)
  // o:
  Semantics(
    label: '$username terminó $title de $author. Calificación $rating de 5. ${review ?? ''}',
    child: ExcludeSemantics(child: contenidoVisual),
  )
  ```
  Las acciones (me gusta, compartir, ver libro) quedan **fuera** del `ExcludeSemantics` para que sigan enfocables.
- **Controles personalizados** (estrellas, me gusta, selector de estado, cronómetro): declarar rol y estado.
  ```dart
  // Estrellas de calificación: un solo control ajustable, no 5 botones mudos
  Semantics(
    label: 'Calificación',
    value: rating == 0 ? 'Sin calificar' : '$rating de 5 estrellas',
    increasedValue: '${(rating + 1).clamp(1, 5)} de 5 estrellas',
    decreasedValue: '${(rating - 1).clamp(0, 5)} de 5 estrellas',
    onIncrease: () => setRating(rating + 1),
    onDecrease: () => setRating(rating - 1),
    child: ExcludeSemantics(child: filaDeEstrellas),
  )

  // Me gusta: botón con estado
  Semantics(
    button: true, toggled: hasLiked,
    label: hasLiked ? 'Quitar me gusta' : 'Me gusta',
    value: '$likes me gusta',
    child: …,
  )
  ```
- **Progreso de lectura:** `LinearProgressIndicator(semanticsLabel: 'Progreso de lectura', semanticsValue: '$percentage %')`.
- **Cronómetro:** el texto que cambia cada segundo **no** debe anunciarse cada segundo. Envolver en `ExcludeSemantics` y exponer un `Semantics(label: 'Tiempo de lectura', value: '12 minutos')` que solo cambie por minuto. Los botones play/pausa llevan tooltip y etiqueta según el estado ('Pausar cronómetro' / 'Reanudar cronómetro').
- **Cambios importantes** (guardado, error, "3 publicaciones nuevas"): además del SnackBar, `SemanticsService.sendAnnouncement(View.of(context), msg, TextDirection.ltr)` cuando el foco no esté en el mensaje (`announce` está deprecado desde Flutter 3.3x; el proyecto usa 3.44).
- **Encabezados:** los títulos de sección llevan `Semantics(header: true, …)` para que TalkBack pueda saltar entre ellos.
- **Textos que no se leen bien:** las fechas tipo "nov 8" se pueden leer completas con `Semantics(label: '8 de noviembre')`. Los estados en MAYÚSCULAS se deletrean, así que se escriben con mayúscula inicial.
- **Cambiar `GestureDetector` por `InkWell`** (o `Semantics(button: true, onTap:)`) en avatares y nombres que navegan: así se anuncian como botón y muestran feedback.

## 2. Tamaño de objetivos táctiles

- Mínimo **48 × 48 dp** para todo lo que se toca, aunque el ícono visible sea de 20 dp (`IconButton` ya lo cumple; `GestureDetector` y `InkWell` pequeños no).
- Separación de al menos 8 dp entre objetivos (por ejemplo, las 5 estrellas).
- No usar `VisualDensity.compact` ni `MaterialTapTargetSize.shrinkWrap` en controles interactivos.

## 3. Texto escalable

- **Nunca** fijar `textScaler`/`textScaleFactor` ni `MediaQuery(textScaler: TextScaler.noScaling)`.
- Diseñar para **200 %**: nada de alturas fijas en contenedores con texto (`SizedBox(height: 40)` alrededor de un `Text`), usar `minHeight` y `Wrap` en vez de `Row` cuando el contenido pueda crecer, y `maxLines` + `overflow: TextOverflow.ellipsis` solo en títulos, nunca en la reseña completa.
- Probar en el teléfono: Ajustes → Pantalla → Tamaño de fuente → máximo. Desde adb: `adb shell settings put system font_scale 2.0` (volver con `1.0`).

## 4. Color y contraste

- Texto normal ≥ **4.5:1**; texto grande (≥ 18 sp, o ≥ 14 sp en negrita) ≥ **3:1**; íconos, bordes de inputs y controles ≥ **3:1** (WCAG 1.4.11).
- Usar los tokens `ink` / `textSecondary` de `lectorapp-design-system`. Los pasteles nunca van como color de texto.
- **No depender solo del color:** los estados llevan ícono y texto; el me gusta cambia de contorno a relleno, no solo de gris a rojo; los errores de formulario llevan texto, no solo un borde rojo.
- Calcular el contraste antes de introducir un color nuevo. En Dart, `Color.computeLuminance()` da la luminancia relativa WCAG:
  ```dart
  double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }
  ```
  Conviene un test unitario que recorra los 4 temas y verifique los pares texto/fondo del sistema de diseño.

## 5. Foco, teclado y formularios

- El foco de los inputs debe verse: `focusedBorder` con `BorderSide(color: ink, width: 2)`.
- Cada `TextField` lleva `labelText` (o una etiqueta visible asociada), no solo `hintText`, porque el hint desaparece al escribir.
- Usar el `keyboardType` y el `textInputAction` correctos (`next`/`done`) y `autofillHints` en login y registro (`AutofillHints.username`, `.email`, `.password`, `.newPassword`) dentro de un `AutofillGroup`.
- Los errores de validación se muestran con `errorText` junto al campo y se anuncian.
- El orden de lectura sigue el orden visual; si no, usar `FocusTraversalGroup` / `OrdinalSortKey`.

## 6. Movimiento y tiempo

- Si `MediaQuery.of(context).disableAnimations` es `true`, quitar las animaciones no esenciales (el loader 3D `BookLoader` debe tener una versión estática).
- Ningún mensaje importante debe desaparecer antes de poder leerse: los SnackBars con acción duran ≥ 6 s (o `persist`) y no hay timeouts que expulsen al usuario mientras escribe.

## 7. Tests automáticos (añadir en `test/`)

```dart
testWidgets('LoginScreen cumple guías de accesibilidad', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(MaterialApp(theme: tema, home: const LoginScreen()));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
});
```
Correr para cada tema (los 4) en las pantallas sin red (login, registro, modales con datos falsos). Las pantallas con red necesitan servicios simulados.

## 8. Prueba manual con TalkBack (5 minutos, antes de cada release)

1. Activar TalkBack y recorrer con deslizamientos: login → feed → abrir libro → registrar lectura → calificar → guardar.
2. Cada elemento enfocado dice **qué es, su estado y qué hace**. Nada de "botón" sin nombre ni "imagen" a secas.
3. Repetir con fuente al máximo y con el tema oscuro.

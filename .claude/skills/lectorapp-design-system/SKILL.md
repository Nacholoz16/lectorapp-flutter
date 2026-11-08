---
name: lectorapp-design-system
description: Sistema de diseño visual de LectorApp (Flutter) — paleta accesible por tema, tipografía Lora/Nunito con escala fija, espaciado, radios, sombras y patrones de componentes (tarjetas, botones, chips, inputs, hojas inferiores). Usar SIEMPRE que se cree o modifique UI en lib/screens, lib/widgets o lib/services/theme_service.dart, se elijan colores, tamaños de texto, márgenes o bordes, o se pida "mejorar el diseño", "darle profesionalismo" o "que se vea más bonito".
---

# Sistema de diseño de LectorApp

**Personalidad:** un cuaderno de lectura cálido. *Amigable pero profesional*: tranquilo, ordenado y con aire, nunca infantil ni recargado. El usuario guarda aquí sus pensamientos, así que la UI cede protagonismo al contenido (portadas, títulos y reseñas).

Principios, en orden de prioridad:
1. **Legible antes que bonito.** Todo texto cumple el contraste WCAG AA (ver la skill `lectorapp-accessibility`).
2. **Calma.** Pocos colores por pantalla, mucho espacio en blanco, una sola acción principal visible.
3. **Consistencia.** Los valores salen de tokens, no se escriben números ni colores sueltos.
4. **El contenido manda.** Lora para la voz literaria (títulos de libros, encabezados) y Nunito para la interfaz.

## 1. Color: pastel para superficies, "tinta" para texto y acciones

Medición real (2026-11): los pasteles actuales **no sirven** como fondo de botón con texto blanco ni como color de texto.

| Combinación actual | Contraste | ¿AA (4.5:1)? |
|---|---|---|
| Blanco sobre salvia `#8BA89F` (botones tema claro) | 2.56 | No |
| Blanco sobre rosa `#D8A7B1` | 2.08 | No |
| Blanco sobre celeste `#A1C4D0` | 1.85 | No |
| `Colors.grey.shade500` sobre crema | 2.59 | No |
| `Colors.grey.shade400` (ítem inactivo del nav) | 1.88 | No (ni 3:1) |
| Estrellas `#FFD54F` sobre blanco | 1.41 | No (ni 3:1) |
| `#1C1917` sobre arena `#B59E86` (tema oscuro) | 6.83 | Sí |

**Regla:** cada tema tiene dos tonos de su color de marca:
- **`accent` (pastel):** fondos suaves, chips seleccionados, barras de progreso, sombras, ilustraciones. Nunca texto sobre fondo claro.
- **`ink` (tinta):** texto de marca, íconos activos, fondo de botones con texto blanco y enlaces.

Tokens validados (contraste calculado):

| Tema | accent (pastel) | ink | Blanco sobre ink | ink sobre fondo |
|---|---|---|---|---|
| Salvia (claro) | `#8BA89F` | `#4F7A70` | 4.83 | 4.67 sobre `#FDFBF7` |
| Rosa Peonía | `#D8A7B1` | `#B5536A` | 4.76 | 4.57 sobre `#FEF9FA` |
| Brisa de Mar | `#A1C4D0` | `#3F7186` | 5.36 | 5.15 sobre `#F7FBFD` |
| Café de Medianoche | `#B59E86` | `#B59E86`, con texto `#1C1917` encima | — | 5.92 sobre card `#292524` |

Texto neutro (tema claro): principal `#3D4042` (10.1:1), **secundario `#6B6F72`** (4.9:1, reemplaza a `grey.shade500/600`) y pista/placeholder `#767B7E` (4.1:1, solo para texto grande o hints). En el tema oscuro: principal `#E7E5E4` y secundario `#A8A29E` (6.0:1 sobre card).

Colores semánticos de estado (texto o ícono sobre fondo claro → usar la versión "ink"; el pastel solo como fondo del chip al 15 %):

| Estado | Fondo del chip (claro) | Texto/ícono claro | Texto/ícono oscuro |
|---|---|---|---|
| terminado | `#81C784` al 15 % | `#2F7D3F` (5.1) | `#81C784` (7.5) |
| leyendo | accent al 15 % | ink del tema | accent |
| abandonado | `#E57373` al 15 % | `#B33B4E` (5.6) | `#EF9A9A` (7.0) |
| estrellas | — | `#A87A00` en el contorno (3.9, UI ≥3:1) o `#FFD54F` con contorno | `#FFD54F` (10.7) |
| me gusta activo | — | `#B33B4E` | `#EF9A9A` |

### Implementación en Flutter

- **No leer `primaryColor` para texto.** Exponer los tokens con un `ThemeExtension`:

```dart
@immutable
class LectorColors extends ThemeExtension<LectorColors> {
  final Color accent, ink, onInk, textPrimary, textSecondary, success, danger, star;
  const LectorColors({required this.accent, required this.ink, required this.onInk,
      required this.textPrimary, required this.textSecondary,
      required this.success, required this.danger, required this.star});
  @override
  LectorColors copyWith({Color? accent, Color? ink, Color? onInk, Color? textPrimary,
      Color? textSecondary, Color? success, Color? danger, Color? star}) => LectorColors(
        accent: accent ?? this.accent, ink: ink ?? this.ink, onInk: onInk ?? this.onInk,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        success: success ?? this.success, danger: danger ?? this.danger, star: star ?? this.star);
  @override
  LectorColors lerp(LectorColors? o, double t) => o == null ? this : LectorColors(
        accent: Color.lerp(accent, o.accent, t)!, ink: Color.lerp(ink, o.ink, t)!,
        onInk: Color.lerp(onInk, o.onInk, t)!, textPrimary: Color.lerp(textPrimary, o.textPrimary, t)!,
        textSecondary: Color.lerp(textSecondary, o.textSecondary, t)!,
        success: Color.lerp(success, o.success, t)!, danger: Color.lerp(danger, o.danger, t)!,
        star: Color.lerp(star, o.star, t)!);
}
// Uso: final c = Theme.of(context).extension<LectorColors>()!;
```

- **Definir un `colorScheme` en cada `ThemeData`** (`ColorScheme.fromSeed(seedColor: ink, brightness: …)` y luego `.copyWith(primary: ink, surface: …)`). Hoy no hay ninguno, así que los componentes Material 3 (Switch, ChoiceChip, DatePicker, ProgressIndicator) caen en el morado por defecto o en colores incoherentes.
- Cero `Colors.grey.shadeXXX`, `Colors.white`, `Colors.black` o `Colors.red` fuera de `theme_service.dart`. Excepción documentada: texto sobre imágenes con blur, siempre con capa oscura detrás.

## 2. Tipografía

| Rol | Fuente | Tamaño / peso / interlineado | `TextTheme` |
|---|---|---|---|
| Título de pantalla | Lora | 22 / w700 | `headlineSmall` |
| Título de sección | Lora | 18 / w700 | `titleLarge` |
| Título de libro en tarjeta | Lora | 16 / w700, máx. 2 líneas | `titleMedium` |
| Cuerpo y reseñas | Nunito | 15–16 / w400 / **1.5–1.6** | `bodyLarge` |
| Texto de interfaz | Nunito | 14 / w600 | `labelLarge` |
| Metadatos (fecha, autor, páginas) | Nunito | 12–13 / w600, color secundario | `bodySmall` |
| Mínimo absoluto | — | **12 sp**. Nada de 10 u 11 | — |

- Usar `Theme.of(context).textTheme.xxx` (con `copyWith` si hace falta) en vez de `TextStyle(fontSize: …)` sueltos. Hoy hay unos 67 tamaños hardcodeados: migrarlos a medida que se toquen las pantallas.
- Lora vía `GoogleFonts.lora(...)` / `ThemeService.titleStyle`, no `fontFamily: 'Lora'`.
- **Evitar MAYÚSCULAS completas** en estados y autores (`'TERMINADO'`): se leen peor, TalkBack las deletrea y se sienten "a gritos". Usar mayúscula inicial (`Terminado`) con w700.
- Reseñas: sin comillas tipográficas forzadas ni cursiva en bloques largos (la cursiva cansa). Como mucho, una barra lateral sutil de color accent.

## 3. Espaciado, radios y elevación

- **Escala de espaciado (múltiplos de 4):** 4 · 8 · 12 · 16 · 20 · 24 · 32 · 48. El margen lateral de pantalla es 16 (20 en formularios). Entre secciones, 24.
- **Radios (máx. 3 valores):** 12 para elementos pequeños (chips, portadas, inputs compactos), 20 para tarjetas, hojas y diálogos, y 999 (píldora) para botones y chips de filtro. Hoy conviven 4, 8, 12, 20 y 24: unificar.
- **Elevación:** sin sombras duras. Una sola sombra de tarjeta: `BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 24, offset: Offset(0, 8))`. En modo oscuro, nada de sombra: diferenciar con `cardColor`.
- Definir estas constantes en un archivo (p. ej. `lib/theme/tokens.dart`: `Space.s16`, `Radii.card`) y no repetir literales.

## 4. Componentes

- **Botón principal** (`FilledButton`/`ElevatedButton`): fondo `ink`, texto `onInk`, altura ≥ 48, forma píldora. Uno solo por pantalla u hoja.
- **Botón secundario:** `OutlinedButton` con borde `ink` al 40 %, o `TextButton` en color `ink`.
- **Acción destructiva:** `TextButton` en color `danger`, siempre con confirmación o "Deshacer" (ver `lectorapp-ux-patterns`).
- **Tarjeta de feed/biblioteca:** `cardColor`, radio 20, padding 16–20, sombra de token. Jerarquía: autor/fecha → reseña → libro → acciones.
- **Chips de estado:** fondo del color semántico al 15 %, texto en su versión ink, ícono a la izquierda (✓ terminado, 📖 leyendo, ✕ abandonado) para no depender solo del color.
- **Inputs:** relleno sutil, sin borde en reposo y **con borde `ink` de 2 px en foco** (hoy `focusedBorder` es `BorderSide.none`, así que no se ve dónde está el foco). Etiqueta visible encima, no solo `hintText`.
- **Bottom sheets:** radio superior de 20, *drag handle* visible (`showDragHandle: true`), `useSafeArea: true` y botón principal fijo abajo, no en el AppBar.
- **Portadas:** siempre `BookCover` (radio 12, proporción 2:3, fallback con título).
- **Avatares:** círculo, con borde de 2 px `accent` cuando se pueden tocar.
- **Estados vacíos:** ilustración o ícono grande en accent, título en Lora, una frase amable y un botón de acción (ver `lectorapp-ux-patterns`).

## 5. Movimiento

- Duraciones de 150–250 ms con curva `Curves.easeOutCubic`. Nada de rebotes.
- Animar los cambios de estado (me gusta, guardar, cambiar de pestaña) con `AnimatedSwitcher`/`AnimatedScale`; no animar listas enteras.
- Respetar `MediaQuery.of(context).disableAnimations`: si es `true`, duración cero.

## 6. Checklist antes de dar por terminada una UI

- [ ] Ningún color, tamaño de fuente ni radio literal nuevo fuera de tokens o tema.
- [ ] Texto sobre fondo ≥ 4.5:1 (≥ 3:1 si es ≥ 18 sp o negrita ≥ 14 sp); íconos y bordes de controles ≥ 3:1.
- [ ] Probado en los **4 temas** (light, pink, blue, dark).
- [ ] Probado con texto al 200 % (Ajustes → tamaño de fuente) sin cortes ni overflow.
- [ ] Una sola acción principal visible.
- [ ] `flutter analyze` sin issues.

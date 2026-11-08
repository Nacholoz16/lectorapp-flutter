import 'package:flutter/material.dart';

/// Colores de marca y semánticos de LectorApp, por tema (ver la skill `lectorapp-design-system`).
///
/// Regla: el tono **pastel** (`accent`) es solo para fondos suaves, chips y decoración. Para texto,
/// íconos activos y fondos de botón se usa **`ink`** (la versión oscura), que cumple contraste
/// WCAG AA (≥ 4.5:1) sobre el fondo del tema.
///
/// Uso: `context.lector.textSecondary`, `context.lector.statusColor('terminado')`.
@immutable
class LectorColors extends ThemeExtension<LectorColors> {
  /// Pastel de marca: fondos tintados, chips seleccionados, sombras. Nunca como color de texto.
  final Color accent;

  /// Tono de marca legible: texto de marca, íconos activos, fondo de botones principales.
  final Color ink;

  /// Texto/íconos sobre un fondo `ink`.
  final Color onInk;

  final Color textPrimary;

  /// Metadatos, subtítulos, íconos secundarios (≥ 4.5:1 sobre el fondo).
  final Color textSecondary;

  /// Ítems inactivos de navegación e íconos de control (≥ 3:1).
  final Color iconInactive;

  /// Divisores, *drag handles* y bordes decorativos (sin requisito de contraste).
  final Color outline;

  /// Estado "terminado" y confirmaciones.
  final Color success;

  /// Estado "abandonado", errores, acciones destructivas, "me gusta" activo.
  final Color danger;

  /// Estado "leyendo" (por defecto, el `ink` del tema).
  final Color reading;

  /// Estrellas de calificación (≥ 3:1 sobre las tarjetas).
  final Color star;

  const LectorColors({
    required this.accent,
    required this.ink,
    required this.onInk,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconInactive,
    required this.outline,
    required this.success,
    required this.danger,
    required this.reading,
    required this.star,
  });

  /// Color semántico de un estado de lectura (`leyendo`, `terminado`, `abandonado`).
  Color statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'terminado':
        return success;
      case 'abandonado':
        return danger;
      case 'leyendo':
        return reading;
      default:
        return textSecondary;
    }
  }

  @override
  LectorColors copyWith({
    Color? accent,
    Color? ink,
    Color? onInk,
    Color? textPrimary,
    Color? textSecondary,
    Color? iconInactive,
    Color? outline,
    Color? success,
    Color? danger,
    Color? reading,
    Color? star,
  }) {
    return LectorColors(
      accent: accent ?? this.accent,
      ink: ink ?? this.ink,
      onInk: onInk ?? this.onInk,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      iconInactive: iconInactive ?? this.iconInactive,
      outline: outline ?? this.outline,
      success: success ?? this.success,
      danger: danger ?? this.danger,
      reading: reading ?? this.reading,
      star: star ?? this.star,
    );
  }

  @override
  LectorColors lerp(ThemeExtension<LectorColors>? other, double t) {
    if (other is! LectorColors) return this;
    return LectorColors(
      accent: Color.lerp(accent, other.accent, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      iconInactive: Color.lerp(iconInactive, other.iconInactive, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      reading: Color.lerp(reading, other.reading, t)!,
      star: Color.lerp(star, other.star, t)!,
    );
  }
}

extension LectorThemeContext on BuildContext {
  /// Tokens de color del tema activo.
  LectorColors get lector => Theme.of(this).extension<LectorColors>()!;
}

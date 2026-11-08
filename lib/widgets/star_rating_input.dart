import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/lector_colors.dart';

/// Selector de calificación de 0 a 5 estrellas, accesible.
///
/// - Para TalkBack es **un solo control ajustable** ("Calificación, 4 de 5 estrellas";
///   deslizar arriba/abajo cambia el valor), en vez de 5 botones sin nombre.
/// - Tocar la estrella ya seleccionada quita la calificación (es opcional).
/// - Cada estrella ocupa 48×48 dp aunque el ícono sea más pequeño.
class StarRatingInput extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 32,
  });

  static String describe(int rating) =>
      rating <= 0 ? 'Sin calificar' : '$rating de 5 estrellas';

  void _set(int rating) {
    final next = rating.clamp(0, 5);
    if (next == value) return;
    HapticFeedback.selectionClick().catchError((_) {});
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    return Semantics(
      label: 'Calificación',
      value: describe(value),
      increasedValue: describe((value + 1).clamp(0, 5)),
      decreasedValue: describe((value - 1).clamp(0, 5)),
      onIncrease: value < 5 ? () => _set(value + 1) : null,
      onDecrease: value > 0 ? () => _set(value - 1) : null,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              SizedBox(
                width: 48,
                height: 48,
                child: InkResponse(
                  key: ValueKey('star_$i'),
                  radius: 24,
                  onTap: () => _set(i == value ? 0 : i),
                  child: Icon(
                    i <= value ? Icons.star_rounded : Icons.star_border_rounded,
                    color: c.star,
                    size: size,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              value <= 0 ? 'Sin calificar' : '$value de 5',
              style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

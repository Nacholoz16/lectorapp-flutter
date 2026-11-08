import 'package:flutter/material.dart';

import '../theme/lector_colors.dart';

/// Etiqueta visible de un estado de lectura. El valor de la API no cambia
/// (`leyendo`/`terminado`/`abandonado`); solo cómo se muestra.
String statusLabel(String? status) {
  switch (status?.toLowerCase()) {
    case 'leyendo':
      return 'Leyendo';
    case 'terminado':
      return 'Terminado';
    case 'abandonado':
      return 'Lo dejé';
    default:
      return status ?? '';
  }
}

IconData statusIcon(String? status) {
  switch (status?.toLowerCase()) {
    case 'terminado':
      return Icons.check_circle_rounded;
    case 'abandonado':
      return Icons.pause_circle_rounded;
    default:
      return Icons.menu_book_rounded;
  }
}

/// Chip compacto de estado: ícono + texto (no depende solo del color) en mayúscula inicial
/// (las MAYÚSCULAS completas se leen peor y TalkBack las deletrea).
class StatusChip extends StatelessWidget {
  final String? status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = context.lector.statusColor(status);
    return Semantics(
      label: 'Estado: ${statusLabel(status)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(statusIcon(status), size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              statusLabel(status),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

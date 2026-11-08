import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_lectorapp/services/theme_service.dart';

/// Contraste WCAG 2.x entre dos colores opacos.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Verifica que los tokens de cada tema cumplan los mínimos de la skill
/// `lectorapp-design-system`: texto ≥ 4.5:1 y controles/íconos/estrellas ≥ 3:1.
void main() {
  for (final entry in ThemeService.palettes.entries) {
    final name = entry.key;
    final p = entry.value;
    final c = p.colors;

    group('Tema $name', () {
      void expectAtLeast(String what, Color fg, Color bg, double min) {
        final ratio = contrast(fg, bg);
        expect(ratio, greaterThanOrEqualTo(min),
            reason: '$what: ${ratio.toStringAsFixed(2)}:1 (mínimo $min:1)');
      }

      test('texto principal y secundario ≥ 4.5:1 sobre fondo y tarjeta', () {
        for (final bg in [p.background, p.card]) {
          expectAtLeast('textPrimary', c.textPrimary, bg, 4.5);
          expectAtLeast('textSecondary', c.textSecondary, bg, 4.5);
        }
      });

      test('ink legible como texto y como fondo de botón', () {
        expectAtLeast('ink sobre fondo', c.ink, p.background, 4.5);
        expectAtLeast('ink sobre tarjeta', c.ink, p.card, 4.5);
        expectAtLeast('onInk sobre ink', c.onInk, c.ink, 4.5);
      });

      test('colores de estado legibles sobre la tarjeta', () {
        expectAtLeast('success', c.success, p.card, 4.5);
        expectAtLeast('danger', c.danger, p.card, 4.5);
        expectAtLeast('reading', c.reading, p.card, 4.5);
      });

      test('íconos inactivos y estrellas ≥ 3:1 (componentes no textuales)', () {
        expectAtLeast('iconInactive', c.iconInactive, p.card, 3);
        expectAtLeast('star', c.star, p.card, 3);
      });
    });
  }
}

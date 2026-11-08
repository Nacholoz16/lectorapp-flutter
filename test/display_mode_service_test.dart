import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_lectorapp/services/display_mode_service.dart';

DisplayMode mode(int id, int w, int h, double hz) =>
    DisplayMode(id: id, width: w, height: h, refreshRate: hz);

void main() {
  group('DisplayModeService.pickBestMode', () {
    test('elige 120 Hz a la misma resolución que el modo activo', () {
      final active = mode(1, 1220, 2712, 60);
      final modes = [active, mode(2, 1220, 2712, 90), mode(3, 1220, 2712, 120)];
      expect(DisplayModeService.pickBestMode(modes, active)?.id, 3);
    });

    test('si ya está en el máximo, no cambia nada', () {
      final active = mode(3, 1220, 2712, 120);
      final modes = [mode(1, 1220, 2712, 60), active];
      expect(DisplayModeService.pickBestMode(modes, active), isNull);
    });

    test('si 120 Hz solo existe a otra resolución, elige el mayor refresco en la resolución más alta', () {
      // Caso típico de algunos fabricantes: el modo activo reporta una resolución "inteligente" menor.
      final active = mode(1, 915, 2034, 60);
      final modes = [active, mode(2, 1220, 2712, 60), mode(3, 1220, 2712, 120)];
      expect(DisplayModeService.pickBestMode(modes, active)?.id, 3);
    });

    test('lista vacía → null', () {
      expect(DisplayModeService.pickBestMode([], mode(1, 1080, 2400, 60)), isNull);
    });
  });
}

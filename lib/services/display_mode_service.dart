import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// Pide al sistema la tasa de refresco más alta disponible (90/120 Hz) en Android.
///
/// Por qué no basta con llamar a `FlutterDisplayMode.setHighRefreshRate()` en `main()`:
/// - En `main()` la ventana (Activity) puede no estar lista todavía; el plugin falla y,
///   si el error se ignora, la app queda en el modo por defecto del sistema.
/// - Algunas capas de fabricante (ej. HyperOS de Xiaomi) bajan a 60 Hz las apps que dibujan
///   en un SurfaceView (como Flutter) salvo que la app pida un modo explícito, y pueden
///   restablecerlo al salir y volver a la app.
///
/// Por eso se aplica tras el primer frame y de nuevo cada vez que la app vuelve al primer plano.
class DisplayModeService {
  DisplayModeService._();

  static AppLifecycleListener? _lifecycleListener;

  static bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Llamar una vez, después de `runApp`.
  static void init() {
    if (!_isSupported || _lifecycleListener != null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_apply()));
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(_apply()),
    );
  }

  static Future<void> _apply() async {
    try {
      final modes = await FlutterDisplayMode.supported;
      final active = await FlutterDisplayMode.active;
      final best = pickBestMode(modes, active);

      if (best != null) {
        await FlutterDisplayMode.setPreferredMode(best);
      }

      if (kDebugMode) {
        final preferred = await FlutterDisplayMode.preferred;
        debugPrint('[DisplayMode] soportados: ${modes.map(_fmt).join(', ')}');
        debugPrint('[DisplayMode] activo: ${_fmt(active)} -> pedido: '
            '${best == null ? '(sin cambio)' : _fmt(best)} -> preferido ahora: ${_fmt(preferred)}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[DisplayMode] no se pudo aplicar: $e');
    }
  }

  /// Elige el modo con mayor refresco **a la resolución actual**; si a esa resolución no hay
  /// nada mejor que el modo activo, busca el de mayor refresco entre las resoluciones más altas.
  /// Devuelve null si no hay un modo mejor que el activo.
  @visibleForTesting
  static DisplayMode? pickBestMode(List<DisplayMode> modes, DisplayMode active) {
    DisplayMode? best;

    for (final m in modes) {
      if (m.width == active.width &&
          m.height == active.height &&
          m.refreshRate > (best?.refreshRate ?? active.refreshRate)) {
        best = m;
      }
    }
    if (best != null) return best;

    final maxPixels = modes.fold<int>(0, (acc, m) {
      final px = m.width * m.height;
      return px > acc ? px : acc;
    });
    for (final m in modes) {
      if (m.width * m.height == maxPixels &&
          m.refreshRate > (best?.refreshRate ?? active.refreshRate)) {
        best = m;
      }
    }
    return best;
  }

  static String _fmt(DisplayMode m) =>
      '#${m.id} ${m.width}x${m.height}@${m.refreshRate.toStringAsFixed(0)}Hz';
}

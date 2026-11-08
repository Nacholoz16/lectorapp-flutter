import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cómo se muestran las lecturas en el feed de Inicio.
enum FeedLayout {
  /// Tarjetas con la portada como protagonista (por defecto).
  cards,

  /// Lista compacta separada por líneas: más lecturas por pantalla.
  compact,
}

/// Preferencias de la interfaz guardadas en el teléfono (no en la cuenta).
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const _feedLayoutKey = 'feed_layout';

  /// Vista del feed; las pantallas la escuchan para redibujarse al cambiarla en Ajustes.
  final ValueNotifier<FeedLayout> feedLayout = ValueNotifier(FeedLayout.cards);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_feedLayoutKey);
    feedLayout.value = FeedLayout.values.firstWhere(
      (l) => l.name == saved,
      orElse: () => FeedLayout.cards,
    );
  }

  Future<void> setFeedLayout(FeedLayout layout) async {
    feedLayout.value = layout;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_feedLayoutKey, layout.name);
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/json_utils.dart';
import 'api_client.dart';

/// Aceptación de los Términos y la Política de privacidad (tarea 1.3).
///
/// La API exige la versión vigente aceptada para publicar (crear o dejar pública una lectura):
/// si falta responde `403 TERMS_REQUIRED`. Para avisar ANTES de ese error, la app guarda en
/// `user-data` lo que la API informa en login/registro/reset y en el perfil propio:
/// `terms_version` (aceptada), `current_terms_version` y `needs_terms`. No son datos sensibles.
///
/// El estado local es solo una pista: la decisión la toma siempre la API, y el 403 se maneja
/// igual (por ejemplo, si la versión vigente cambió y el dato local es viejo).
class TermsService {
  static final TermsService _instance = TermsService._internal();
  factory TermsService() => _instance;
  TermsService._internal();

  final _api = ApiClient();

  /// Campos que se copian de las respuestas de la API a `user-data`.
  static const _fields = [
    'terms_version',
    'current_terms_version',
    'needs_terms',
  ];

  /// ¿Hay que aceptar los términos antes de publicar, según [json] (usuario de login/registro,
  /// perfil propio o `user-data`)? `null` si no trae información (sesiones de la 1.0.0 o
  /// perfiles ajenos): en ese caso la app no pregunta y confía en el 403 de la API.
  static bool? needsTermsFrom(Map<dynamic, dynamic>? json) {
    if (json == null) return null;
    if (json.containsKey('needs_terms') && json['needs_terms'] != null) {
      return asBool(json['needs_terms']);
    }
    final current = json['current_terms_version'];
    if (current is String && current.isNotEmpty) {
      return json['terms_version'] != current;
    }
    return null;
  }

  /// Solo los campos de términos de [json] (para guardarlos junto al usuario).
  static Map<String, dynamic> pickFields(Map<dynamic, dynamic> json) => {
        for (final key in _fields)
          if (json.containsKey(key)) key: json[key],
      };

  /// Estado guardado en el teléfono (ver [needsTermsFrom]).
  Future<bool?> needsAcceptance() async =>
      needsTermsFrom(await _readUserData());

  /// Guarda el estado que trae una respuesta de la API (no hace nada si no trae información).
  Future<void> saveStatusFrom(Map<dynamic, dynamic> json) async {
    if (needsTermsFrom(json) == null) return;
    await _mergeUserData(pickFields(json));
  }

  /// La API respondió 403 TERMS_REQUIRED: el dato local estaba viejo.
  Future<void> markAcceptanceNeeded() => _mergeUserData({'needs_terms': true});

  /// Acepta la versión vigente (`POST /account/terms`) y guarda el nuevo estado.
  Future<void> accept() async {
    final data = await _api.post('/account/terms');
    if (data is Map && needsTermsFrom(data) != null) {
      await _mergeUserData(pickFields(data));
    } else {
      // Respuesta sin cuerpo útil: lo importante es que la API respondió 2xx.
      await _mergeUserData({'needs_terms': false});
    }
  }

  Future<Map<String, dynamic>?> _readUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ApiClient.userDataKey);
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Mezcla [values] en `user-data`. Sin sesión guardada no crea nada (no hay a quién asignarlo).
  Future<void> _mergeUserData(Map<String, dynamic> values) async {
    final current = await _readUserData();
    if (current == null) {
      if (kDebugMode) {
        debugPrint('[terms] sin user-data: no se guarda el estado');
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ApiClient.userDataKey,
      json.encode({...current, ...values}),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../utils/json_utils.dart';
import 'api_client.dart';

/// Lo que devuelve `GET /account/status`: el estado y los conteos para los textos de
/// confirmación ("Tus N lecturas públicas pasarán a privadas" / "…volverán a ser públicas").
@immutable
class AccountStatusInfo {
  final String status;

  /// Lecturas públicas ahora (las que se ocultarán al desactivar).
  final int publicReadings;

  /// Lecturas que volverán a ser públicas al reactivar (sin las bloqueadas por moderación).
  final int restorableReadings;

  const AccountStatusInfo({
    required this.status,
    required this.publicReadings,
    required this.restorableReadings,
  });

  bool get isDeactivated => status == AccountService.deactivated;

  factory AccountStatusInfo.fromJson(Map<dynamic, dynamic> json) =>
      AccountStatusInfo(
        status: AccountService.statusFrom(json) ?? AccountService.active,
        publicReadings: asInt(json['public_readings']),
        restorableReadings: asInt(json['restorable_readings']),
      );
}

/// Estado de la cuenta: activa o desactivada por su dueño (tarea 2.1, decisión D7).
///
/// Con la cuenta desactivada la app entra en **modo solo lectura** (solo la biblioteca, ver
/// `TabsScreen`). [isDeactivated] es la fuente para la UI; se alimenta de:
/// - `user-data` al arrancar ([load]) y el `status` del usuario en login/registro/reset;
/// - las respuestas de desactivar / reactivar / `GET /account/status`;
/// - la red de seguridad: cualquier `403 ACCOUNT_DEACTIVATED` que reciba [ApiClient]
///   ([onDeactivatedResponse]), p. ej. si se desactivó desde otro teléfono.
///
/// El estado local es solo una pista para no esperar a la red: la API decide siempre.
class AccountService {
  static final AccountService _instance = AccountService._internal();
  factory AccountService() => _instance;
  AccountService._internal();

  static const active = 'active';
  static const deactivated = 'deactivated';
  static const _statusField = 'status';

  final _api = ApiClient();

  /// `true` mientras la cuenta está desactivada (modo solo lectura).
  final ValueNotifier<bool> isDeactivated = ValueNotifier(false);

  /// `status` de una respuesta de la API (usuario de login, perfil propio, `/account/status`),
  /// o null si no lo trae (APIs anteriores a la 1.1.0, perfiles ajenos).
  static String? statusFrom(Map<dynamic, dynamic>? json) {
    final value = json?[_statusField];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// Lee el estado guardado en `user-data` (al arrancar, sin red).
  Future<void> load() async {
    final data = await _readUserData();
    isDeactivated.value = statusFrom(data) == deactivated;
  }

  /// Aplica el `status` que trae [json] (si lo trae) y lo guarda en `user-data`.
  Future<void> saveStatusFrom(Map<dynamic, dynamic> json) async {
    final status = statusFrom(json);
    if (status != null) await _setStatus(status);
  }

  /// `GET /account/status`: estado real y conteos. Actualiza [isDeactivated].
  Future<AccountStatusInfo> fetchStatus() async {
    final data = await _api.get('/account/status');
    if (data is! Map) throw ApiException('Respuesta inválida del servidor');
    final info = AccountStatusInfo.fromJson(data);
    await _setStatus(info.status);
    return info;
  }

  /// Desactiva la cuenta confirmando con la contraseña. Devuelve cuántas lecturas públicas
  /// pasaron a privadas. Contraseña incorrecta → [ApiException] con `isInvalidPassword`
  /// (la sesión NO se cierra: ver ApiClient).
  /// Si ya estaba desactivada (409, p. ej. desde otro teléfono) se sincroniza el estado y se
  /// devuelve 0: la API no tocó nada y la visibilidad guardada sigue intacta.
  Future<int> deactivate(String password) async {
    try {
      final data =
          await _api.post('/account/deactivate', body: {'password': password});
      await _setStatus(deactivated);
      return data is Map ? asInt(data['hidden_readings']) : 0;
    } on ApiException catch (e) {
      if (e.statusCode != 409) rethrow;
      final info = await fetchStatus();
      if (!info.isDeactivated) rethrow;
      return 0;
    }
  }

  /// Reactiva la cuenta. Devuelve cuántas lecturas volvieron a ser públicas.
  /// Si ya estaba activa (p. ej. se reactivó desde otro teléfono) la API responde 409: se toma
  /// como éxito con 0 lecturas, porque el resultado que el usuario quería ya se cumple.
  Future<int> reactivate() async {
    try {
      final data = await _api.post('/account/reactivate');
      await _setStatus(active);
      return data is Map ? asInt(data['restored_readings']) : 0;
    } on ApiException catch (e) {
      if (e.statusCode != 409) rethrow;
      final info = await fetchStatus();
      if (info.isDeactivated) rethrow;
      return 0;
    }
  }

  /// Red de seguridad: la API respondió `403 ACCOUNT_DEACTIVATED` a alguna petición. Se pasa a
  /// modo solo lectura y se cierran las pantallas apiladas (búsqueda, detalle, hojas…), que ya
  /// no sirven. Solo actúa la primera vez: las peticiones que fallen después (o a la vez) no
  /// vuelven a navegar, y el modo solo lectura no llama a nada que pueda dar este error.
  void onDeactivatedResponse() {
    if (isDeactivated.value) return;
    unawaited(_setStatus(deactivated));
    Config.navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  Future<void> _setStatus(String status) async {
    isDeactivated.value = status == deactivated;
    await _mergeUserData({_statusField: status});
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

  /// Mezcla [values] en `user-data` (como TermsService). Sin sesión guardada no crea nada.
  Future<void> _mergeUserData(Map<String, dynamic> values) async {
    final current = await _readUserData();
    if (current == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ApiClient.userDataKey,
      json.encode({...current, ...values}),
    );
  }
}

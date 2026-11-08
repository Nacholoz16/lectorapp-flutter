import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';
import '../screens/login_screen.dart';

/// Cliente HTTP centralizado. TODA llamada a la API pasa por aquí.
/// - Sesión = token de acceso (JWT de 30 min) + refresh token (60 días, rotativo), ambos en
///   SecureStorage y cacheados en memoria.
/// - Renueva la sesión sola: antes de pedir si el acceso ya venció, y al recibir un 401
///   (reintenta la petición una vez). Varias peticiones a la vez comparten UNA renovación.
/// - Solo manda a Login si la API dice que la sesión terminó de verdad; un fallo de red al
///   renovar no cierra la sesión.
/// - Timeout de 15 segundos. Cualquier fallo se convierte en [ApiException].
/// - Logs de depuración solo en modo debug (sin bodies: pueden llevar contraseñas).
class ApiClient {
  // Singleton
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const _timeout = Duration(seconds: 15);
  static const _tokenKey = 'auth-token';
  static const _refreshKey = 'refresh-token';
  static const userDataKey = 'user-data';
  static const feedCacheKey = 'cached_global_feed';
  static const _refreshPath = '/auth/refresh';

  final _secureStorage = const FlutterSecureStorage();

  /// Cliente único y reutilizado: mantiene las conexiones abiertas (keep-alive).
  http.Client _httpClient = http.Client();

  /// Solo para tests: sustituye el cliente HTTP (p. ej. por un `MockClient`).
  @visibleForTesting
  set httpClientForTesting(http.Client client) => _httpClient = client;

  String? _cachedToken;
  String? _cachedRefreshToken;

  /// Renovación en curso (compartida por todas las peticiones que la necesiten a la vez).
  Future<bool>? _refreshing;

  /// Evita que varias peticiones con 401 simultáneas empujen varias LoginScreen.
  bool _isRedirectingToLogin = false;

  // ─── Sesión ───────────────────────────────────────────────────────────────

  /// Guarda la sesión (token de acceso y, si viene, refresh token) en memoria y SecureStorage.
  Future<void> setSession({required String token, String? refreshToken}) async {
    _cachedToken = token;
    await _secureStorage.write(key: _tokenKey, value: token);
    if (refreshToken != null) {
      _cachedRefreshToken = refreshToken;
      await _secureStorage.write(key: _refreshKey, value: refreshToken);
    }
  }

  /// Carga la sesión desde SecureStorage una sola vez al arranque.
  Future<void> loadToken() async {
    final values = await Future.wait([
      _secureStorage.read(key: _tokenKey),
      _secureStorage.read(key: _refreshKey),
    ]);
    _cachedToken = values[0];
    _cachedRefreshToken = values[1];
  }

  /// Token de acceso actual (desde caché en memoria).
  Future<String?> getToken() async {
    _cachedToken ??= await _secureStorage.read(key: _tokenKey);
    return _cachedToken;
  }

  Future<String?> getRefreshToken() async {
    _cachedRefreshToken ??= await _secureStorage.read(key: _refreshKey);
    return _cachedRefreshToken;
  }

  /// Borra todos los datos de sesión locales (tokens, usuario y feed cacheado).
  Future<void> clearSession() async {
    _cachedToken = null;
    _cachedRefreshToken = null;
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(userDataKey);
    await prefs.remove(feedCacheKey);
  }

  /// ¿El JWT ya venció (o vence en menos de 30 s)? Solo lee `exp`; la firma la valida la API.
  @visibleForTesting
  static bool isAccessTokenExpired(String? token, {DateTime? now}) {
    if (token == null || token.isEmpty) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = json.decode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload['exp'];
      if (exp is! int) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return !(now ?? DateTime.now()).isBefore(expiry.subtract(const Duration(seconds: 30)));
    } catch (_) {
      return true;
    }
  }

  // ─── Métodos públicos ─────────────────────────────────────────────────────

  Future<dynamic> get(String path) => _send('GET', path);

  /// [redirectOn401]: false en login/registro/logout/recuperación, donde un 401 significa
  /// "credenciales inválidas", no "sesión expirada" (no se intenta renovar ni se va a Login).
  Future<dynamic> post(String path,
          {Map<String, dynamic>? body, bool redirectOn401 = true}) =>
      _send('POST', path, body: body, redirectOn401: redirectOn401);

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  // ─── Implementación ───────────────────────────────────────────────────────

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool redirectOn401 = true,
  }) async {
    final authenticated = redirectOn401;

    // 1. Acceso ya vencido y hay refresh: renovar ANTES (evita un 401 seguro).
    if (authenticated &&
        isAccessTokenExpired(await getToken()) &&
        await getRefreshToken() != null) {
      try {
        await _refreshSession();
      } on ApiException {
        // Sin red al renovar: se intenta igual; si da 401 se vuelve a probar abajo.
      }
    }

    var response = await _request(method, path, body);

    // 2. 401 en una petición autenticada: renovar una vez y reintentar.
    if (response.statusCode == 401 && authenticated) {
      // Si la renovación falla por red, la ApiException sube tal cual (sin cerrar sesión).
      if (await _refreshSession()) {
        response = await _request(method, path, body);
      }
      if (response.statusCode == 401) {
        await _handleSessionExpired();
        throw ApiException('Tu sesión expiró. Inicia sesión de nuevo.', statusCode: 401);
      }
    }

    return _parse(response, method, path);
  }

  /// Una petición HTTP con el token actual. Convierte fallos de red/timeout en [ApiException].
  Future<http.Response> _request(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final uri = Uri.parse('${Config.baseUrl}$path');
    final token = await getToken();
    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    if (token != null && path != _refreshPath) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) request.body = json.encode(body);

    if (kDebugMode) debugPrint('[HTTP] $method $uri');

    try {
      final streamed = await _httpClient.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(streamed).timeout(_timeout);
      if (kDebugMode) debugPrint('[HTTP] ${response.statusCode} $method $path');
      return response;
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder. Intenta de nuevo.');
    } on SocketException {
      throw ApiException('Sin conexión a internet.');
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor.');
    }
  }

  dynamic _parse(http.Response response, String method, String path) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return json.decode(response.body);
      } on FormatException {
        throw ApiException('Respuesta inválida del servidor',
            statusCode: response.statusCode);
      }
    }
    throw ApiException(
      _extractErrorMessage(response),
      statusCode: response.statusCode,
    );
  }

  /// Renueva la sesión con el refresh token. Devuelve false si la sesión ya no es válida
  /// (sin refresh token, o la API lo rechaza). Lanza [ApiException] si falla la red o el
  /// servidor (5xx/429): en ese caso NO se cierra la sesión.
  Future<bool> _refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    final response =
        await _request('POST', _refreshPath, {'refresh_token': refreshToken});
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await setSession(
        token: data['token'] as String,
        refreshToken: data['refresh_token'] as String?,
      );
      if (kDebugMode) debugPrint('[HTTP] sesión renovada');
      return true;
    }
    if (response.statusCode == 401 || response.statusCode == 400) return false;
    throw ApiException(_extractErrorMessage(response), statusCode: response.statusCode);
  }

  /// Limpia la sesión y vuelve a Login (una sola vez aunque fallen varias peticiones a la vez).
  Future<void> _handleSessionExpired() async {
    if (_isRedirectingToLogin) return;
    _isRedirectingToLogin = true;
    try {
      await clearSession();
      final navigator = Config.navigatorKey.currentState;
      if (navigator != null) {
        unawaited(navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        ));
      }
    } finally {
      _isRedirectingToLogin = false;
    }
  }

  /// Extrae el mensaje de error del body (`{ error }` o `{ message }`).
  /// Si el body no es JSON (ej. página HTML de Nginx en un 502), usa un mensaje genérico.
  @visibleForTesting
  static String extractErrorMessage(int statusCode, String body) {
    try {
      final data = json.decode(body);
      if (data is Map) {
        final msg = data['error'] ?? data['message'];
        if (msg is String && msg.isNotEmpty) return msg;
      }
    } catch (_) {}
    if (statusCode >= 500) return 'El servidor no está disponible. Intenta más tarde.';
    return 'Error $statusCode';
  }

  String _extractErrorMessage(http.Response response) =>
      extractErrorMessage(response.statusCode, response.body);
}

/// Excepción para cualquier error de API. `statusCode` es 0 si no hubo respuesta (red/timeout).
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, {this.statusCode = 0});

  @override
  String toString() => message;
}

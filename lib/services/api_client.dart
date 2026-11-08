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
/// - Token cacheado en memoria (solo lee SecureStorage al arranque).
/// - Inyecta automáticamente el token en los headers.
/// - Detecta respuestas 401 y redirige a Login limpiando la sesión.
/// - Timeout de 15 segundos en todas las peticiones.
/// - Convierte cualquier fallo (red, timeout, JSON inválido, HTTP 4xx/5xx) en [ApiException].
/// - Logs de depuración solo en modo debug (sin bodies: pueden llevar contraseñas).
class ApiClient {
  // Singleton
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const _timeout = Duration(seconds: 15);
  static const _tokenKey = 'auth-token';
  static const userDataKey = 'user-data';
  static const feedCacheKey = 'cached_global_feed';

  final _secureStorage = const FlutterSecureStorage();

  /// Cliente único y reutilizado: mantiene las conexiones abiertas (keep-alive)
  /// en vez de abrir un socket nuevo por petición.
  final http.Client _httpClient = http.Client();

  /// Token cacheado en memoria para evitar I/O de SecureStorage en cada request.
  String? _cachedToken;

  /// Evita que varias peticiones con 401 simultáneas empujen varias LoginScreen.
  bool _isRedirectingToLogin = false;

  // ─── Token ────────────────────────────────────────────────────────────────

  /// Escribe el token en memoria y en SecureStorage.
  Future<void> setToken(String? token) async {
    _cachedToken = token;
    if (token != null) {
      await _secureStorage.write(key: _tokenKey, value: token);
    } else {
      await _secureStorage.delete(key: _tokenKey);
    }
  }

  /// Carga el token desde SecureStorage una sola vez al arranque.
  Future<void> loadToken() async {
    _cachedToken = await _secureStorage.read(key: _tokenKey);
  }

  /// Lee el token actual (desde caché en memoria).
  Future<String?> getToken() async {
    _cachedToken ??= await _secureStorage.read(key: _tokenKey);
    return _cachedToken;
  }

  /// Borra todos los datos de sesión locales (token, usuario y feed cacheado).
  Future<void> clearSession() async {
    await setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(userDataKey);
    await prefs.remove(feedCacheKey);
  }

  // ─── Métodos públicos ─────────────────────────────────────────────────────

  Future<dynamic> get(String path) => _send('GET', path);

  /// [redirectOn401]: false en login/registro/logout, donde un 401 significa
  /// "credenciales inválidas" o "token ya revocado", no "sesión expirada".
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
    final uri = Uri.parse('${Config.baseUrl}$path');
    final token = await getToken();
    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = json.encode(body);

    if (kDebugMode) debugPrint('[HTTP] $method $uri');

    final http.Response response;
    try {
      final streamed = await _httpClient.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado en responder. Intenta de nuevo.');
    } on SocketException {
      throw ApiException('Sin conexión a internet.');
    } on http.ClientException {
      throw ApiException('No se pudo conectar con el servidor.');
    }

    if (kDebugMode) debugPrint('[HTTP] ${response.statusCode} $method $path');

    if (response.statusCode == 401 && redirectOn401) {
      await _handleSessionExpired();
      throw ApiException('Sesión expirada', statusCode: 401);
    }

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

  /// Limpia la sesión y vuelve a Login (una sola vez aunque fallen varias peticiones a la vez).
  Future<void> _handleSessionExpired() async {
    if (_isRedirectingToLogin) return;
    _isRedirectingToLogin = true;
    try {
      await clearSession();
      final navigator = Config.navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
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

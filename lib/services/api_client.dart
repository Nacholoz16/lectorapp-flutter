import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';
import '../screens/login_screen.dart';

/// Cliente HTTP centralizado.
/// - Token cacheado en memoria (solo lee SecureStorage al arranque).
/// - Inyecta automáticamente el token en los headers.
/// - Detecta respuestas 401 y redirige a Login limpiando la sesión.
/// - Timeout de 15 segundos en todas las peticiones.
/// - Logs de depuración solo en modo debug.
class ApiClient {
  // Singleton
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _secureStorage = const FlutterSecureStorage();

  /// Token cacheado en memoria para evitar I/O de SecureStorage en cada request.
  String? _cachedToken;

  /// Escribe el token en memoria y en SecureStorage.
  Future<void> setToken(String? token) async {
    _cachedToken = token;
    if (token != null) {
      await _secureStorage.write(key: 'auth-token', value: token);
    } else {
      await _secureStorage.delete(key: 'auth-token');
    }
  }

  /// Carga el token desde SecureStorage una sola vez al arranque.
  Future<void> loadToken() async {
    _cachedToken = await _secureStorage.read(key: 'auth-token');
  }

  /// Lee el token actual (desde caché en memoria).
  Future<String?> getToken() async {
    _cachedToken ??= await _secureStorage.read(key: 'auth-token');
    return _cachedToken;
  }

  /// Headers comunes para todas las peticiones autenticadas.
  Future<Map<String, String>> _buildHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _logRequest(String method, Uri uri, {String? body}) {
    if (!kDebugMode) return;
    debugPrint('\n--- [HTTP REQUEST] ---');
    debugPrint('$method ${uri.toString()}');
    if (body != null) debugPrint('Body: $body');
  }

  void _logResponse(http.Response response) {
    if (!kDebugMode) return;
    debugPrint('--- [HTTP RESPONSE] ---');
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Body: ${response.body}');
    debugPrint('----------------------\n');
  }

  /// Maneja respuestas 401: limpia sesión y redirige a Login.
  Future<bool> _handle401(http.Response response) async {
    if (response.statusCode == 401) {
      await setToken(null); // limpia caché + SecureStorage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user-data');

      final navigator = Config.navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
      return true;
    }
    return false;
  }

  static const _timeout = Duration(seconds: 15);

  /// GET request autenticado.
  Future<dynamic> get(String path) async {
    final headers = await _buildHeaders();
    final uri = Uri.parse('${Config.baseUrl}$path');
    _logRequest('GET', uri);

    final response =
        await http.get(uri, headers: headers).timeout(_timeout);
    _logResponse(response);

    if (await _handle401(response)) {
      throw ApiException('Sesión expirada', statusCode: 401);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    }

    throw ApiException(
      _extractErrorMessage(response),
      statusCode: response.statusCode,
    );
  }

  /// POST request autenticado.
  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    final headers = await _buildHeaders();
    final uri = Uri.parse('${Config.baseUrl}$path');
    final encodedBody = body != null ? json.encode(body) : null;
    _logRequest('POST', uri, body: encodedBody);

    final response = await http
        .post(uri, headers: headers, body: encodedBody)
        .timeout(_timeout);
    _logResponse(response);

    if (await _handle401(response)) {
      throw ApiException('Sesión expirada', statusCode: 401);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    }

    throw ApiException(
      _extractErrorMessage(response),
      statusCode: response.statusCode,
    );
  }

  /// PUT request autenticado.
  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final headers = await _buildHeaders();
    final uri = Uri.parse('${Config.baseUrl}$path');
    final encodedBody = body != null ? json.encode(body) : null;
    _logRequest('PUT', uri, body: encodedBody);

    final response = await http
        .put(uri, headers: headers, body: encodedBody)
        .timeout(_timeout);
    _logResponse(response);

    if (await _handle401(response)) {
      throw ApiException('Sesión expirada', statusCode: 401);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    }

    throw ApiException(
      _extractErrorMessage(response),
      statusCode: response.statusCode,
    );
  }

  /// DELETE request autenticado.
  Future<dynamic> delete(String path) async {
    final headers = await _buildHeaders();
    final uri = Uri.parse('${Config.baseUrl}$path');
    _logRequest('DELETE', uri);

    final response =
        await http.delete(uri, headers: headers).timeout(_timeout);
    _logResponse(response);

    if (await _handle401(response)) {
      throw ApiException('Sesión expirada', statusCode: 401);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    }

    throw ApiException(
      _extractErrorMessage(response),
      statusCode: response.statusCode,
    );
  }

  /// Extrae el mensaje de error del body de la respuesta.
  String _extractErrorMessage(http.Response response) {
    try {
      final data = json.decode(response.body);
      return data['error'] ?? data['message'] ?? 'Error ${response.statusCode}';
    } catch (_) {
      return 'Error ${response.statusCode}';
    }
  }
}

/// Excepción personalizada para errores de API.
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, {this.statusCode = 0});

  @override
  String toString() => message;
}

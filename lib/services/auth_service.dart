import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../screens/login_screen.dart';
import 'api_client.dart';

class AuthService {
  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Future<void> login(String identifier, String password) async {
    final Map<String, dynamic> payload = identifier.contains('@')
        ? {'email': identifier, 'password': password}
        : {'username': identifier, 'password': password};

    final response = await http.post(
      Uri.parse('${Config.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final prefs = await SharedPreferences.getInstance();
      // Guardar token en caché + SecureStorage vía ApiClient
      await ApiClient().setToken(data['token']);
      await prefs.setString('user-data', json.encode(data['user']));
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Error al iniciar sesión');
    }
  }

  /// Obtener el token actual (desde caché en memoria).
  Future<String?> getToken() async {
    return ApiClient().getToken();
  }

  /// Obtener los datos del usuario logueado guardados.
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user-data');
    if (userStr != null) {
      return json.decode(userStr);
    }
    return null;
  }

  /// Verifica si un JWT es válido decodificando su payload.
  static bool isJwtValid(String? token) {
    if (token == null || token.isEmpty) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      String payload = parts[1];
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }
      final decoded = json.decode(utf8.decode(base64Url.decode(payload)));
      final exp = decoded['exp'] as int?;
      if (exp == null) return false;

      return DateTime.now()
          .isBefore(DateTime.fromMillisecondsSinceEpoch(exp * 1000));
    } catch (_) {
      return false;
    }
  }

  /// Verifica si el token guardado existe y NO ha expirado.
  Future<bool> isTokenValid() async {
    final token = await getToken();
    return isJwtValid(token);
  }

  /// Cerrar sesión borrando los datos.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await ApiClient().setToken(null); // limpia caché + SecureStorage
    await prefs.remove('user-data');
  }

  /// Forzar logout y redirigir a Login (usado por ApiClient en 401).
  Future<void> forceLogout() async {
    await logout();
    final navigator = Config.navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  /// Registrar un nuevo usuario.
  Future<void> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse('${Config.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await ApiClient().setToken(data['token']);
      await prefs.setString('user-data', json.encode(data['user']));
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ??
          errorData['message'] ??
          'Error al crear la cuenta');
    }
  }
}

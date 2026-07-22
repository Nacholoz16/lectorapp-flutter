import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Patrón Singleton para poder llamarlo desde cualquier lado sin instanciarlo repetidamente
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final String baseUrl = 'https://api.nacholoz3d.cl/api';

  Future<void> login(String identifier, String password) async {
    // Exactamente la misma lógica que tu TS
    final Map<String, dynamic> payload = identifier.contains('@')
        ? {'email': identifier, 'password': password}
        : {'username': identifier, 'password': password};

    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Guardamos el token y el usuario usando SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth-token', data['token']);
      await prefs.setString('user-data', json.encode(data['user']));
    } else {
      // Extraemos el mensaje de error de tu backend
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ?? 'Error al iniciar sesión');
    }
  }

  // Método para obtener el token guardado
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth-token');
  }

  // Obtener los datos del usuario logueado guardados
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user-data');
    if (userStr != null) {
      return json.decode(userStr);
    }
    return null;
  }

  // Cerrar sesión borrando los datos
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth-token');
    await prefs.remove('user-data');
  }

  // Método para registrar un nuevo usuario
  Future<void> register(String username, String email, String password) async {
    final response = await http.post(
      Uri.parse(
          '$baseUrl/auth/register'), // Ajusta esta ruta si tu API usa otra
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);

      // Guardamos la sesión automáticamente al registrarse (igual que en el login)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth-token', data['token']);
      await prefs.setString('user-data', json.encode(data['user']));
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['error'] ??
          errorData['message'] ??
          'Error al crear la cuenta');
    }
  }
}

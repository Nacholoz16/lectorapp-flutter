import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class UserService {
  final String baseUrl = 'https://api.nacholoz3d.cl/api';

  Future<Map<String, dynamic>> getProfile(String username) async {
    final token = await AuthService().getToken();

    final response = await http.get(
      Uri.parse(
          '$baseUrl/users/$username'), // Ajusta si tu endpoint es distinto
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Fallo al cargar el perfil');
    }
  }
}

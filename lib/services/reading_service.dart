import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ReadingService {
  final String baseUrl = 'https://api.nacholoz3d.cl/api';

  Future<List<dynamic>> getGlobalFeed() async {
    final token = await AuthService().getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/readings/feed'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Simulamos el Interceptor de Angular
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al cargar el feed');
    }
  } // 1. Crear nueva lectura

  Future<void> createLog(Map<String, dynamic> payload) async {
    final token = await AuthService().getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/readings'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(payload),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al crear el registro de lectura');
    }
  }

  // 2. Obtener biblioteca personal
  Future<List<dynamic>> getMyLibrary() async {
    final token = await AuthService().getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/readings/my-library'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al cargar la biblioteca personal');
    }
  }

  // 3. Actualizar lectura
  Future<void> updateLog(String id, Map<String, dynamic> payload) async {
    final token = await AuthService().getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/readings/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al actualizar la lectura');
    }
  }

  // 4. Eliminar lectura
  Future<void> deleteLog(String id) async {
    final token = await AuthService().getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/readings/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Error al eliminar la lectura');
    }
  }
}

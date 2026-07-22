import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart'; // Importamos el auth_service para sacar el token

class BookService {
  final String baseUrl = 'https://api.nacholoz3d.cl/api';

  Future<List<dynamic>> searchBooks(String query) async {
    // 1. Obtenemos el token guardado
    final token = await AuthService().getToken();

    // 2. Hacemos la petición inyectando el token en los headers
    final response = await http.get(
      Uri.parse('$baseUrl/books/search?q=$query'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> decoded = json.decode(response.body);
      return decoded['data'] ?? [];
    } else {
      // Imprimimos el error real en la consola para poder debugear
      print('Error en API (Search): ${response.statusCode} - ${response.body}');
      throw Exception('Fallo al buscar libros (Error ${response.statusCode})');
    }
  }

  // Aprovechamos de actualizar el getBookFeed para que también lleve token
  Future<List<dynamic>> getBookFeed(String externalId) async {
    final token = await AuthService().getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/books/feed?external_id=$externalId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('Error en API (Feed): ${response.statusCode} - ${response.body}');
      throw Exception('Fallo al cargar el feed (Error ${response.statusCode})');
    }
  }
}

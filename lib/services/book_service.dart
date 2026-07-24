import 'api_client.dart';

class BookService {
  final _api = ApiClient();

  Future<List<dynamic>> searchBooks(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final data = await _api.get('/books/search?q=$encodedQuery');
    // La API devuelve { data: [...] }
    if (data is Map<String, dynamic>) {
      return data['data'] ?? [];
    }
    return [];
  }

  Future<List<dynamic>> getBookFeed(String externalId) async {
    final encodedId = Uri.encodeComponent(externalId);
    final data = await _api.get('/books/feed?external_id=$encodedId');
    if (data is List) return data;
    return [];
  }
}


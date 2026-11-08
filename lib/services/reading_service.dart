import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class ReadingService {
  static final ReadingService _instance = ReadingService._internal();
  factory ReadingService() => _instance;
  ReadingService._internal();
  final _api = ApiClient();

  /// Se incrementa cada vez que la biblioteca del usuario cambia (añadir, editar, borrar o
  /// guardar una sesión). Las pantallas que muestran la biblioteca lo escuchan para
  /// refrescarse aunque el cambio se haya hecho desde otra pestaña (p. ej. Buscar → Perfil).
  final ValueNotifier<int> libraryChanges = ValueNotifier<int>(0);
  void _notifyLibraryChanged() => libraryChanges.value++;

  /// Feed global paginado por cursor.
  /// [beforeId]: id del último elemento ya mostrado (null = primera página).
  Future<List<dynamic>> getGlobalFeed({int? beforeId, int limit = 10}) async {
    final cursor = beforeId != null ? '&before_id=$beforeId' : '';
    final data = await _api.get('/readings/feed?limit=$limit$cursor');
    if (data is List) return data;
    return [];
  }

  /// Cuántas publicaciones públicas hay más nuevas que [afterId] (banner de novedades).
  Future<int> countNewPosts(int afterId) async {
    final data = await _api.get('/readings/feed/new-count?after_id=$afterId');
    if (data is Map && data['count'] is int) return data['count'] as int;
    return 0;
  }

  static const String _feedCacheKey = 'cached_global_feed';

  Future<void> saveCachedFeed(List<dynamic> feed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_feedCacheKey, json.encode(feed));
  }

  Future<List<dynamic>?> getCachedFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedStr = prefs.getString(_feedCacheKey);
    if (cachedStr != null) {
      try {
        final data = json.decode(cachedStr);
        if (data is List) return data;
      } catch (_) {}
    }
    return null;
  }

  Future<void> createLog(Map<String, dynamic> payload) async {
    await _api.post('/readings', body: payload);
    _notifyLibraryChanged();
  }

  Future<List<dynamic>> getMyLibrary({int page = 1, int limit = 10}) async {
    final data = await _api.get('/readings/my-library?page=$page&limit=$limit');
    if (data is List) return data;
    return [];
  }

  Future<void> updateLog(String id, Map<String, dynamic> payload) async {
    await _api.put('/readings/$id', body: payload);
    _notifyLibraryChanged();
  }

  Future<void> deleteLog(String id) async {
    await _api.delete('/readings/$id');
    _notifyLibraryChanged();
  }

  Future<Map<String, dynamic>> toggleLike(int readingLogId) async {
    final data = await _api.post('/readings/$readingLogId/like');
    return data as Map<String, dynamic>;
  }

  Future<void> recordSession(int readingLogId,
      {required int durationMinutes,
      required int pagesRead,
      int? currentPage}) async {
    await _api.post('/readings/$readingLogId/session', body: {
      'duration_minutes': durationMinutes,
      'pages_read': pagesRead,
      if (currentPage != null) 'current_page': currentPage,
    });
    _notifyLibraryChanged();
  }

  Future<Map<String, dynamic>> getBookStats(int readingLogId) async {
    final data = await _api.get('/readings/$readingLogId/stats');
    return data as Map<String, dynamic>;
  }
}


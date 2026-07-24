import 'api_client.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();
  final _api = ApiClient();

  Future<Map<String, dynamic>> getProfile(String username) async {
    final data = await _api.get('/users/$username');
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getUserLibrary(String username,
      {int page = 1, int limit = 10}) async {
    final data =
        await _api.get('/users/$username/library?page=$page&limit=$limit');
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> getUserStats(String username) async {
    final data = await _api.get('/users/$username/stats');
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setReadingGoal(int targetBooks) async {
    final data = await _api.post('/users/goal', body: {'target_books': targetBooks});
    return data as Map<String, dynamic>;
  }
}


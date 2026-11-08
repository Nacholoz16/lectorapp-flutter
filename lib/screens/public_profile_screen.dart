import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
import '../models/reading_log.dart';
import '../book_cover.dart';
import 'book_detail_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String username;

  const PublicProfileScreen({super.key, required this.username});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  UserProfile? _profile;
  String? _errorMessage;

  int _page = 1;
  final int _limit = 10;
  bool _hasMore = true;
  bool _isFetchingMore = false;

  int _selectedTab = 0; // 0: Biblioteca, 1: Estadísticas
  Map<String, dynamic>? _stats;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadProfile();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMore &&
        _hasMore &&
        !_isLoading) {
      _fetchMore();
    }
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _page = 1;
        _hasMore = true;
        _isFetchingMore = false;
      });
    }
    try {
      final profileData = await UserService().getProfile(widget.username);
      List<dynamic> libraryData = [];

      if (profileData['is_profile_public'] == true) {
        try {
          libraryData = await UserService().getUserLibrary(widget.username,
              page: _page, limit: _limit);
          profileData['library'] = libraryData;
        } catch (_) {
          if (profileData['library'] is List) {
            libraryData = profileData['library'];
          }
          _hasMore = false;
        }
      } else {
        _hasMore = false;
      }

      if (mounted) {
        setState(() {
          _profile = UserProfile.fromJson(profileData);
          _isLoading = false;
          if (libraryData.length < _limit) {
            _hasMore = false;
          }
        });
        if (_profile != null && _profile!.isProfilePublic) {
          _loadStats();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final res = await UserService().getUserStats(widget.username);
      if (mounted) {
        setState(() {
          _stats = res;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _fetchMore() async {
    if (_isFetchingMore || !_hasMore || _profile == null || !_profile!.isProfilePublic) return;
    setState(() => _isFetchingMore = true);

    try {
      final nextPage = _page + 1;
      final libraryData = await UserService().getUserLibrary(widget.username,
          page: nextPage, limit: _limit);

      final newLogs =
          libraryData.map((item) => ReadingLog.fromJson(item)).toList();

      if (mounted) {
        setState(() {
          _page = nextPage;
          _profile!.library.addAll(newLogs);
          _isFetchingMore = false;
          if (libraryData.length < _limit) {
            _hasMore = false;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isFetchingMore = false;
          _hasMore = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'terminado':
        return const Color(0xFF2DD55B);
      case 'abandonado':
        return const Color(0xFFFF4961);
      case 'leyendo':
        return const Color(0xFF4995FF);
      default:
        return const Color(0xFFB3AFB6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Error: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _profile == null
                  ? const Center(child: Text('Usuario no encontrado'))
                  : _buildContent(),
    );
  }

  Widget _buildContent() {
    final primaryColor = Theme.of(context).primaryColor;
    final library = _profile!.library;

    if (_profile!.isPrivateLock && !_profile!.isOwnProfile) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 72, color: Colors.grey.shade400),
              const SizedBox(height: 20),
              Text(
                'Perfil Privado de @${_profile!.username}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Este usuario ha configurado su perfil como privado.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: primaryColor,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          // CABECERA
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3), width: 3),
              ),
              child: CircleAvatar(
                radius: 54,
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                backgroundImage:
                    CachedNetworkImageProvider(_profile!.safeAvatarUrl),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _profile!.username,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, fontFamily: 'Lora'),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              _profile!.bio ?? 'Sin biografía aún...',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                  fontSize: 15),
            ),
          ),
          const SizedBox(height: 24),

          // Tab Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0
                              ? primaryColor.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Biblioteca (${library.length})',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                _selectedTab == 0 ? primaryColor : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1
                              ? primaryColor.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Estadísticas',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                _selectedTab == 1 ? primaryColor : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (_selectedTab == 0) ...[
            if (library.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.auto_stories_rounded,
                          size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No hay lecturas públicas.',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              )
            else ...[
              ...library.map((log) => _buildBookCard(log)),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                ),
            ],
          ] else ...[
            _buildStatsContent(),
          ],
        ],
      ),
    );
  }

  Widget _buildBookCard(ReadingLog log) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final logMap = {
      'id': log.id,
      'title': log.title,
      'author': log.authors,
      'authors': log.authors,
      'cover_url': log.coverUrl,
      'cover_image': log.coverUrl,
      'external_id': log.externalId,
      'status': log.status,
      'rating': log.rating,
      'review_text': log.reviewText,
      'start_date': log.startDate?.toIso8601String(),
      'finish_date': log.finishDate?.toIso8601String(),
      'page_count': log.pageCount,
      'current_page': log.currentPage,
      'is_log_public': log.isLogPublic,
    };

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailScreen(book: logMap),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.05),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                width: 50,
                height: 75,
                child: BookCover(
                  src: log.coverUrl,
                  title: log.title ?? '',
                  author: log.authors ?? '',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          log.title ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              fontFamily: 'Lora',
                              height: 1.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!log.isLogPublic)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Icon(Icons.lock_outline_rounded,
                              size: 16, color: Colors.grey.shade400),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(log.authors ?? '',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(log.status)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          log.status.toUpperCase(),
                          style: TextStyle(
                              color: _getStatusColor(log.status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5),
                        ),
                      ),
                      const Spacer(),
                      if (log.rating != null && log.status != 'leyendo') ...[
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFFFD54F), size: 18),
                            const SizedBox(width: 2),
                            Text('${log.rating}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsContent() {
    if (_isLoadingStats) {
      return const Padding(
        padding: EdgeInsets.all(40.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_stats == null || _stats!['is_private'] == true) {
      return Padding(
        padding: const EdgeInsets.all(40.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Las estadísticas de este usuario son privadas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final primaryColor = Theme.of(context).primaryColor;
    final totalMinutes = _stats?['total_minutes'] ?? 0;
    final hours = (totalMinutes / 60).floor();
    final minutes = totalMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    final totalPages = _stats?['total_pages'] ?? 0;
    final finishedThisYear = _stats?['finished_books_this_year'] ?? 0;
    final targetBooks = _stats?['target_books_this_year'] ?? 10;
    final avgRating = _stats?['avg_rating'] ?? '0.0';
    final totalLikes = _stats?['total_likes'] ?? 0;
    final double goalProgress =
        (targetBooks > 0 ? finishedThisYear / targetBooks : 0.0)
            .clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          // Reto Anual
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: goalProgress,
                        strokeWidth: 6,
                        backgroundColor: primaryColor.withValues(alpha: 0.15),
                        color: primaryColor,
                      ),
                      Center(
                        child: Text(
                          '${(goalProgress * 100).round()}%',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.emoji_events_outlined,
                              size: 20, color: primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            'Reto ${_stats?['year'] ?? 2026}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$finishedThisYear de $targetBooks libros leídos este año',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cuadrícula de Métricas
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.access_time_filled_rounded,
                  iconColor: const Color(0xFF4995FF),
                  title: 'Tiempo Total',
                  value: timeStr,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF66BB6A),
                  title: 'Páginas Leídas',
                  value: '$totalPages pág.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.check_circle_rounded,
                  iconColor: const Color(0xFFAB47BC),
                  title: 'Terminados',
                  value: '${_stats?['finished_books'] ?? 0} libros',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.favorite_rounded,
                  iconColor: const Color(0xFFE57373),
                  title: 'Likes Recibidos',
                  value: '$totalLikes',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFFFD54F),
                  title: 'Promedio Stars',
                  value: '$avgRating',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 12),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 2),
          Text(title,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ),
    );
  }
}

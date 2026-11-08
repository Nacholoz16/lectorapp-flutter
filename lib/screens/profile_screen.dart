import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/reading_service.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
import '../models/reading_log.dart';
import 'login_screen.dart';
import '../widgets/edit_book_modal.dart';
import '../widgets/reading_timer_modal.dart';
import '../widgets/book_stats_modal.dart';
import '../services/theme_service.dart';
import '../book_cover.dart';
import '../theme/lector_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  UserProfile? _profile;

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
    ReadingService().libraryChanges.addListener(_onLibraryChanged);
    _loadMyProfile();
  }

  /// La biblioteca cambió (aquí o desde otra pestaña): recargar perfil y estadísticas.
  void _onLibraryChanged() => unawaited(_loadMyProfile());

  @override
  void dispose() {
    ReadingService().libraryChanges.removeListener(_onLibraryChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    if (_profile == null) return;
    setState(() => _isLoadingStats = true);
    try {
      final res = await UserService().getUserStats(_profile!.username);
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

  void _openTimerModal() async {
    if (_profile == null) return;
    final readingLogs = _profile!.library
        .where((l) => l.status.toLowerCase() == 'leyendo')
        .map((l) => {
              'id': l.id,
              'title': l.title,
              'current_page': l.currentPage,
              'page_count': l.pageCount,
            })
        .toList();

    await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReadingTimerModal(readingLogs: readingLogs),
    );
  }

  void _openEditGoalDialog() {
    final controller = TextEditingController(
        text: (_stats?['target_books_this_year'] ?? 10).toString());

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Meta de Lectura Anual'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '¿Cuántos libros quieres leer este año?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0 && val <= 1000) {
                Navigator.pop(dialogContext);
                _saveGoal(val);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Future<void> _saveGoal(int targetBooks) async {
    try {
      await UserService().setReadingGoal(targetBooks);
      if (mounted) unawaited(_loadStats());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo guardar la meta: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
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

  Future<void> _loadMyProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _page = 1;
        _hasMore = true;
        _isFetchingMore = false;
      });
    }
    try {
      final currentUser = await AuthService().getCurrentUser();
      if (currentUser != null && currentUser['username'] != null) {
        final username = currentUser['username'];
        // /users/:username ya incluye la primera página de la biblioteca:
        // no hace falta pedir /library?page=1 por separado.
        final profileData = await UserService().getProfile(username);
        final libraryData =
            profileData['library'] is List ? profileData['library'] as List : const [];

        if (mounted) {
          setState(() {
            _profile = UserProfile.fromJson(profileData);
            _isLoading = false;
            if (libraryData.length < _limit) {
              _hasMore = false;
            }
          });
          unawaited(_loadStats());
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No se pudo obtener los datos de la sesión'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar el perfil: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Theme.of(context).colorScheme.onError,
              onPressed: _loadMyProfile,
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchMore() async {
    if (_isFetchingMore || !_hasMore || _profile == null) return;
    setState(() => _isFetchingMore = true);

    try {
      final nextPage = _page + 1;
      final libraryData = await UserService().getUserLibrary(_profile!.username,
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingMore = false;
          _hasMore = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) => context.lector.statusColor(status);

  Future<void> _onLogout() async {
    await AuthService().logout();
    if (mounted) {
      unawaited(Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      ));
    }
  }

  void _onOpenPrivacyDialog() {
    if (_profile == null) return;
    bool isProfilePublic = _profile!.isProfilePublic;
    bool areStatsPublic = _profile!.areStatsPublic;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ajustes de Privacidad'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Perfil Público'),
                    subtitle: const Text('Permite que otros usuarios vean tu perfil y biblioteca'),
                    value: isProfilePublic,
                    activeTrackColor: Theme.of(context).primaryColor,
                    onChanged: (val) {
                      setDialogState(() => isProfilePublic = val);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Estadísticas Públicas'),
                    subtitle: const Text('Permite que otros usuarios vean tus estadísticas de lectura'),
                    value: areStatsPublic,
                    activeTrackColor: Theme.of(context).primaryColor,
                    onChanged: (val) {
                      setDialogState(() => areStatsPublic = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await UserService().updatePrivacySettings(
                      isProfilePublic: isProfilePublic,
                      areStatsPublic: areStatsPublic,
                    );
                    unawaited(_loadMyProfile());
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onOpenThemeSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                  title: Text('Selecciona un tema',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Claro (Batuvi)'),
                  onTap: () {
                    ThemeService().setTheme('light');
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading: const Icon(Icons.nightlight_outlined),
                  title: const Text('Oscuro (Nativo)'),
                  onTap: () {
                    ThemeService().setTheme('dark');
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: const Text('Pink'),
                  onTap: () {
                    ThemeService().setTheme('pink');
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading: const Icon(Icons.water_drop_outlined),
                  title: const Text('Light Blue'),
                  onTap: () {
                    ThemeService().setTheme('blue');
                    Navigator.pop(context);
                  }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Biblioteca'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_outlined),
            onSelected: (value) {
              if (value == 'privacy') _onOpenPrivacyDialog();
              if (value == 'theme') _onOpenThemeSheet();
              if (value == 'logout') _onLogout();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                  value: 'privacy',
                  child: ListTile(
                      leading: Icon(Icons.lock_outline_rounded),
                      title: Text('Privacidad'),
                      contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(
                  value: 'theme',
                  child: ListTile(
                      leading: Icon(Icons.palette_outlined),
                      title: Text('Apariencia'),
                      contentPadding: EdgeInsets.zero)),
              PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                      leading: Icon(Icons.logout, color: context.lector.danger),
                      title: Text('Cerrar Sesión',
                          style: TextStyle(color: context.lector.danger)),
                      contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: context.lector.iconInactive),
                      const SizedBox(height: 16),
                      const Text('No se pudo cargar el perfil'),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadMyProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    final library = _profile!.library;
    final primaryColor = Theme.of(context).primaryColor;

    return RefreshIndicator(
      onRefresh: _loadMyProfile,
      color: primaryColor,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          // CABECERA PERFIL
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: primaryColor.withValues(alpha: 0.3), width: 3),
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
                  color: context.lector.textSecondary,
                  fontStyle: FontStyle.italic,
                  fontSize: 15),
            ),
          ),
          const SizedBox(height: 16),

          // Chip de perfil dinámico
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _profile!.isProfilePublic
                    ? primaryColor.withValues(alpha: 0.15)
                    : context.lector.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _profile!.isProfilePublic
                        ? Icons.public_rounded
                        : Icons.lock_outline_rounded,
                    size: 16,
                    color: _profile!.isProfilePublic
                        ? primaryColor
                        : context.lector.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _profile!.isProfilePublic
                        ? 'Perfil Público'
                        : 'Perfil Privado',
                    style: TextStyle(
                      color: _profile!.isProfilePublic
                          ? primaryColor
                          : context.lector.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
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
                            color: _selectedTab == 0 ? primaryColor : context.lector.textSecondary,
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
                            color: _selectedTab == 1 ? primaryColor : context.lector.textSecondary,
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
                          size: 64, color: context.lector.textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('Aún no has registrado lecturas.',
                          style: TextStyle(color: context.lector.textSecondary)),
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
                    child: CircularProgressIndicator(
                      color: primaryColor,
                    ),
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
      'is_log_public': log.isLogPublic,
      'page_count': log.pageCount,
      'isbn': log.isbn,
      'published_year': log.publishedYear,
      'current_page': log.currentPage,
    };

    final double progress = (log.pageCount != null && log.pageCount! > 0)
        ? (log.currentPage / log.pageCount!).clamp(0.0, 1.0)
        : 0.0;
    final int percentage = (progress * 100).round();

    return InkWell(
      onTap: () async {
        await showModalBottomSheet<Object?>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => EditBookModal(readingLog: logMap),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.05))),
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
                      offset: const Offset(0, 4)),
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
                  Text(
                    log.title ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        fontFamily: 'Lora',
                        height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(log.authors ?? '',
                      style:
                          TextStyle(fontSize: 13, color: context.lector.textSecondary)),
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
                      IconButton(
                        icon: const Icon(Icons.bar_chart_rounded, size: 20),
                        tooltip: 'Ver Estadísticas',
                        color: primaryColor,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => BookStatsModal(readingLog: logMap),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Editar',
                        color: context.lector.textSecondary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          await showModalBottomSheet<Object?>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => EditBookModal(readingLog: logMap),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      if (log.rating != null && log.status != 'leyendo') ...[
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                color: context.lector.star, size: 18),
                            const SizedBox(width: 2),
                            Text('${log.rating}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: context.lector.textSecondary)),
                          ],
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (!log.isLogPublic)
                        Icon(Icons.lock_outline_rounded,
                            size: 16, color: context.lector.iconInactive),
                    ],
                  ),
                  if (log.status.toLowerCase() == 'leyendo') ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          log.pageCount != null
                              ? '${log.currentPage} / ${log.pageCount} pág.'
                              : '${log.currentPage} pág.',
                          style: TextStyle(
                              fontSize: 11, color: context.lector.textSecondary),
                        ),
                        if (log.pageCount != null)
                          Text(
                            '$percentage%',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryColor),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: primaryColor.withValues(alpha: 0.15),
                        color: primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsContent() {
    final primaryColor = Theme.of(context).primaryColor;
    if (_isLoadingStats) {
      return const Padding(
        padding: EdgeInsets.all(40.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final totalMinutes = _stats?['total_minutes'] ?? 0;
    final hours = (totalMinutes / 60).floor();
    final minutes = totalMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    final totalPages = _stats?['total_pages'] ?? 0;
    final finishedThisYear = _stats?['finished_books_this_year'] ?? 0;
    final targetBooks = _stats?['target_books_this_year'] ?? 10;
    final avgRating = _stats?['avg_rating'] ?? '0.0';
    final double goalProgress = (targetBooks > 0 ? finishedThisYear / targetBooks : 0.0).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          // Botón Iniciar Lectura con Timer
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openTimerModal,
              icon: const Icon(Icons.timer_outlined, size: 22),
              label: const Text('Iniciar Sesión de Lectura',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 20),

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
                          Icon(Icons.emoji_events_outlined, size: 20, color: primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            'Reto ${_stats?['year'] ?? 2026}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: _openEditGoalDialog,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$finishedThisYear de $targetBooks libros leídos este año',
                        style: TextStyle(
                            color: context.lector.textSecondary, fontSize: 13),
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
                  iconColor: context.lector.danger,
                  title: 'Likes Recibidos',
                  value: '${_stats?['total_likes'] ?? 0}',
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
                  iconColor: context.lector.star,
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
              style: TextStyle(color: context.lector.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

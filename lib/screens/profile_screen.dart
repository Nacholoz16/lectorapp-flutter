import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/reading_service.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
import 'login_screen.dart';
import '../widgets/reading_timer_modal.dart';
import '../services/theme_service.dart';
import '../services/preferences_service.dart';
import '../theme/lector_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ui/feedback.dart';
import '../utils/json_utils.dart';

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

  Map<String, dynamic>? _stats;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
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
        showError(context, e, fallback: 'No pudimos guardar tu meta.');
      }
    }
  }

  Future<void> _loadMyProfile() async {
    // Solo la primera carga muestra el indicador; las recargas (p. ej. tras guardar una
    // lectura) actualizan en silencio para no hacer parpadear la pantalla.
    if (mounted && _profile == null) setState(() => _isLoading = true);
    try {
      final currentUser = await AuthService().getCurrentUser();
      if (currentUser != null && currentUser['username'] != null) {
        final username = currentUser['username'];
        // /users/:username ya incluye la primera página de la biblioteca:
        // no hace falta pedir /library?page=1 por separado.
        final profileData = await UserService().getProfile(username);
        if (mounted) {
          setState(() {
            _profile = UserProfile.fromJson(profileData);
            _isLoading = false;
          });
          unawaited(_loadStats());
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          showError(context, 'session',
              fallback: 'No pudimos leer tu sesión. Vuelve a iniciar sesión.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showError(context, e,
            fallback: 'No pudimos cargar tu perfil.', onRetry: _loadMyProfile);
      }
    }
  }

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
              title: const Text('Privacidad'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Perfil público'),
                    subtitle: const Text(
                        'Permite que otros usuarios vean tu perfil y biblioteca'),
                    value: isProfilePublic,
                    activeTrackColor: Theme.of(context).primaryColor,
                    onChanged: (val) {
                      setDialogState(() => isProfilePublic = val);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Estadísticas públicas'),
                    subtitle: const Text(
                        'Permite que otros usuarios vean tus estadísticas de lectura'),
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
    const themes = [
      ('light', 'Crema y salvia', Icons.wb_sunny_outlined),
      ('pink', 'Rosa peonía', Icons.local_florist_outlined),
      ('blue', 'Brisa de mar', Icons.water_drop_outlined),
      ('dark', 'Café de medianoche', Icons.nightlight_outlined),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text('Apariencia', style: ThemeService.titleStyle.copyWith(fontSize: 20)),
            ),
            const SizedBox(height: 8),
            for (final (value, label, icon) in themes)
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () {
                  unawaited(ThemeService().setTheme(value));
                  Navigator.pop(sheetContext);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _onOpenFeedLayoutSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ValueListenableBuilder<FeedLayout>(
          valueListenable: PreferencesService().feedLayout,
          builder: (context, current, _) => RadioGroup<FeedLayout>(
            groupValue: current,
            onChanged: (v) {
              if (v == null) return;
              unawaited(PreferencesService().setFeedLayout(v));
              Navigator.pop(sheetContext);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text('Vista del feed',
                      style: ThemeService.titleStyle.copyWith(fontSize: 20)),
                ),
                const SizedBox(height: 8),
                const RadioListTile<FeedLayout>(
                  value: FeedLayout.cards,
                  title: Text('Tarjetas'),
                  subtitle: Text('Portada grande y reseña resumida'),
                  secondary: Icon(Icons.view_agenda_outlined),
                ),
                const RadioListTile<FeedLayout>(
                  value: FeedLayout.compact,
                  title: Text('Compacta'),
                  subtitle: Text('Más lecturas por pantalla, sin tarjetas'),
                  secondary: Icon(Icons.view_list_outlined),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onSelected: (value) {
              if (value == 'privacy') _onOpenPrivacyDialog();
              if (value == 'theme') _onOpenThemeSheet();
              if (value == 'feed') _onOpenFeedLayoutSheet();
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
              const PopupMenuItem(
                  value: 'feed',
                  child: ListTile(
                      leading: Icon(Icons.view_agenda_outlined),
                      title: Text('Vista del feed'),
                      contentPadding: EdgeInsets.zero)),
              PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                      leading: Icon(Icons.logout, color: context.lector.danger),
                      title: Text('Cerrar sesión',
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
            style: GoogleFonts.lora(
                textStyle: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            )),
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
                        ? 'Perfil público'
                        : 'Perfil privado',
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
          _buildStatsContent(),
        ],
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
    final double goalProgress =
        (targetBooks > 0 ? finishedThisYear / targetBooks : 0.0)
            .clamp(0.0, 1.0);

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
              label: const Text('Empezar a leer',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
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
                          Icon(Icons.emoji_events_outlined,
                              size: 20, color: primaryColor),
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
                  title: 'Tiempo leyendo',
                  value: timeStr,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF66BB6A),
                  title: 'Páginas leídas',
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
                  value: _booksLabel(asInt(_stats?['finished_books'])),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.favorite_rounded,
                  iconColor: context.lector.danger,
                  title: 'Me gusta recibidos',
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
                  title: 'Calificación media',
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
              style:
                  TextStyle(color: context.lector.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  /// "1 libro" / "3 libros".
  String _booksLabel(int n) => n == 1 ? '1 libro' : '$n libros';
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:test_lectorapp/services/reading_service.dart';
import '../widgets/user_card.dart';
import '../utils/json_utils.dart';
import 'package:test_lectorapp/screens/book_detail_screen.dart';
import 'package:test_lectorapp/screens/public_profile_screen.dart';
import '../ui/feedback.dart';
import '../widgets/state_views.dart';
import 'package:intl/intl.dart';
import '../book_cover.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../services/theme_service.dart';
import '../theme/lector_colors.dart';
import '../widgets/edit_book_modal.dart';
import 'search_screen.dart';
import 'tabs_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  bool isLoading = true;
  List<dynamic> feed = [];
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  final int _limit = 10;
  bool _hasMore = true;
  bool _isFetchingMore = false;

  int _newPostsCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    ReadingService().libraryChanges.addListener(_onLibraryChanged);
    _initFeed();
    unawaited(_loadUser());
    unawaited(_loadContinueReading());
  }

  Future<void> _initFeed() async {
    final cachedFeed = await ReadingService().getCachedFeed();
    if (cachedFeed != null && cachedFeed.isNotEmpty) {
      // Pre-decodificar portadas ANTES de revelar el feed
      await _precacheVisibleCovers(cachedFeed);
      if (mounted) {
        setState(() {
          feed = cachedFeed;
          isLoading = false;
        });
      }
      unawaited(_checkForNewPosts());
      _prefetchUpcomingCovers(cachedFeed);
    } else {
      unawaited(loadFeed());
    }
  }

  /// Pregunta solo cuántas publicaciones hay más nuevas que la primera en pantalla
  /// (una respuesta de pocos bytes en vez de descargar la primera página completa).
  Future<void> _checkForNewPosts() async {
    if (feed.isEmpty) return;
    final topId = asInt(feed.first['id'], fallback: -1);
    if (topId < 0) return;
    try {
      final newCount = await ReadingService().countNewPosts(topId);
      if (newCount > 0 && mounted) {
        setState(() => _newPostsCount = newCount);
      }
    } catch (_) {
      // Ignorar fallos de red en background
    }
  }

  /// Cursor para la siguiente página: id del último elemento cargado.
  int? get _lastLoadedId => feed.isEmpty ? null : asInt(feed.last['id']);

  @override
  void dispose() {
    ReadingService().libraryChanges.removeListener(_onLibraryChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMore &&
        _hasMore &&
        !isLoading) {
      _fetchMore();
    }
  }

  Future<void> loadFeed() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        _errorMessage = null;
        _hasMore = true;
        _isFetchingMore = false;
      });
    }
    try {
      final data = await ReadingService().getGlobalFeed(limit: _limit);
      // Pre-decodificar portadas ANTES de revelar el feed
      await _precacheVisibleCovers(data);
      if (mounted) {
        setState(() {
          feed = data;
          isLoading = false;
          _newPostsCount = 0;
          if (data.length < _limit) {
            _hasMore = false;
          }
        });
        unawaited(ReadingService().saveCachedFeed(data));
        _prefetchUpcomingCovers(data);
      }
    } catch (e) {
      if (mounted) {
        // Si ya hay publicaciones (caché o carga anterior) se siguen mostrando y solo se
        // avisa; antes el error reemplazaba el feed entero por un texto.
        final hasContent = feed.isNotEmpty;
        setState(() {
          isLoading = false;
          _errorMessage = hasContent ? null : friendlyError(e);
        });
        if (hasContent) {
          showError(context, e,
              fallback: 'No pudimos actualizar el feed.', onRetry: loadFeed);
        }
      }
    }
  }

  Future<void> _fetchMore() async {
    if (_isFetchingMore || !_hasMore) return;
    setState(() => _isFetchingMore = true);

    try {
      final newData = await ReadingService()
          .getGlobalFeed(beforeId: _lastLoadedId, limit: _limit);
      if (mounted) {
        setState(() {
          feed.addAll(newData);
          _isFetchingMore = false;
          if (newData.length < _limit) {
            _hasMore = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingMore = false);
      }
    }
  }
  Future<void> _handleToggleLike(int index) async {
    final item = feed[index];
    final logId = item['id'];
    if (logId == null) return;

    final currentLiked = asBool(item['has_liked']);
    final currentCount = asInt(item['likes_count']);

    // Tras el await el feed puede haberse recargado: se actualiza la publicación por id,
    // no por posición, para no marcar el like en otra tarjeta.
    void applyToPost(bool liked, int count) {
      final post = feed.firstWhere((p) => p['id'] == logId, orElse: () => null);
      if (post == null) return;
      post['has_liked'] = liked;
      post['likes_count'] = count;
    }

    setState(() => applyToPost(
        !currentLiked, currentLiked ? (currentCount > 0 ? currentCount - 1 : 0) : currentCount + 1));

    try {
      final res = await ReadingService().toggleLike(asInt(logId));
      if (mounted) {
        setState(() => applyToPost(asBool(res['liked']), asInt(res['likes_count'])));
      }
    } catch (_) {
      if (mounted) {
        setState(() => applyToPost(currentLiked, currentCount));
      }
    }
  }

  /// Pre-decodifica las portadas y avatares de los primeros items visibles.
  /// Usa CachedNetworkImageProvider para aprovechar la caché de disco existente.
  /// Timeout de 3s para no bloquear si no hay red ni caché de disco.
  Future<void> _precacheVisibleCovers(List<dynamic> feedData) async {
    if (!mounted) return;
    const visibleCount = 5;
    final urls = <String>[];

    for (int i = 0; i < feedData.length && i < visibleCount; i++) {
      final item = feedData[i];
      // Portada del libro
      final coverUrl = item['cover_url']?.toString();
      if (coverUrl != null && coverUrl.isNotEmpty) {
        urls.add(coverUrl);
      }
      // Avatar del usuario
      String? avatarUrl = item['avatar_url']?.toString();
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        if (avatarUrl.contains('/svg')) {
          avatarUrl = avatarUrl.replaceAll('/svg', '/png');
        }
        urls.add(avatarUrl);
      }
    }

    if (urls.isEmpty) return;

    try {
      await Future.wait(
        urls.map((url) => precacheImage(
              CachedNetworkImageProvider(url),
              context,
            ).catchError((_) {})),
      ).timeout(const Duration(seconds: 3));
    } catch (_) {
      // Timeout expirado: mostrar feed de todos modos
    }
  }

  /// Pre-decodifica las portadas de los items 5-10 en background.
  void _prefetchUpcomingCovers(List<dynamic> feedData) {
    if (!mounted || feedData.length <= 5) return;
    final upcoming = feedData.skip(5).take(5);
    for (final item in upcoming) {
      final coverUrl = item['cover_url']?.toString();
      if (coverUrl != null && coverUrl.isNotEmpty) {
        precacheImage(CachedNetworkImageProvider(coverUrl), context)
            .catchError((_) {});
      }
    }
  }

  // ─── Cabecera: saludo, búsqueda y "Sigues leyendo" ─────────────────────────────────────

  String? _username;
  String? _avatarUrl;
  Map<String, dynamic>? _continueReading;

  Future<void> _loadUser() async {
    final user = await AuthService().getCurrentUser();
    if (!mounted || user == null) return;
    final username = user['username']?.toString();
    // La sesión no siempre trae avatar: mismo respaldo DiceBear que el resto de la app.
    var avatar = (user['avatar'] ?? user['avatar_url'])?.toString();
    if ((avatar == null || avatar.isEmpty) && username != null) {
      avatar = 'https://api.dicebear.com/7.x/bottts/png?seed=$username';
    }
    if (avatar != null && avatar.contains('/svg')) avatar = avatar.replaceAll('/svg', '/png');
    setState(() {
      _username = username;
      _avatarUrl = avatar;
    });
  }

  /// El libro que el usuario está leyendo (el más reciente), para retomarlo con un toque.
  Future<void> _loadContinueReading() async {
    try {
      final library = await ReadingService().getMyLibrary(page: 1, limit: 50);
      final reading = library
          .whereType<Map<String, dynamic>>()
          .where((l) => l['status'] == 'leyendo')
          .toList();
      if (mounted) setState(() => _continueReading = reading.isEmpty ? null : reading.first);
    } catch (_) {
      // Sin red: simplemente no se muestra la tarjeta.
    }
  }

  void _onLibraryChanged() => unawaited(_loadContinueReading());

  Future<void> _refreshAll() => Future.wait([loadFeed(), _loadContinueReading()]);

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'Buenas noches';
    if (h < 13) return 'Buenos días';
    if (h < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshAll,
            edgeOffset: MediaQuery.paddingOf(context).top + 56,
            child: ValueListenableBuilder<FeedLayout>(
              valueListenable: PreferencesService().feedLayout,
              builder: (context, layout, _) => CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildHeader(),
                  SliverToBoxAdapter(child: _buildSearchBar()),
                  if (_continueReading != null)
                    SliverToBoxAdapter(child: _buildContinueReading(_continueReading!)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Lo que lee la comunidad',
                          style: ThemeService.titleStyle
                              .copyWith(fontSize: 18, color: context.lector.textPrimary),
                        ),
                      ),
                    ),
                  ),
                  ..._buildFeedSlivers(layout),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
          if (_newPostsCount > 0) _buildNewPostsBanner(),
        ],
      ),
    );
  }

  /// Cabecera grande con saludo que, al hacer scroll, se reduce a "LectorApp" + avatar.
  Widget _buildHeader() {
    const toolbar = 56.0;
    const expanded = 136.0;
    final c = context.lector;
    final today = DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now());

    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      toolbarHeight: toolbar,
      expandedHeight: expanded,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: LayoutBuilder(builder: (context, constraints) {
        final top = MediaQuery.paddingOf(context).top;
        final t = ((constraints.maxHeight - top - toolbar) / (expanded - toolbar))
            .clamp(0.0, 1.0);
        final collapsed = t < 0.5;
        return Stack(
          children: [
            // Barra compacta (visible al bajar)
            Positioned(
              left: 20,
              right: 8,
              top: top,
              height: toolbar,
              child: IgnorePointer(
                ignoring: !collapsed,
                child: ExcludeSemantics(
                  excluding: !collapsed,
                  child: Opacity(
                    opacity: 1 - t,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('LectorApp',
                              style: ThemeService.titleStyle
                                  .copyWith(fontSize: 20, color: c.textPrimary)),
                        ),
                        _avatarButton(radius: 17),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Saludo grande (visible arriba)
            Positioned(
              left: 20,
              right: 8,
              bottom: 6,
              child: IgnorePointer(
                ignoring: collapsed,
                child: ExcludeSemantics(
                  excluding: collapsed,
                  child: Opacity(
                    opacity: t,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(today,
                                  style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Semantics(
                                header: true,
                                child: Text(
                                  _username != null
                                      ? '${_greeting()},\n$_username'
                                      : _greeting(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: ThemeService.titleStyle.copyWith(
                                      fontSize: 28, height: 1.15, color: c.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _avatarButton(radius: 21),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _avatarButton({required double radius}) {
    final c = context.lector;
    final hasAvatar = _avatarUrl != null && _avatarUrl!.isNotEmpty;
    return Semantics(
      button: true,
      label: 'Ir a mi perfil',
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => TabsScreen.select(context, TabsScreen.profile),
        radius: 26,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.accent, width: 2),
              ),
              child: CircleAvatar(
                radius: radius - 4,
                backgroundColor: c.accent.withValues(alpha: 0.2),
                backgroundImage: hasAvatar ? CachedNetworkImageProvider(_avatarUrl!) : null,
                child: hasAvatar
                    ? null
                    : Icon(Icons.person_rounded, size: radius, color: c.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final c = context.lector;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Semantics(
        button: true,
        label: 'Buscar libros',
        hint: 'Por título, autor o ISBN',
        excludeSemantics: true,
        child: Material(
          color: Theme.of(context).cardColor,
          shape: const StadiumBorder(),
          elevation: isDark ? 0 : 2,
          shadowColor: c.accent.withValues(alpha: 0.35),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => openSearch(context),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  const SizedBox(width: 18),
                  Icon(Icons.search_rounded, color: c.textSecondary),
                  const SizedBox(width: 12),
                  Text('¿Qué estás leyendo?',
                      style: TextStyle(color: c.textSecondary, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueReading(Map<String, dynamic> log) {
    final c = context.lector;
    final title = (log['title'] ?? '').toString();
    final author = (log['author'] ?? log['authors'] ?? '').toString();
    final current = asInt(log['current_page']);
    final total = asInt(log['page_count']);
    final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    final pct = (progress * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Semantics(
        button: true,
        label: 'Sigues leyendo «$title»'
            '${total > 0 ? ', página $current de $total, $pct por ciento' : ''}',
        hint: 'Actualizar página o escribir lo que piensas',
        excludeSemantics: true,
        child: Material(
          color: c.accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showModalBottomSheet<Object?>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => EditBookModal(readingLog: log),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 46,
                    height: 69,
                    child: BookCover(src: log['cover_url'], title: title, author: author),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sigues leyendo',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800, color: c.ink)),
                        const SizedBox(height: 2),
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ThemeService.titleStyle
                                .copyWith(fontSize: 16, color: c.textPrimary)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child:
                                    LinearProgressIndicator(value: progress, minHeight: 5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(total > 0 ? '$pct %' : 'Pág. $current',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700, color: c.ink)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: c.ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFeedSlivers(FeedLayout layout) {
    if (isLoading) {
      return [SliverToBoxAdapter(child: SizedBox(height: 620, child: _buildSkeleton()))];
    }
    if (_errorMessage != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(message: _errorMessage!, onRetry: loadFeed),
        ),
      ];
    }
    if (feed.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.auto_stories_rounded,
            title: 'Aún no hay lecturas compartidas',
            message:
                'Cuando alguien comparta lo que está leyendo, aparecerá aquí. ¿Empiezas tú?',
            actionLabel: 'Buscar un libro',
            actionIcon: Icons.search_rounded,
            onAction: () => openSearch(context),
          ),
        ),
      ];
    }
    final compact = layout == FeedLayout.compact;
    return [
      SliverList.separated(
        itemCount: feed.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => compact
            ? Divider(height: 1, indent: 16, endIndent: 16, color: context.lector.outline)
            : const SizedBox.shrink(),
        itemBuilder: (context, index) {
          if (index == feed.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = feed[index];
          return UserCard(
            item: item,
            mode: 'feed',
            layout: layout,
            onLikeClick: () => _handleToggleLike(index),
            onUserClick: () {
              final username = item['username'];
              if (username != null && username.toString().isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PublicProfileScreen(username: username)),
                );
              }
            },
            onBookClick: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BookDetailScreen(book: item)),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildNewPostsBanner() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 64,
      left: 0,
      right: 0,
      child: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: () {
            _scrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
            loadFeed();
          },
          icon: const Icon(Icons.arrow_upward_rounded, size: 18),
          label: Text(
            _newPostsCount == 1
                ? '1 nueva publicación'
                : '$_newPostsCount nuevas publicaciones',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    final primaryColor = Theme.of(context).primaryColor;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header skeleton
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 60,
                      height: 10,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Review text skeleton
            Container(
              width: double.infinity,
              height: 12,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 200,
              height: 12,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 16),
            // Book embed skeleton
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 90,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 14,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 90,
                          height: 10,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: primaryColor.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

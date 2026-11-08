import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:test_lectorapp/services/reading_service.dart';
import '../widgets/user_card.dart';
import '../utils/json_utils.dart';
import 'package:test_lectorapp/screens/book_detail_screen.dart';
import 'package:test_lectorapp/screens/public_profile_screen.dart';

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

  int _page = 1;
  final int _limit = 10;
  bool _hasMore = true;
  bool _isFetchingMore = false;

  int _newPostsCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initFeed();
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
      _checkForNewPosts();
      _prefetchUpcomingCovers(cachedFeed);
    } else {
      loadFeed();
    }
  }

  Future<void> _checkForNewPosts() async {
    try {
      final freshFeed = await ReadingService().getGlobalFeed(page: 1, limit: _limit);
      if (freshFeed.isNotEmpty && feed.isNotEmpty) {
        final topCachedId = feed.first['id'];
        int newCount = 0;
        for (var post in freshFeed) {
          if (post['id'] > topCachedId) {
            newCount++;
          } else {
            break;
          }
        }
        if (newCount > 0 && mounted) {
          setState(() {
            _newPostsCount = newCount;
          });
        }
      }
    } catch (_) {
      // Ignorar fallos de red en background
    }
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
        !isLoading) {
      _fetchMore();
    }
  }

  Future<void> loadFeed() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        _errorMessage = null;
        _page = 1;
        _hasMore = true;
        _isFetchingMore = false;
      });
    }
    try {
      final data =
          await ReadingService().getGlobalFeed(page: _page, limit: _limit);
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
        ReadingService().saveCachedFeed(data);
        _prefetchUpcomingCovers(data);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar el feed: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: loadFeed,
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchMore() async {
    if (_isFetchingMore || !_hasMore) return;
    setState(() => _isFetchingMore = true);

    try {
      final nextPage = _page + 1;
      final newData =
          await ReadingService().getGlobalFeed(page: nextPage, limit: _limit);
      if (mounted) {
        setState(() {
          _page = nextPage;
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
    final currentCount = (item['likes_count'] is int) ? item['likes_count'] : 0;

    setState(() {
      feed[index]['has_liked'] = !currentLiked;
      feed[index]['likes_count'] = currentLiked ? (currentCount > 0 ? currentCount - 1 : 0) : currentCount + 1;
    });

    try {
      final res = await ReadingService().toggleLike(logId);
      if (mounted) {
        setState(() {
          feed[index]['has_liked'] = res['liked'] == true;
          feed[index]['likes_count'] = res['likes_count'] ?? 0;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          feed[index]['has_liked'] = currentLiked;
          feed[index]['likes_count'] = currentCount;
        });
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // Requerido por AutomaticKeepAliveClientMixin
    return Scaffold(
      appBar: AppBar(
        title: const Text('LectorApp',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: loadFeed,
            color: Theme.of(context).primaryColor,
            child: isLoading
                ? _buildSkeleton()
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : ListView.separated(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 24),
                        itemCount: feed.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          if (index == feed.length) {
                            return const Center(
                                child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ));
                          }
                          return UserCard(
                            item: feed[index],
                            mode: 'feed',
                            onLikeClick: () => _handleToggleLike(index),
                            onUserClick: () {
                              final username = feed[index]['username'];
                              if (username != null && username.toString().isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PublicProfileScreen(username: username),
                                  ),
                                );
                              }
                            },
                            onBookClick: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      BookDetailScreen(book: feed[index]),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
          if (_newPostsCount > 0) _buildNewPostsBanner(),
        ],
      ),
    );
  }

  Widget _buildNewPostsBanner() {
    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
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

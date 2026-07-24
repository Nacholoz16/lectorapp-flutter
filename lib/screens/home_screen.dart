import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:test_lectorapp/services/reading_service.dart';
import '../widgets/user_card.dart';
import 'package:test_lectorapp/screens/book_detail_screen.dart';

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
      // Precachear las portadas visibles antes de mostrar el feed
      await _precacheVisibleImages(cachedFeed);
      if (mounted) {
        setState(() {
          feed = cachedFeed;
          isLoading = false;
        });
      }
      _checkForNewPosts();
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

  /// Pre-decodifica en RAM las portadas de los primeros items visibles.
  /// Timeout de 3 segundos para no bloquear si la red es lenta.
  Future<void> _precacheVisibleImages(List<dynamic> items) async {
    if (!mounted) return;
    final visibleItems = items.take(5); // solo las primeras 5 portadas
    final futures = <Future>[];

    for (final item in visibleItems) {
      final coverUrl = (item['cover_url'] ?? item['cover_image'] ?? '') as String;
      if (coverUrl.isNotEmpty) {
        futures.add(
          precacheImage(
            CachedNetworkImageProvider(coverUrl),
            context,
          ).catchError((_) {}), // ignorar errores individuales
        );
      }
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures).timeout(
        const Duration(seconds: 3),
        onTimeout: () => [], // si pasan 3 seg, continuar sin esperar
      );
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
      // Precachear portadas antes de mostrar el feed
      await _precacheVisibleImages(data);
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

    final currentLiked = item['has_liked'] == true;
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
                ? const Center(child: CircularProgressIndicator())
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
}

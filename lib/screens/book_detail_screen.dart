import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:test_lectorapp/book_cover.dart';
import '../widgets/user_card.dart';
import '../services/book_service.dart';
import '../widgets/log_book_modal.dart';
import 'public_profile_screen.dart';
import '../theme/lector_colors.dart';

class BookDetailScreen extends StatefulWidget {
  final Map<String, dynamic> book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _isLoadingReviews = true;
  List<dynamic> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final id = widget.book['external_id'] ??
        widget.book['google_id'] ??
        widget.book['id'];
    if (id == null) {
      if (mounted) setState(() => _isLoadingReviews = false);
      return;
    }

    try {
      final data = await BookService().getBookFeed(id.toString());
      if (mounted) {
        setState(() {
          _reviews = data;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar reseñas: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = widget.book['cover_url'] ?? '';
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. FONDO INMERSIVO (Blur + Gradiente Suave)
          if (coverUrl.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.55,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: CachedNetworkImage(
                  imageUrl: coverUrl,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    color: primaryColor.withValues(alpha: 0.3),
                  ),
                  placeholder: (context, url) => Container(
                    color: primaryColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),

          // Gradiente para fundir el fondo borroso con el tema
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.1, 0.45, 1.0],
                  colors: [
                    scaffoldBg.withValues(alpha: 0.3),
                    scaffoldBg.withValues(alpha: 0.9),
                    scaffoldBg,
                  ],
                ),
              ),
            ),
          ),

          // 2. CONTENIDO PRINCIPAL SCROLLABLE
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Center(
                          child: SizedBox(
                            width: 150,
                            height: 225,
                            child: BookCover(
                              src: coverUrl,
                              title: widget.book['title'] ?? '',
                              author: widget.book['author'] ??
                                  widget.book['authors'] ??
                                  '',
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        Text(
                          widget.book['title'] ?? 'Sin título',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            fontFamily: 'Lora',
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (widget.book['author'] ??
                                  widget.book['authors'] ??
                                  '')
                              .toString()
                              .toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // METADATA ROW
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            if (widget.book['published_year'] != null)
                              _buildMetaCard(
                                  context,
                                  Icons.calendar_today_rounded,
                                  'AÑO',
                                  widget.book['published_year'].toString(),
                                  isDark),
                            if (widget.book['page_count'] != null)
                              _buildMetaCard(
                                  context,
                                  Icons.menu_book_rounded,
                                  'PÁGS',
                                  widget.book['page_count'].toString(),
                                  isDark),
                            if (widget.book['isbn'] != null)
                              _buildMetaCard(
                                  context,
                                  Icons.qr_code_rounded,
                                  'ISBN',
                                  widget.book['isbn'].toString(),
                                  isDark),
                          ],
                        ),
                        const SizedBox(height: 48),

                        Row(
                          children: [
                            const Text(
                              'Reseñas',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Lora'),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('${_reviews.length}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                // LISTA DE RESEÑAS
                if (_isLoadingReviews)
                  const SliverToBoxAdapter(
                      child: Center(
                          child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: CircularProgressIndicator())))
                else if (_reviews.isEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 48, color: context.lector.textSecondary.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text('Sé el primero en opinar sobre esta obra.',
                                style: TextStyle(color: context.lector.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return UserCard(
                          item: _reviews[index],
                          mode: 'review',
                          onUserClick: () {
                            final username = _reviews[index]['username'];
                            if (username != null && username.toString().isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PublicProfileScreen(username: username),
                                ),
                              );
                            }
                          },
                        );
                      },
                      childCount: _reviews.length,
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),

          // BOTÓN ATRÁS (Efecto Cristal)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color:
                      (isDark ? Colors.black : Colors.white).withValues(alpha: 0.2),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      // FAB
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final successColor = context.lector.success;
          final result = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => LogBookModal(book: widget.book),
          );
          if (result != null && result['saved'] == true) {
            messenger.showSnackBar(
              SnackBar(
                  content: const Text('Guardado en tu biblioteca'),
                  backgroundColor: successColor),
            );
            unawaited(_loadReviews());
          }
        },
        icon: const Icon(Icons.library_add_rounded),
        label: const Text('Añadir a mi biblioteca',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        elevation: 0,
        highlightElevation: 0,
        backgroundColor: primaryColor,
      ),
    );
  }

  Widget _buildMetaCard(BuildContext context, IconData icon, String label,
      String value, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 24),
              const SizedBox(height: 12),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: context.lector.textSecondary,
                      letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

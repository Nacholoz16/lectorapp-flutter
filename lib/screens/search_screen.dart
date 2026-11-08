import 'dart:async';
import 'package:flutter/material.dart';
import 'package:test_lectorapp/book_cover.dart';
import '../services/book_service.dart';
import 'book_detail_screen.dart';
import '../widgets/log_book_modal.dart';
import '../theme/lector_colors.dart';
import '../ui/feedback.dart';
import '../widgets/state_views.dart';

/// Abre la búsqueda como pantalla propia (desde la barra de Inicio o un estado vacío).
Future<void> openSearch(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen(autofocus: true)),
    );

class SearchScreen extends StatefulWidget {
  /// Abre el teclado al entrar (cuando se llega desde la barra de búsqueda de Inicio).
  final bool autofocus;

  const SearchScreen({super.key, this.autofocus = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = false;
  List<dynamic> _results = [];
  String _searchTerm = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchTerm = query);

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.length < 3) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final res = await BookService().searchBooks(query);

      if (mounted) {
        setState(() {
          _results = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showError(context, e, fallback: 'No pudimos buscar ahora. Inténtalo de nuevo.');
      }
    }
  }

  /// Añadir directamente (antes estaba escondido tras un menú ⋮ con una sola opción).
  Future<void> _addToLibrary(dynamic book) async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LogBookModal(book: book),
    );
    if (!mounted) return;
    if (result is Map && result['saved'] == true) {
      showSuccess(context, 'Guardado en tu biblioteca');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar libros'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Título, autor o ISBN...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        tooltip: 'Borrar búsqueda',
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Buscando en bibliotecas...'),
          ],
        ),
      );
    }

    if (_results.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final book = _results[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            elevation: 0,
            color: Theme.of(context).cardColor,
            child: ListTile(
              contentPadding: const EdgeInsets.all(8),
              leading: SizedBox(
                width: 50,
                height: 75,
                child: BookCover(
                  src: book['cover_url'],
                  title: book['title'] ?? '',
                  author: book['authors'] ?? '',
                ),
              ),
              title: Text(book['title'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book['authors'] ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (book['published_year'] != null)
                    Text(book['published_year'].toString(),
                        style:
                            TextStyle(fontSize: 12, color: context.lector.textSecondary)),
                ],
              ),
              trailing: IconButton.outlined(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Añadir «${book['title'] ?? 'este libro'}» a mi biblioteca',
                onPressed: () => _addToLibrary(book),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => BookDetailScreen(book: book)),
                );
              },
            ),
          );
        },
      );
    }

    // Corregido: >= 3 (la búsqueda se dispara con 3 caracteres)
    if (_searchTerm.length >= 3 && _results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No encontramos «$_searchTerm»',
        message: 'Prueba con el autor, con menos palabras o revisa cómo está escrito.',
      );
    }

    return EmptyState(
      icon: Icons.menu_book_rounded,
      title: '¿Qué estás leyendo?',
      message: _searchTerm.isEmpty
          ? 'Busca por título, autor o ISBN y añádelo a tu biblioteca.'
          : 'Escribe al menos 3 letras para buscar.',
    );
  }
}

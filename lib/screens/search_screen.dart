import 'dart:async';
import 'package:flutter/material.dart';
import 'package:test_lectorapp/book_cover.dart';
import '../services/book_service.dart';
import 'book_detail_screen.dart';
import '../widgets/log_book_modal.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en la búsqueda: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _presentOptions(BuildContext context, dynamic book) {
    // Guardamos referencia al ScaffoldMessenger antes de abrir el modal
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Registrar Lectura'),
                onTap: () async {
                  Navigator.pop(sheetContext); // Cerramos el Action Sheet

                  // Abrimos el Modal de Registro
                  final result = await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => LogBookModal(book: book),
                  );

                  if (result != null && result['saved'] == true) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                          content: Text('¡Libro registrado exitosamente!'),
                          backgroundColor: Colors.green),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Libros'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Título, autor o ISBN...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchTerm.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
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
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onPressed: () => _presentOptions(context, book),
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
      return const Center(child: Text('No encontramos libros con ese nombre.'));
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search,
              size: 64, color: Theme.of(context).primaryColor.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Busca para agregar a tu lista.',
              style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

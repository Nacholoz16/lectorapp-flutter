import 'dart:async';

import 'package:flutter/material.dart';

import '../models/reading_log.dart';
import '../services/reading_service.dart';
import '../services/theme_service.dart';
import '../theme/lector_colors.dart';
import '../ui/feedback.dart';
import '../widgets/library_book_tile.dart';
import '../widgets/reading_timer_modal.dart';
import '../widgets/state_views.dart';
import 'search_screen.dart';

/// Pestaña "Mi biblioteca": todos los libros del usuario, filtrados por estado.
/// (Antes vivía dentro de Perfil, mezclada con estadísticas y ajustes.)
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const _filters = [
    ('leyendo', 'Leyendo'),
    ('terminado', 'Terminados'),
    ('abandonado', 'Lo dejé'),
  ];
  static const _pageSize = 50; // límite de la API

  List<ReadingLog> _library = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'leyendo';
  bool _filterChosenByUser = false;

  @override
  void initState() {
    super.initState();
    ReadingService().libraryChanges.addListener(_onLibraryChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    ReadingService().libraryChanges.removeListener(_onLibraryChanged);
    super.dispose();
  }

  void _onLibraryChanged() => unawaited(_load(silent: true));

  /// Carga la biblioteca completa (páginas de 50 hasta agotar). Las bibliotecas personales
  /// son pequeñas y así los filtros y contadores son exactos sin pedir a la API por estado.
  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final all = <ReadingLog>[];
      for (var page = 1;; page++) {
        final data = await ReadingService().getMyLibrary(page: page, limit: _pageSize);
        all.addAll(data.map((e) => ReadingLog.fromJson(e as Map<String, dynamic>)));
        if (data.length < _pageSize || page >= 20) break;
      }
      if (!mounted) return;
      setState(() {
        _library = all;
        _isLoading = false;
        _error = null;
        // Si no hay nada "leyendo", abrir en el primer filtro con libros.
        if (!_filterChosenByUser && _count(_filter) == 0) {
          _filter = _filters
              .map((f) => f.$1)
              .firstWhere((f) => _count(f) > 0, orElse: () => 'leyendo');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_library.isEmpty) _error = friendlyError(e);
      });
      if (_library.isNotEmpty) showError(context, e, onRetry: _load);
    }
  }

  int _count(String status) =>
      _library.where((l) => l.status.toLowerCase() == status).length;

  List<ReadingLog> get _visible =>
      _library.where((l) => l.status.toLowerCase() == _filter).toList();

  int get _finishedThisYear => _library
      .where((l) =>
          l.status.toLowerCase() == 'terminado' &&
          l.finishDate?.year == DateTime.now().year)
      .length;

  Future<void> _openTimer() async {
    final reading = _library
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
      builder: (_) => ReadingTimerModal(readingLogs: reading),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.lector;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(c)),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorState(message: _error!, onRetry: _load),
                )
              else if (_library.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.auto_stories_rounded,
                    title: 'Tu biblioteca está esperando su primer libro',
                    message: 'Busca lo que estás leyendo y empieza a guardar lo que piensas.',
                    actionLabel: 'Buscar libros',
                    actionIcon: Icons.search_rounded,
                    onAction: () => openSearch(context),
                  ),
                )
              else ...[
                SliverToBoxAdapter(child: _buildFilters(c)),
                if (_filter == 'leyendo' && _count('leyendo') > 0)
                  SliverToBoxAdapter(child: _buildTimerCard(c)),
                if (_visible.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'Nada por aquí',
                      message: _filter == 'leyendo'
                          ? '¿Empiezas un libro nuevo?'
                          : 'Aún no hay libros en esta lista.',
                    ),
                  )
                else
                  SliverList.separated(
                    itemCount: _visible.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, indent: 20, endIndent: 20, color: c.outline),
                    itemBuilder: (_, i) => LibraryBookTile(log: _visible[i]),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(LectorColors c) {
    final total = _library.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text('Mi biblioteca',
                      style: ThemeService.titleStyle
                          .copyWith(fontSize: 26, color: c.textPrimary)),
                ),
                if (!_isLoading && total > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${total == 1 ? '1 libro' : '$total libros'} · '
                    '${_finishedThisYear == 1 ? '1 terminado' : '$_finishedThisYear terminados'} este año',
                    style: TextStyle(color: c.textSecondary, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          IconButton.filled(
            onPressed: () => openSearch(context),
            tooltip: 'Añadir un libro',
            style: IconButton.styleFrom(
              backgroundColor: c.ink,
              foregroundColor: c.onInk,
              minimumSize: const Size(48, 48),
            ),
            icon: const Icon(Icons.add_rounded, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(LectorColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          for (final (value, label) in _filters)
            ButtonSegment(value: value, label: Text('$label · ${_count(value)}')),
        ],
        selected: {_filter},
        onSelectionChanged: (s) => setState(() {
          _filter = s.first;
          _filterChosenByUser = true;
        }),
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: c.accent.withValues(alpha: 0.3),
          selectedForegroundColor: c.textPrimary,
          foregroundColor: c.textSecondary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          side: BorderSide(color: c.outline),
          minimumSize: const Size(0, 44),
        ),
      ),
    );
  }

  Widget _buildTimerCard(LectorColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ThemeService.radiusCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeService.radiusCard),
          onTap: _openTimer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: c.ink, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Empezar a leer',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, color: c.textPrimary)),
                      Text('Cronometra tu sesión de hoy',
                          style: TextStyle(color: c.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

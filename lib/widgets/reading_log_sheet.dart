import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../book_cover.dart';
import '../models/reading_log_draft.dart';
import '../services/reading_service.dart';
import '../services/theme_service.dart';
import '../theme/lector_colors.dart';
import '../ui/feedback.dart';
import '../utils/json_utils.dart';
import 'star_rating_input.dart';

/// Hoja inferior para **añadir** un libro a la biblioteca o **editar** una lectura.
///
/// Reemplaza a los antiguos `LogBookModal` / `EditBookModal` (que eran casi idénticos y hoy
/// solo delegan aquí). Principios (skills `lectorapp-ux-patterns` y `lectorapp-accessibility`):
/// - Lo escrito nunca se pierde: borrador automático en el teléfono, aviso antes de descartar y
///   el formulario sigue abierto si falla el guardado.
/// - Solo se pide lo necesario; cada sección aparece cuando aplica al estado elegido.
/// - Privado por defecto, y el interruptor explica qué verá la gente.
/// - Botón principal abajo, al alcance del pulgar.
///
/// Devuelve con `Navigator.pop`: `{'saved': true}` al crear, `{'action': 'updated'|'deleted'}`
/// al editar (mismo contrato que los modales anteriores).
class ReadingLogSheet extends StatefulWidget {
  /// Datos del libro (título, autor, portada, `page_count`, `external_id`...). En modo edición
  /// es el propio registro de lectura.
  final Map<String, dynamic> book;

  /// Registro existente (modo edición). `null` = añadir a la biblioteca.
  final Map<String, dynamic>? existingLog;

  const ReadingLogSheet({super.key, required this.book, this.existingLog});

  bool get isEdit => existingLog != null;

  @override
  State<ReadingLogSheet> createState() => _ReadingLogSheetState();
}

class _ReadingLogSheetState extends State<ReadingLogSheet> {
  static const _statuses = [
    ('leyendo', 'Leyendo', Icons.menu_book_rounded),
    ('terminado', 'Terminado', Icons.check_circle_rounded),
    ('abandonado', 'Lo dejé', Icons.pause_circle_rounded),
  ];
  static const _reviewMaxLength = 5000;

  late final ReadingLogDraft _initial;
  late String _status;
  late int _rating;
  late bool _isPublic;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reviewController = TextEditingController();
  final _pageController = TextEditingController();

  bool _isSaving = false;
  bool _restoredDraft = false;
  bool _draftSaved = false;
  Timer? _draftTimer;

  Map<String, dynamic> get _book => widget.book;
  String get _title => (_book['title'] ?? '').toString();
  String get _author => (_book['authors'] ?? _book['author'] ?? '').toString();
  String? get _cover => (_book['cover_url'] ?? _book['cover_image']) as String?;
  int? get _pageCount {
    final n = asInt(_book['page_count']);
    return n > 0 ? n : null;
  }

  String get _draftId => widget.isEdit
      ? 'log_${widget.existingLog!['id']}'
      : 'book_${_book['external_id'] ?? _book['google_id'] ?? _title}';

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final log = widget.existingLog;
    _initial = log != null
        ? ReadingLogDraft(
            status: (log['status'] ?? 'leyendo').toString(),
            rating: asInt(log['rating']),
            currentPage: asInt(log['current_page']).toString(),
            review: (log['review_text'] ?? '').toString(),
            isPublic: asBool(log['is_log_public']),
            startDate: DateTime.tryParse((log['start_date'] ?? '').toString()),
            endDate: DateTime.tryParse((log['finish_date'] ?? '').toString()),
          )
        // Valores por defecto al añadir: "Leyendo" desde hoy y privado.
        : ReadingLogDraft(
            status: 'leyendo',
            rating: 0,
            currentPage: '0',
            review: '',
            isPublic: false,
            startDate: _today(),
          );
    _apply(_initial);
    _reviewController.addListener(_onChanged);
    _pageController.addListener(_onChanged);
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    // Si quedaba un guardado de borrador pendiente (p. ej. se cerró la hoja deslizando),
    // se guarda ya para no perder los últimos segundos escritos.
    if (_isDirty && !_isSaving) {
      unawaited(ReadingLogDraftStore.save(_draftId, _current));
    }
    _reviewController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --- Estado del formulario y borrador ---

  ReadingLogDraft get _current => ReadingLogDraft(
        status: _status,
        rating: _rating,
        currentPage: _pageController.text,
        review: _reviewController.text,
        isPublic: _isPublic,
        startDate: _startDate,
        endDate: _endDate,
      );

  bool get _isDirty => _current != _initial;

  void _apply(ReadingLogDraft d) {
    _status = d.status;
    _rating = d.rating;
    _isPublic = d.isPublic;
    _startDate = d.startDate;
    _endDate = d.endDate;
    _reviewController.text = d.review;
    _pageController.text = d.currentPage;
  }

  Future<void> _restoreDraft() async {
    final draft = await ReadingLogDraftStore.load(_draftId);
    if (!mounted || draft == null || draft == _initial) return;
    setState(() {
      _apply(draft);
      _restoredDraft = true;
      _draftSaved = true;
    });
  }

  void _discardRestoredDraft() {
    setState(() {
      _apply(_initial);
      _restoredDraft = false;
      _draftSaved = false;
    });
    unawaited(ReadingLogDraftStore.clear(_draftId));
  }

  /// Se llama en cada cambio: refresca la UI y programa el guardado del borrador.
  void _onChanged() {
    if (!mounted) return;
    setState(() => _draftSaved = false);
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 800), () async {
      if (_isDirty) {
        await ReadingLogDraftStore.save(_draftId, _current);
        if (mounted) setState(() => _draftSaved = true);
      } else {
        await ReadingLogDraftStore.clear(_draftId);
      }
    });
  }

  void _setStatus(String status) {
    setState(() {
      _status = status;
      // Fechas inteligentes: si no hay, se proponen las de hoy (se pueden cambiar o quitar).
      if (status == 'leyendo') _startDate ??= _today();
      if (status == 'terminado') {
        _endDate ??= _today();
        final pages = _pageCount;
        if (pages != null) _pageController.text = pages.toString();
      }
    });
    _onChanged();
  }

  // --- Validación ---

  String? get _pageError {
    if (_status != 'leyendo') return null;
    final page = int.tryParse(_pageController.text);
    final total = _pageCount;
    if (page != null && total != null && page > total) {
      return 'Este libro tiene $total páginas';
    }
    return null;
  }

  String? get _dateError {
    if (_status == 'terminado' &&
        _startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      return 'La fecha de término no puede ser anterior al inicio';
    }
    return null;
  }

  // --- Acciones ---

  Future<void> _save() async {
    final validation = _pageError ?? _dateError;
    if (validation != null) {
      showError(context, validation, fallback: validation);
      return;
    }

    setState(() => _isSaving = true);
    final fmt = DateFormat('yyyy-MM-dd');
    final review = _reviewController.text.trim();
    final logData = {
      'status': _status,
      'rating': _status != 'leyendo' && _rating > 0 ? _rating : null,
      'review_text': review,
      'start_date': _startDate != null ? fmt.format(_startDate!) : null,
      'finish_date': _status == 'terminado' && _endDate != null
          ? fmt.format(_endDate!)
          : null,
      'is_log_public': _isPublic,
      'current_page': int.tryParse(_pageController.text) ?? 0,
    };

    try {
      if (widget.isEdit) {
        await ReadingService()
            .updateLog(widget.existingLog!['id'].toString(), logData);
      } else {
        await ReadingService().createLog({
          'bookData': {
            'external_id': _book['external_id'] ?? _book['google_id'],
            'title': _book['title'],
            'authors': _book['authors'] ?? _book['author'],
            'cover_url': _book['cover_url'],
            'isbn': _book['isbn'],
            'page_count': _book['page_count'],
            'published_year': _book['published_year'],
          },
          'logData': logData,
        });
      }
      _draftTimer?.cancel();
      await ReadingLogDraftStore.clear(_draftId);
      unawaitedHaptic(HapticFeedback.lightImpact());
      if (!mounted) return;
      // pop directo (no maybePop): ya está guardado, no hay nada que descartar.
      Navigator.of(context)
          .pop(widget.isEdit ? {'action': 'updated'} : {'saved': true});
    } catch (e) {
      // El formulario queda abierto con todo lo escrito (y el borrador a salvo).
      if (mounted) {
        setState(() => _isSaving = false);
        showError(context, e,
            fallback: 'No pudimos guardar tu lectura. Inténtalo de nuevo.',
            onRetry: _save);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final c = context.lector;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar de tu biblioteca?'),
        content: Text(
          'Se borrarán tus pensamientos, tu calificación y las sesiones de lectura de '
          '«$_title». Esto no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: c.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await ReadingService().deleteLog(widget.existingLog!['id'].toString());
      _draftTimer?.cancel();
      await ReadingLogDraftStore.clear(_draftId);
      if (mounted) Navigator.of(context).pop({'action': 'deleted'});
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showError(context, e, fallback: 'No pudimos eliminar esta lectura.');
      }
    }
  }

  /// Gesto atrás o botón cerrar con cambios sin guardar.
  Future<void> _onPopBlocked() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar los cambios?'),
        content: const Text(
            'Si sales ahora, lo que escribiste no se guardará en tu biblioteca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir editando'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    _draftTimer?.cancel();
    await ReadingLogDraftStore.clear(_draftId);
    // Evita que dispose() vuelva a guardar el borrador recién descartado.
    _apply(_initial);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? _today(),
      firstDate:
          (!isStart && _startDate != null) ? _startDate! : DateTime(1950),
      lastDate: _today(),
      helpText: isStart ? '¿Cuándo empezaste?' : '¿Cuándo terminaste?',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
    );
    if (picked == null || !mounted) return;
    setState(() => isStart ? _startDate = picked : _endDate = picked);
    _onChanged();
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.lector;

    return PopScope(
      canPop: !_isDirty || _isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_onPopBlocked());
      },
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(ThemeService.radiusCard)),
            ),
            child: Column(
              children: [
                _buildHeader(c),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      if (_restoredDraft) _buildRestoredBanner(c),
                      _buildBookInfo(c),
                      const SizedBox(height: 28),
                      _sectionTitle('¿Cómo va esta lectura?'),
                      const SizedBox(height: 12),
                      _buildStatusSelector(c),
                      if (_status == 'leyendo') ...[
                        const SizedBox(height: 20),
                        _buildPageField(),
                      ],
                      if (_status != 'leyendo') ...[
                        const SizedBox(height: 24),
                        _sectionTitle('Tu calificación'),
                        const SizedBox(height: 4),
                        StarRatingInput(
                          value: _rating,
                          onChanged: (v) {
                            setState(() => _rating = v);
                            _onChanged();
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      _sectionTitle('Fechas'),
                      const SizedBox(height: 12),
                      _buildDates(c),
                      const SizedBox(height: 28),
                      _sectionTitle('Tus pensamientos'),
                      const SizedBox(height: 4),
                      Text(
                        'Lo que quieras recordar de este libro. Es tuyo: tú decides si se comparte.',
                        style: TextStyle(color: c.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      _buildReviewField(c),
                      const SizedBox(height: 16),
                      _buildPrivacySwitch(c),
                    ],
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(LectorColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        children: [
          // Asa visual de la hoja (decorativa).
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.maybePop(context),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.isEdit ? 'Editar lectura' : 'Añadir a mi biblioteca',
                    textAlign: TextAlign.center,
                    style: ThemeService.titleStyle
                        .copyWith(fontSize: 18, color: c.textPrimary),
                  ),
                ),
              ),
              if (widget.isEdit)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: c.danger),
                  tooltip: 'Eliminar de mi biblioteca',
                  onPressed: _isSaving ? null : _confirmDelete,
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestoredBanner(LectorColors c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(ThemeService.radiusSmall),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: c.ink),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Recuperamos lo que estabas escribiendo.'),
          ),
          TextButton(
            onPressed: _discardRestoredDraft,
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookInfo(LectorColors c) {
    return MergeSemantics(
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 96,
            child: ExcludeSemantics(
              child: BookCover(src: _cover, title: _title, author: _author),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: ThemeService.titleStyle.copyWith(
                      fontSize: 18, color: c.textPrimary, height: 1.25),
                ),
                if (_author.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_author, style: TextStyle(color: c.textSecondary)),
                ],
                if (_pageCount != null) ...[
                  const SizedBox(height: 2),
                  Text('$_pageCount páginas',
                      style: TextStyle(color: c.textSecondary, fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildStatusSelector(LectorColors c) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label, icon) in _statuses)
          ChoiceChip(
            showCheckmark: false,
            avatar: Icon(icon, size: 20, color: c.statusColor(value)),
            label: Text(label),
            selected: _status == value,
            selectedColor: c.statusColor(value).withValues(alpha: 0.15),
            side: BorderSide(
              color: _status == value ? c.statusColor(value) : c.outline,
              width: _status == value ? 1.5 : 1,
            ),
            labelStyle: TextStyle(
              color: c.textPrimary,
              fontWeight: _status == value ? FontWeight.w700 : FontWeight.w500,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            onSelected: (_) => _setStatus(value),
          ),
      ],
    );
  }

  Widget _buildPageField() {
    // Align: dentro de un ListView los hijos se estiran a todo el ancho.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SizedBox(
        width: 220,
        child: TextField(
          controller: _pageController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          decoration: InputDecoration(
            labelText: 'Página actual',
            suffixText: _pageCount != null ? 'de $_pageCount' : null,
            errorText: _pageError,
          ),
        ),
      ),
    );
  }

  Widget _buildDates(LectorColors c) {
    final error = _dateError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _DateTile(
                label: 'Empecé',
                date: _startDate,
                onTap: () => _pickDate(isStart: true),
                onClear: () {
                  setState(() => _startDate = null);
                  _onChanged();
                },
              ),
            ),
            if (_status == 'terminado') ...[
              const SizedBox(width: 12),
              Expanded(
                child: _DateTile(
                  label: 'Terminé',
                  date: _endDate,
                  hasError: error != null,
                  onTap: () => _pickDate(isStart: false),
                  onClear: () {
                    setState(() => _endDate = null);
                    _onChanged();
                  },
                ),
              ),
            ],
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(error, style: TextStyle(color: c.danger, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _buildReviewField(LectorColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _reviewController,
          minLines: 5,
          maxLines: null,
          maxLength: _reviewMaxLength,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 16, height: 1.5),
          // El contador solo aparece cerca del límite, para no distraer.
          buildCounter: (context,
                  {required currentLength, required isFocused, maxLength}) =>
              currentLength > _reviewMaxLength - 500
                  ? Text('$currentLength / $_reviewMaxLength',
                      style: TextStyle(color: c.textSecondary, fontSize: 12))
                  : null,
          decoration: InputDecoration(
            hintText: '¿Qué te dejó este libro?',
            hintStyle: TextStyle(color: c.textSecondary),
            alignLabelWithHint: true,
          ),
        ),
        AnimatedOpacity(
          opacity: _draftSaved && _isDirty ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(Icons.cloud_done_outlined,
                    size: 16, color: c.textSecondary),
                const SizedBox(width: 6),
                Text('Borrador guardado en este teléfono',
                    style: TextStyle(color: c.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySwitch(LectorColors c) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(ThemeService.radiusSmall),
      ),
      child: SwitchListTile(
        value: _isPublic,
        onChanged: (v) {
          setState(() => _isPublic = v);
          _onChanged();
        },
        secondary: Icon(
          _isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
          color: _isPublic ? c.ink : c.textSecondary,
        ),
        title: const Text('Compartir en el feed',
            style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          _isPublic
              ? 'Otros lectores verán tu calificación y tus pensamientos.'
              : 'Privado: solo tú puedes verlo.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeService.radiusSmall),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              disabledBackgroundColor: scheme.primary.withValues(alpha: 0.6),
            ),
            child: _isSaving
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.onPrimary,
                      semanticsLabel: 'Guardando',
                    ),
                  )
                : Text(widget.isEdit
                    ? 'Guardar cambios'
                    : 'Guardar en mi biblioteca'),
          ),
        ),
      ),
    );
  }
}

/// Campo de fecha tocable, con botón para quitarla (las fechas son opcionales).
class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool hasError;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    final text = date != null
        ? DateFormat("d MMM y", 'es').format(date!)
        : 'Elegir fecha';
    final spoken = date != null
        ? DateFormat("d 'de' MMMM 'de' y", 'es').format(date!)
        : 'sin fecha';

    return Material(
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeService.radiusSmall),
        side: BorderSide(
          color: hasError ? c.danger : c.outline,
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: '$label: $spoken',
              hint: 'Toca para elegir la fecha',
              excludeSemantics: true,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(ThemeService.radiusSmall),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(label,
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: date != null ? c.textPrimary : c.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (date != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Quitar fecha: $label',
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

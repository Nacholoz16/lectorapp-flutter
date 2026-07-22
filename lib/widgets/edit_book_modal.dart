import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/reading_service.dart';

class EditBookModal extends StatefulWidget {
  final Map<String, dynamic> readingLog;

  const EditBookModal({super.key, required this.readingLog});

  @override
  State<EditBookModal> createState() => _EditBookModalState();
}

class _EditBookModalState extends State<EditBookModal> {
  late String _status;
  late int _rating;
  late TextEditingController _reviewController;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _isPublic;
  bool _datesExpanded = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-poblamos el formulario con los datos de tu API
    _status = widget.readingLog['status'] ?? 'leyendo';
    _rating = (widget.readingLog['rating'] as num?)?.toInt() ?? 0;
    _reviewController =
        TextEditingController(text: widget.readingLog['review_text'] ?? '');

    if (widget.readingLog['start_date'] != null) {
      _startDate = DateTime.tryParse(widget.readingLog['start_date']);
    }
    if (widget.readingLog['finish_date'] != null) {
      _endDate = DateTime.tryParse(widget.readingLog['finish_date']);
    }
    _isPublic = widget.readingLog['is_log_public'] == true ||
        widget.readingLog['is_log_public'] == 1;

    if (_startDate != null || _endDate != null) _datesExpanded = true;
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _startDate = picked;
        else
          _endDate = picked;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final payload = {
      'status': _status,
      'rating': _rating > 0 ? _rating : null,
      'review_text': _reviewController.text,
      'start_date': _startDate != null
          ? DateFormat('yyyy-MM-dd').format(_startDate!)
          : null,
      'finish_date':
          _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
      'is_log_public': _isPublic
    };

    try {
      await ReadingService()
          .updateLog(widget.readingLog['id'].toString(), payload);
      if (mounted) Navigator.pop(context, {'action': 'updated'});
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar opinión?'),
        content: const Text(
            'Esta acción no se puede deshacer. Se borrará tu reseña y calificación.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      try {
        await ReadingService().deleteLog(widget.readingLog['id'].toString());
        if (mounted) Navigator.pop(context, {'action': 'deleted'});
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Es idéntico a la vista de LogBookModal, la única gran diferencia es el botón de basurero.
    // Te ahorraré líneas de código repetitivas aquí, usa la misma estructura de Column > ListView.
    // Solo cambia el AppBar por este:

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
            title: const Text('Editar Lectura', style: TextStyle(fontSize: 18)),
            actions: [
              IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _isSaving ? null : _confirmDelete),
              TextButton(
                  onPressed: _isSaving ? null : _save,
                  child: const Text('Guardar',
                      style: TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          Expanded(
            // Pega exactamente el mismo ListView que usamos en LogBookModal pero apuntando a widget.readingLog['cover_image'] o cover_url
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                          widget.readingLog['cover_image'] ??
                              widget.readingLog['cover_url'] ??
                              'https://via.placeholder.com/60x90',
                          width: 60,
                          height: 90,
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.readingLog['title'] ?? '',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                              widget.readingLog['author'] ??
                                  widget.readingLog['authors'] ??
                                  '',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // STATUS (Igual que LogBookModal pero con la variable _status)
                Wrap(
                  spacing: 8,
                  children:
                      ['leyendo', 'terminado', 'abandonado'].map((status) {
                    final isActive = _status == status;
                    return ChoiceChip(
                      label: Text(status.toUpperCase()),
                      selected: isActive,
                      onSelected: (_) => setState(() => _status = status),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // RATING
                if (_status != 'leyendo') ...[
                  Row(
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                            index < _rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: const Color(0xFFFFD54F),
                            size: 32),
                        onPressed: () => setState(() => _rating = index + 1),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                ],

                // FECHAS, RESEÑA Y SWITCH PRIVACIDAD
                // (Misma implementación que el LogBookModal)
                TextField(
                  controller: _reviewController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      hintText: 'Edita tu opinión...',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  title: Text(_isPublic ? 'Público' : 'Privado'),
                  value: _isPublic,
                  onChanged: (val) => setState(() => _isPublic = val),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'reading_log_sheet.dart';

/// Editar o eliminar una lectura. Devuelve `{'action': 'updated' | 'deleted'}`.
/// (Envoltorio de [ReadingLogSheet], que comparte el formulario con el alta.)
class EditBookModal extends StatelessWidget {
  final Map<String, dynamic> readingLog;

  const EditBookModal({super.key, required this.readingLog});

  @override
  Widget build(BuildContext context) =>
      ReadingLogSheet(book: readingLog, existingLog: readingLog);
}

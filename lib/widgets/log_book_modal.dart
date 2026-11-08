import 'package:flutter/material.dart';

import 'reading_log_sheet.dart';

/// Añadir un libro a la biblioteca. Devuelve `{'saved': true}` al guardar.
/// (Envoltorio de [ReadingLogSheet], que comparte el formulario con la edición.)
class LogBookModal extends StatelessWidget {
  final Map<String, dynamic> book;

  const LogBookModal({super.key, required this.book});

  @override
  Widget build(BuildContext context) => ReadingLogSheet(book: book);
}

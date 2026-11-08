/// Helpers para leer valores del JSON de la API de forma tolerante.
///
/// MySQL guarda los booleanos como TINYINT, así que según el endpoint (o una
/// respuesta antigua guardada en caché) pueden llegar como `true`/`false` o `1`/`0`.
bool asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return fallback;
}

/// Entero desde int, num o String; `fallback` si no se puede convertir.
int asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

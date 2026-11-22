/// Textos de desactivar / reactivar (tarea 2.1) y eliminar (2.2) la cuenta. Funciones puras para poder probar
/// singulares, plurales y el caso 0, y para que la pantalla de desactivar, la de cuenta
/// desactivada y los avisos digan lo mismo con las mismas palabras.
library;

/// Qué pasa con las lecturas públicas al desactivar ([publicReadings] = las públicas ahora).
String deactivateReadingsText(int publicReadings) {
  if (publicReadings <= 0) {
    return 'No tienes lecturas públicas: todo sigue siendo solo para ti.';
  }
  final which = publicReadings == 1
      ? 'Tu lectura pública pasará a privada'
      : 'Tus $publicReadings lecturas públicas pasarán a privadas';
  return '$which. Cuando vuelvas, regresarán como estaban.';
}

/// Qué pasa con las lecturas al reactivar ([restorable] = las que volverán a ser públicas).
String reactivateReadingsText(int restorable) {
  if (restorable <= 0) {
    return 'Tus lecturas seguirán siendo privadas; puedes compartirlas cuando quieras.';
  }
  if (restorable == 1) {
    return 'Tu lectura que era pública volverá a ser pública. Las demás seguirán privadas.';
  }
  return 'Tus $restorable lecturas que eran públicas volverán a ser públicas. '
      'Las demás seguirán privadas.';
}

/// Aviso tras reactivar ([restored] = cuántas volvieron a ser públicas).
String reactivatedMessage(int restored) {
  if (restored <= 0) return 'Tu cuenta está activa de nuevo.';
  if (restored == 1) {
    return 'Tu cuenta está activa de nuevo. Volvió a ser pública 1 lectura.';
  }
  return 'Tu cuenta está activa de nuevo. Volvieron a ser públicas $restored lecturas.';
}

/// Aviso tras desactivar ([hidden] = cuántas lecturas públicas pasaron a privadas).
String deactivatedMessage(int hidden) {
  if (hidden <= 0) return 'Tu cuenta está desactivada.';
  if (hidden == 1) {
    return 'Tu cuenta está desactivada. Tu lectura pública ahora es privada.';
  }
  return 'Tu cuenta está desactivada. Tus $hidden lecturas públicas ahora son privadas.';
}

/// Aviso en Login después de eliminar la cuenta (tarea 2.2).
const accountDeletedMessage = 'Tu cuenta y tus datos se eliminaron. Gracias por leer con nosotros.';

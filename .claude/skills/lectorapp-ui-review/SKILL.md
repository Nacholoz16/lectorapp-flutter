---
name: lectorapp-ui-review
description: Auditoría de diseño, UX y accesibilidad de una pantalla o widget de LectorApp, con hallazgos priorizados y, si se pide, aplicación de las correcciones. Usar cuando el usuario pida "revisa el diseño de X", "audita la UX", "qué le falta a esta pantalla", "hazla más profesional/accesible", o antes de un release para repasar las pantallas tocadas.
---

# Revisión de UI/UX de LectorApp

Revisa una pantalla o widget contra las tres skills de referencia y entrega una lista priorizada. **No reescribas pantallas enteras sin que se pida:** primero el informe, después los cambios aprobados.

Skills de referencia (cárgalas si no están en contexto):
- `lectorapp-design-system`: tokens, color, tipografía y componentes.
- `lectorapp-accessibility`: TalkBack, 48 dp, escala de texto y contraste.
- `lectorapp-ux-patterns`: voz, estados, protección de datos y flujos.

## Proceso

1. **Delimitar.** Qué archivo o pantalla (`lib/screens/…`, `lib/widgets/…`) y qué flujo cubre (p. ej. "registrar una lectura desde el detalle del libro").
2. **Leer el código completo** del widget y de los hijos propios que usa.
3. **Búsquedas rápidas** en los archivos revisados:
   ```bash
   grep -nE "Colors\.(grey|white|black|red)|fontSize:|fontFamily: 'Lora'|toUpperCase\(\)|GestureDetector\(|IconButton\(|SnackBar\(|\\\$e|circular\((4|8)\)" <archivos>
   grep -c "tooltip:" <archivos>; grep -c "Semantics" <archivos>
   ```
4. **Ver la pantalla real** si hay un teléfono conectado (`$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe`):
   `adb exec-out screencap -p > shot.png` (guardar en el scratchpad) y mirarla en los 4 temas y con `font_scale 2.0`. Restaurar con `settings put system font_scale 1.0` al terminar.
5. **Evaluar** con la tabla de criterios de abajo.
6. **Informar** en español, agrupado por severidad, con `archivo:línea`, el problema, por qué le importa al lector y la corrección concreta.
7. **Si el usuario aprueba**, aplicar por severidad, correr `flutter analyze` y `flutter test` (y los tests de `meetsGuideline` si existen), y volver a capturar la pantalla.

## Criterios y severidad

| Severidad | Ejemplos |
|---|---|
| **Bloqueante** | Se pierde texto escrito por el usuario; algo privado se publica sin intención; un control no se puede usar con TalkBack; texto < 3:1; overflow o corte con fuente al 200 %; acción destructiva sin confirmación ni deshacer. |
| **Alta** | Texto entre 3:1 y 4.5:1; `IconButton` sin tooltip; objetivo táctil < 48 dp; error técnico crudo (`$e`); falta el estado vacío, de error o de carga; validación solo al enviar. |
| **Media** | Colores, tamaños o radios literales fuera de tokens; MAYÚSCULAS; textos poco claros ("OK", "Enviar"); más de una acción principal; sin háptica o feedback al guardar. |
| **Pulido** | Animaciones, microcopy más cálido, espaciado no múltiplo de 4, detalles visuales en un solo tema. |

## Formato del informe

```
## Revisión: <pantalla> (<archivo>)
Resumen: 2–3 frases sobre cómo se siente hoy y qué es lo más importante.

### Bloqueante
1. <archivo:línea> — <problema>. Por qué importa: <efecto en el lector>. Corrección: <cambio concreto>.
### Alta
…
### Media
…
### Pulido
…

Qué está bien (mantener): …
Siguiente paso propuesto: …
```

Mantener el informe en un máximo de unos 15 hallazgos; si hay más, agrupar los repetidos ("12 tamaños de fuente literales → migrar a textTheme").

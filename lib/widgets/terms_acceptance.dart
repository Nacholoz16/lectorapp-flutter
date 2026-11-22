import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/terms_service.dart';
import '../services/theme_service.dart';
import '../theme/lector_colors.dart';
import '../ui/feedback.dart';

/// Piezas de UI de la aceptación de Términos y Política de privacidad (tarea 1.3):
/// enlaces a los documentos, la casilla del registro y la hoja "Antes de compartir…".

/// Documentos legales publicados en la web (URLs en [Config]).
enum LegalDocument {
  terms('Términos y condiciones', Config.termsUrl),
  privacy('Política de privacidad', Config.privacyUrl);

  const LegalDocument(this.label, this.url);

  final String label;
  final String url;
}

/// Abre un documento legal en una pestaña del navegador dentro de la app (Custom Tabs) y, si no
/// se puede, en el navegador del teléfono. Si tampoco, avisa con la dirección para buscarla.
Future<void> openLegalDocument(BuildContext context, LegalDocument doc) async {
  final uri = Uri.parse(doc.url);
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (!opened && context.mounted) {
    final message =
        'No pudimos abrir la página. La encuentras en ${uri.host}${uri.path}';
    showError(context, message, fallback: message);
  }
}

/// Enlace a un documento legal: botón de texto subrayado en `ink`, con 48 dp de alto y que
/// TalkBack anuncia como enlace ("Términos y condiciones, enlace, se abre en el navegador").
class LegalLinkButton extends StatelessWidget {
  final LegalDocument document;

  const LegalLinkButton({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    // MergeSemantics: el rol de enlace y la pista se suman al nodo del propio botón.
    return MergeSemantics(
      child: Semantics(
        link: true,
        hint: 'Se abre en el navegador',
        child: TextButton.icon(
          onPressed: () => openLegalDocument(context, document),
          style: TextButton.styleFrom(
            foregroundColor: c.ink,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
            ),
          ),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(document.label),
        ),
      ),
    );
  }
}

/// Los dos enlaces legales, uno junto al otro (o uno bajo el otro si no caben, p. ej. con
/// la letra al 200 %).
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 0,
      children: [
        LegalLinkButton(document: LegalDocument.terms),
        LegalLinkButton(document: LegalDocument.privacy),
      ],
    );
  }
}

/// Casilla obligatoria del registro: "Acepto los Términos y la Política de privacidad", con
/// los dos enlaces debajo. Toda la fila marca o desmarca la casilla (objetivo de 48 dp).
class TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Mensaje si se intentó crear la cuenta sin marcarla.
  final String? errorText;

  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          side: BorderSide(
              color: hasError ? c.danger : c.textSecondary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeService.radiusSmall),
          ),
          title: const Text('Acepto los Términos y la Política de privacidad'),
          subtitle: hasError
              ? Text(errorText!, style: TextStyle(color: c.danger))
              : null,
        ),
        const Padding(
          // Alineado con el texto de la casilla (no con el cuadro).
          padding: EdgeInsetsDirectional.only(start: 40),
          child: LegalLinks(),
        ),
      ],
    );
  }
}

/// Qué eligió la persona en la hoja "Antes de compartir…".
enum TermsSheetResult {
  /// Aceptó (la API ya lo registró): se puede publicar.
  accepted,

  /// Prefirió guardar la lectura como privada (no hace falta aceptar nada).
  savePrivately,

  /// "Ahora no" o cerró la hoja: no se guarda nada y el formulario sigue como estaba.
  dismissed,
}

/// Muestra la hoja "Antes de compartir…". Si la persona acepta, registra la aceptación en la
/// API (`POST /account/terms`) antes de devolver [TermsSheetResult.accepted]; si falla, el
/// error se ve dentro de la hoja y puede reintentar.
///
/// Sin arrastre para cerrar (`enableDrag: false`): mientras se registra la aceptación la hoja no
/// debe poder cerrarse a medias, y `enableDrag` no se puede cambiar una vez abierta. Se cierra
/// con sus botones, con atrás o tocando fuera (estos dos, bloqueados por `PopScope` durante
/// la petición).
Future<TermsSheetResult> showTermsSheet(BuildContext context) async {
  final result = await showModalBottomSheet<TermsSheetResult>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    useSafeArea: true,
    builder: (_) => const _TermsSheet(),
  );
  return result ?? TermsSheetResult.dismissed;
}

class _TermsSheet extends StatefulWidget {
  const _TermsSheet();

  @override
  State<_TermsSheet> createState() => _TermsSheetState();
}

class _TermsSheetState extends State<_TermsSheet> {
  bool _accepting = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _accepting = true;
      _error = null;
    });
    try {
      await TermsService().accept();
      if (!mounted) return;
      Navigator.of(context).pop(TermsSheetResult.accepted);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _accepting = false;
        _error = friendlyError(e,
            fallback:
                'No pudimos registrar tu aceptación. Inténtalo de nuevo.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.lector;
    final scheme = Theme.of(context).colorScheme;
    // Durante la petición no se puede cerrar (atrás ni tocar fuera): el resultado debe
    // corresponder a lo que respondió la API.
    return PopScope(
      canPop: !_accepting,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Antes de compartir…',
                style: ThemeService.titleStyle
                    .copyWith(fontSize: 20, color: c.textPrimary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Lo que publicas en el feed lo verán otros lectores, así que se aplican nuestras '
              'reglas de la comunidad: respeto, nada de spam ni contenido ofensivo o ilegal. '
              'Solo tienes que aceptarlas una vez (salvo que las actualicemos: entonces te '
              'avisaremos).',
              style: TextStyle(color: c.textPrimary, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'En la Política de privacidad te contamos qué hacemos con tus datos.',
              style:
                  TextStyle(color: c.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 8),
            const LegalLinks(),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: TextStyle(color: c.danger)),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Al tocar «Aceptar y publicar» aceptas los Términos y condiciones y la Política '
              'de privacidad.',
              style:
                  TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _accepting ? null : _accept,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                disabledBackgroundColor: scheme.primary.withValues(alpha: 0.6),
              ),
              child: _accepting
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: scheme.onPrimary,
                        semanticsLabel: 'Aceptando',
                      ),
                    )
                  : const Text('Aceptar y publicar'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _accepting
                  ? null
                  : () =>
                      Navigator.of(context).pop(TermsSheetResult.savePrivately),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: c.ink,
                side: BorderSide(color: c.ink.withValues(alpha: 0.4)),
              ),
              child: const Text('Guardar solo para mí'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _accepting
                  ? null
                  : () => Navigator.of(context).pop(TermsSheetResult.dismissed),
              style:
                  TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text('Ahora no'),
            ),
          ],
        ),
      ),
    );
  }
}

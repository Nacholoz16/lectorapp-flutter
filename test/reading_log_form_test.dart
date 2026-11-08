import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_lectorapp/models/reading_log_draft.dart';
import 'package:test_lectorapp/services/theme_service.dart';
import 'package:test_lectorapp/widgets/star_rating_input.dart';

ThemeData _testTheme() =>
    ThemeData(extensions: [ThemeService.palettes['light']!.colors]);

void main() {
  group('ReadingLogDraft', () {
    final base = ReadingLogDraft(
      status: 'terminado',
      rating: 4,
      currentPage: '120',
      review: 'Me encantó',
      isPublic: false,
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 11, 2),
    );

    test('ida y vuelta por JSON conserva todos los campos', () {
      expect(ReadingLogDraft.fromJson(base.toJson()), base);
    });

    test('ignora espacios finales, hora del día y ceros a la izquierda', () {
      final same = ReadingLogDraft(
        status: 'terminado',
        rating: 4,
        currentPage: '0120',
        review: 'Me encantó  ',
        isPublic: false,
        startDate: DateTime(2026, 10, 1, 15, 30),
        endDate: DateTime(2026, 11, 2),
      );
      expect(same, base);
    });

    test('detecta cambios reales', () {
      final changed = ReadingLogDraft.fromJson({...base.toJson(), 'review': 'Otra idea'});
      expect(changed == base, isFalse);
    });

    test('el store guarda, carga y borra', () async {
      SharedPreferences.setMockInitialValues({});
      await ReadingLogDraftStore.save('book_x', base);
      expect(await ReadingLogDraftStore.load('book_x'), base);
      await ReadingLogDraftStore.clear('book_x');
      expect(await ReadingLogDraftStore.load('book_x'), isNull);
    });

    test('un borrador corrupto no rompe la carga', () async {
      SharedPreferences.setMockInitialValues({'reading_draft_bad': '{no es json'});
      expect(await ReadingLogDraftStore.load('bad'), isNull);
    });
  });

  group('StarRatingInput', () {
    Future<List<int>> pump(WidgetTester tester, int initial) async {
      final changes = <int>[];
      var value = initial;
      await tester.pumpWidget(MaterialApp(
        theme: _testTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => StarRatingInput(
              value: value,
              onChanged: (v) => setState(() {
                value = v;
                changes.add(v);
              }),
            ),
          ),
        ),
      ));
      return changes;
    }

    testWidgets('tocar una estrella califica y tocarla de nuevo la quita', (tester) async {
      final changes = await pump(tester, 0);
      await tester.tap(find.byKey(const ValueKey('star_4')));
      await tester.pump();
      expect(find.text('4 de 5'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('star_4')));
      await tester.pump();
      expect(find.text('Sin calificar'), findsOneWidget);
      expect(changes, [4, 0]);
    });

    testWidgets('TalkBack lo ve como un control ajustable con valor', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, 3);
      final node = tester.getSemantics(find.byType(StarRatingInput));
      expect(node.label, 'Calificación');
      expect(node.value, '3 de 5 estrellas');
      expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.decrease), isTrue);

      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(tester.getSemantics(find.byType(StarRatingInput)).value, '4 de 5 estrellas');
      handle.dispose();
    });

    testWidgets('cumple tamaño táctil y etiquetas', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, 2);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}

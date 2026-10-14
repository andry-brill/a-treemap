import 'package:any_treemap_example/playground/config.dart';
import 'package:any_treemap_example/playground/inputs.dart';
import 'package:any_treemap_example/playground/property_editor.dart';
import 'package:any_treemap_example/playground/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget form(PlaygroundStore store, String key) => MaterialApp(
  home: Scaffold(
    body: AnimatedBuilder(
      animation: store,
      builder: (context, _) => SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: PropertyEditorField(
            property: propertiesByKey[key]!,
            store: store,
          ),
        ),
      ),
    ),
  ),
);

Finder rowField(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets('property help opens when reached with the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PropertyHelp(
              label: 'Domain scope',
              message: 'Global includes source branches and leaves.',
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Global includes source branches and leaves.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'numeric mapping drafts retain their type when temporarily invalid',
    (tester) async {
      final store = PlaygroundStore()..change('color.scale', 'exact');
      addTearDown(store.dispose);
      await tester.pumpWidget(form(store, 'color.mappings'));
      final before = store.location.uri;
      await tester.enterText(rowField('Exact value').first, '-');
      await tester.pump();
      expect(store.errors, contains('color.mappings'));
      expect(store.location.uri, before);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>).first,
            )
            .initialValue,
        'number',
      );
      await tester.enterText(rowField('Exact value').first, '15');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(store.errors, isEmpty);
      expect(store.committed.rows('color.mappings').first['value'], 15.0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'range conflicts stay drafts until a valid interval is committed',
    (tester) async {
      final store = PlaygroundStore()..change('color.scale', 'numericRange');
      addTearDown(store.dispose);
      await tester.pumpWidget(form(store, 'color.ranges'));
      final before = store.location.uri;
      await tester.enterText(rowField('Maximum').first, '40');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(store.errors, contains('color.ranges'));
      expect(store.location.uri, before);
      await tester.enterText(rowField('Maximum').first, '20');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(store.errors, isEmpty);
      expect(store.committed.rows('color.ranges').first['maximum'], 20);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('palette swatches update the collection and URL atomically', (
    tester,
  ) async {
    final store = PlaygroundStore()..change('color.scale', 'interpolated');
    addTearDown(store.dispose);
    await tester.pumpWidget(form(store, 'color.palette'));
    await tester.tap(find.byTooltip('Choose color').first);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('FF009688'));
    await tester.pumpAndSettle();
    expect(
      store.committed.palette('color.palette').first.toARGB32(),
      Colors.teal.toARGB32(),
    );
    expect(
      store.location.uri.queryParameters['color.palette'],
      contains('FF009688'),
    );
    expect(store.errors, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout rules support adding a row and editing its target', (
    tester,
  ) async {
    final store = PlaygroundStore();
    addTearDown(store.dispose);
    await tester.pumpWidget(form(store, 'layout.rules'));
    await tester.tap(find.text('Add row'));
    await tester.pump();
    expect(store.committed.rows('layout.rules').single['key'], '2');
    await tester.enterText(rowField('Depth or parent key'), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(store.errors, contains('layout.rules'));
    await tester.enterText(rowField('Depth or parent key'), '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(store.committed.rows('layout.rules').single['key'], '3');
    expect(store.errors, isEmpty);
    await tester.ensureVisible(find.text('Add row'));
    await tester.tap(find.text('Add row'));
    await tester.pump();
    expect(store.committed.rows('layout.rules').map((row) => row['key']), [
      '3',
      '2',
    ]);
    expect(store.errors, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

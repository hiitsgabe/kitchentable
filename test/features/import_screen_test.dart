import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/sources/import_controller.dart';
import 'package:kitchentable/features/sources/import_screen.dart';
import 'package:kitchentable/sources/source_registry.dart';
import 'package:kitchentable/sources/model/source_def.dart';

/// An import that has already finished and will not start another.
///
/// The screen runs the import the moment it opens, which is the right thing
/// for a screen and the wrong thing for a case about what it shows after.
class _Finished extends ImportNotifier {
  @override
  ImportState build() =>
      const ImportState(phase: ImportPhase.done, indexed: 36079);

  @override
  Future<void> run(SourceDef source) async {}
}

void main() {
  testWidgets('a finished import offers one row out, and it says done', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [importProvider.overrideWith(_Finished.new)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const Key('open'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ImportScreen(source: knownSources.first),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    // Frames rather than settling: the screen keeps a bar moving.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Finishing used to read exactly like not having started: a note, and
    // the same Back as before. The count is the proof something happened.
    final done = find.byKey(const Key('import-done'));
    expect(done, findsOneWidget);
    expect(
      find.descendant(of: done, matching: find.textContaining('36079 cards')),
      findsOneWidget,
    );

    await tester.tap(done);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byType(ImportScreen),
      findsNothing,
      reason: 'one press, back to whichever screen opened this',
    );
  });
}

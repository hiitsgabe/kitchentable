import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/sources/import_controller.dart';

void main() {
  test('it starts idle with both bars empty', () {
    const s = ImportState();
    expect(s.phase, ImportPhase.idle);
    expect(s.downloadFraction, 0);
    expect(s.indexFraction, 0);
  });

  test('download progress is bytes over total', () {
    const s = ImportState(
      phase: ImportPhase.downloading,
      received: 12355278,
      total: 24710557,
    );
    expect(s.downloadFraction, closeTo(0.5, 0.01));
  });

  test('an unknown total leaves the bar indeterminate rather than lying', () {
    const s = ImportState(phase: ImportPhase.downloading, received: 500);
    expect(s.downloadFraction, isNull);
  });

  test('indexing counts against the estimate', () {
    const s = ImportState(
      phase: ImportPhase.indexing,
      indexed: 18000,
      estimatedRecords: 36000,
    );
    expect(s.indexFraction, closeTo(0.5, 0.01));
  });

  test('indexing never reports more than finished', () {
    const s = ImportState(
      phase: ImportPhase.indexing,
      indexed: 40000,
      estimatedRecords: 36000,
    );
    expect(s.indexFraction, 1.0);
  });

  test('a failure carries its reason', () {
    const s = ImportState(phase: ImportPhase.failed, error: 'no network');
    expect(s.error, 'no network');
  });
}

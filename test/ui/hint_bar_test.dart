import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/atoms/hint_bar.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

void main() {
  testWidgets('it prints every hint it is given', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HintBar(
          metrics: Metrics.of(DeviceClass.handheld),
          hints: const [
            Hint(button: 'A', label: 'open'),
            Hint(button: 'B', label: 'back'),
          ],
        ),
      ),
    ));

    expect(find.text('A'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('back'), findsOneWidget);
  });
}

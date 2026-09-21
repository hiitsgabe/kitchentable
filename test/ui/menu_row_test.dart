import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/atoms/menu_row.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: Column(children: [child])),
    );

void main() {
  testWidgets('an enabled row takes focus', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(_host(MenuRow(
      title: 'Sources',
      subtitle: 'start here',
      focusNode: node,
      metrics: Metrics.of(DeviceClass.handheld),
      onActivate: () {},
    )));

    node.requestFocus();
    await tester.pump();

    expect(node.hasFocus, isTrue);
  });

  testWidgets('a disabled row refuses focus so the D-pad skips it',
      (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(_host(MenuRow(
      title: 'Play',
      subtitle: 'needs a source',
      enabled: false,
      focusNode: node,
      metrics: Metrics.of(DeviceClass.handheld),
      onActivate: () {},
    )));

    node.requestFocus();
    await tester.pump();

    expect(node.hasFocus, isFalse);
  });

  testWidgets('a disabled row does not fire when tapped', (tester) async {
    var fired = 0;

    await tester.pumpWidget(_host(MenuRow(
      title: 'Play',
      subtitle: 'needs a source',
      enabled: false,
      metrics: Metrics.of(DeviceClass.handheld),
      onActivate: () => fired++,
    )));

    await tester.tap(find.text('Play'));
    await tester.pump();

    expect(fired, 0);
  });

  testWidgets('an enabled row fires when tapped', (tester) async {
    var fired = 0;

    await tester.pumpWidget(_host(MenuRow(
      title: 'Sources',
      subtitle: 'start here',
      metrics: Metrics.of(DeviceClass.handheld),
      onActivate: () => fired++,
    )));

    await tester.tap(find.text('Sources'));
    await tester.pump();

    expect(fired, 1);
  });
}

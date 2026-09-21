import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/atoms/menu_row.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host(Widget child, {NavigationMode? navigationMode}) {
  final app = MaterialApp(home: Scaffold(body: Column(children: [child])));
  if (navigationMode == null) return app;
  return MediaQuery(
    data: MediaQueryData(navigationMode: navigationMode),
    child: app,
  );
}

MenuRow _row({
  String title = 'Sources',
  bool enabled = true,
  FocusNode? focusNode,
  required VoidCallback onActivate,
}) =>
    MenuRow(
      title: title,
      subtitle: 'start here',
      enabled: enabled,
      focusNode: focusNode,
      metrics: Metrics.of(DeviceClass.handheld),
      onActivate: onActivate,
    );

void main() {
  testWidgets('an enabled row takes focus', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(_host(_row(focusNode: node, onActivate: () {})));
    node.requestFocus();
    await tester.pump();

    expect(node.hasFocus, isTrue);
  });

  testWidgets('an enabled row fires when tapped', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_host(_row(onActivate: () => fired++)));

    await tester.tap(find.text('Sources'));
    await tester.pump();

    expect(fired, 1);
  });

  testWidgets('an enabled row fires when the select button is pressed',
      (tester) async {
    var fired = 0;
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      _host(_row(focusNode: node, onActivate: () => fired++)),
    );
    node.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(fired, 1);
  });

  testWidgets('an enabled row fires when the gamepad A button is pressed',
      (tester) async {
    var fired = 0;
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      _host(_row(focusNode: node, onActivate: () => fired++)),
    );
    node.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();

    expect(fired, 1);
  });

  testWidgets('a disabled row does not fire when tapped', (tester) async {
    var fired = 0;
    await tester.pumpWidget(
      _host(_row(title: 'Play', enabled: false, onActivate: () => fired++)),
    );

    await tester.tap(find.text('Play'));
    await tester.pump();

    expect(fired, 0);
  });

  testWidgets('a D-pad can reach a disabled row so its reason can be read',
      (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(_host(
      _row(title: 'Play', enabled: false, focusNode: node, onActivate: () {}),
      navigationMode: NavigationMode.directional,
    ));
    node.requestFocus();
    await tester.pump();

    expect(node.hasFocus, isTrue,
        reason: 'the subtitle on a dead row is how a player learns what to do');
  });

  testWidgets('a disabled row does not fire when the select button is pressed',
      (tester) async {
    var fired = 0;
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(_host(
      _row(
        title: 'Play',
        enabled: false,
        focusNode: node,
        onActivate: () => fired++,
      ),
      navigationMode: NavigationMode.directional,
    ));
    node.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(fired, 0);
  });
}

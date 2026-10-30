import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/room/entry.dart';
import 'features/room/room_controller.dart';
import 'ui/background/backdrop.dart';
import 'ui/background/backdrop_controller.dart';
import 'ui/input/pad.dart';
import 'table/room/room.dart';
import 'ui/tokens/theme.dart';

/// The app's one navigator, so a room link handled outside any widget can
/// take it back to its first screen.
final appNavigator = GlobalKey<NavigatorState>();

/// Where a room link that reaches the running app lands: iOS hands every link
/// over this way (one it was launched on too), Android one that arrives with
/// the app already open, and the web build one pasted into the address bar.
///
/// Registered in `main` before the app is built, so a link iOS hands over
/// while the app is starting finds somebody listening, and ahead of the
/// [MaterialApp]'s own observer, so a room link is answered here and never
/// pushed as a named route this app does not have.
class RoomLinks with WidgetsBindingObserver {
  RoomLinks(this._container);

  final ProviderContainer _container;

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final link = routeInformation.uri.toString();
    final code = codeFrom(link);
    if (code == null) return false;
    // Already there: a host who follows their own link stays the host.
    if (_container.read(roomProvider)?.code == code) return true;

    // Back to the first screen before it changes, so nothing pushed on top is
    // left over a screen swapped out underneath it. The first screen then
    // opens the room, or the first-run wizard on the way to it. Before the
    // first frame there is no navigator yet and the first screen simply
    // starts out on the room.
    appNavigator.currentState?.popUntil((route) => route.isFirst);
    _container.read(roomProvider.notifier).arrive(link);
    _container.read(launchLinkProvider.notifier).arrived(link);
    return true;
  }
}

class KitchentableApp extends ConsumerWidget {
  const KitchentableApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      navigatorKey: appNavigator,
      title: 'Kitchentable',
      // The picked colour reaches the whole app through the theme, so a
      // border is the colour the background is rather than the pink it was
      // written as.
      theme: kitchentableTheme(accent: ref.watch(backdropProvider).top),
      debugShowCheckedModeBanner: false,
      // One backdrop for the whole app, under every route. Putting it inside
      // each screen would restart the animation on every push, which reads as
      // a flicker every time you open anything.
      // Around the navigator, so B and Escape reach every route, and the
      // pad driver aims at whatever has focus in any of them.
      builder: (context, child) => PadInput(
        child: Backdrop(
          style: ref.watch(backdropProvider),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      // Not the menu directly: a tab opened on a room link has somewhere else
      // to be. See [Entry].
      home: const Entry(),
    );
  }
}

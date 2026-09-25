import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/room/entry.dart';
import 'ui/background/backdrop.dart';
import 'ui/background/backdrop_controller.dart';
import 'ui/tokens/theme.dart';

class KitchentableApp extends ConsumerWidget {
  const KitchentableApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'kitchentable',
      theme: kitchentableTheme(),
      debugShowCheckedModeBanner: false,
      // One backdrop for the whole app, under every route. Putting it inside
      // each screen would restart the animation on every push, which reads as
      // a flicker every time you open anything.
      builder: (context, child) => Backdrop(
        style: ref.watch(backdropProvider),
        child: child ?? const SizedBox.shrink(),
      ),
      // Not the menu directly: a tab opened on a room link has somewhere else
      // to be. See [Entry].
      home: const Entry(),
    );
  }
}

import 'package:flutter/material.dart';

import 'ui/tokens/palette.dart';
import 'ui/tokens/theme.dart';

class KitchentableApp extends StatelessWidget {
  const KitchentableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kitchentable',
      theme: kitchentableTheme(),
      debugShowCheckedModeBanner: false,
      home: const _EmptyTable(),
    );
  }
}

/// Stands in for the lobby until there is one. It says out loud what the first
/// run of the finished app will also say: there are no cards here yet, and
/// nothing was fetched on your behalf.
class _EmptyTable extends StatelessWidget {
  const _EmptyTable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'kitchentable',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 10),
              const Text(
                'No sources configured.\nThis app does not know a single card yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Palette.inkMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

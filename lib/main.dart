import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  final container = ProviderContainer();
  WidgetsFlutterBinding.ensureInitialized().addObserver(RoomLinks(container));
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const KitchentableApp(),
    ),
  );
}

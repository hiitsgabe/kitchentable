import 'package:flutter/material.dart';

import 'features/menu/menu_screen.dart';
import 'ui/tokens/theme.dart';

class KitchentableApp extends StatelessWidget {
  const KitchentableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kitchentable',
      theme: kitchentableTheme(),
      debugShowCheckedModeBanner: false,
      home: const MenuScreen(),
    );
  }
}

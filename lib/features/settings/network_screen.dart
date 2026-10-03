import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/text_field_box.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import 'network.dart';
import 'settings_parts.dart';

/// The one advanced thing in the app, on a screen of its own.
///
/// Three fields nobody fills in unless the room has told them to, and on the
/// main settings screen they were half of it. The benchmark's rule: primary
/// settings in front, advanced behind a subscreen.
class NetworkScreen extends ConsumerStatefulWidget {
  const NetworkScreen({super.key});

  @override
  ConsumerState<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends ConsumerState<NetworkScreen> {
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _credential = TextEditingController();
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    final turn = ref.read(turnProvider);
    _url.text = turn?.url ?? '';
    _username.text = turn?.username ?? '';
    _credential.text = turn?.credential ?? '';
  }

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _credential.dispose();
    super.dispose();
  }

  void _set() {
    _typing = true;
    ref
        .read(turnProvider.notifier)
        .set(
          url: _url.text,
          username: _username.text,
          credential: _credential.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );

    ref.listen(turnProvider, (_, turn) {
      if (_typing) return;
      _url.text = turn?.url ?? '';
      _username.text = turn?.username ?? '';
      _credential.text = turn?.credential ?? '';
    });

    return ScreenFrame(
      metrics: m,
      title: 'Network',
      label: ref.watch(turnProvider) == null ? 'no relay' : 'a relay is set',
      onBack: () => Navigator.of(context).maybePop(),
      children: [
        SettingsCaption(
          metrics: m,
          text:
              'Only for when two phones on different networks cannot reach '
              'each other, which the room says when it happens. A relay for '
              'the connection itself: a friend running one, or a public one. '
              'Left empty, none is used.',
        ),
        SettingsLabel(metrics: m, text: 'a TURN server'),
        TextFieldBox(
          key: const Key('turn-url'),
          metrics: m,
          controller: _url,
          hint: 'turn:host:3478',
          onChanged: (_) => _set(),
        ),
        SizedBox(height: m.scaled(6)),
        TextFieldBox(
          key: const Key('turn-username'),
          metrics: m,
          controller: _username,
          hint: 'username',
          onChanged: (_) => _set(),
        ),
        SizedBox(height: m.scaled(6)),
        TextFieldBox(
          key: const Key('turn-credential'),
          metrics: m,
          controller: _credential,
          hint: 'password',
          onChanged: (_) => _set(),
        ),
        SizedBox(height: m.scaled(16)),
        Text(
          'deploy/coturn in the repository runs one, if nobody at the table '
          'has one already.',
          style: pixel(
            size: m.scaled(11),
            weight: 500,
            height: 1.45,
            color: Palette.inkFaint,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/atoms/kitchentable_mark.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/pressable.dart';
import '../../ui/atoms/slab.dart';
import '../../ui/atoms/tray.dart';
import '../../ui/atoms/toast.dart';
import '../../ui/organisms/screen_frame.dart';
import 'settings_parts.dart';
import '../../ui/tokens/app_palette.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';

/// The commit this build was made from, the same stamp the room screen shows.
///
/// Read here rather than imported from the room, because the two screens have
/// nothing to do with each other and a compile time constant is the same
/// value wherever it is read.
const _build = String.fromEnvironment('BUILD', defaultValue: 'dev');

/// One line in a shelf: a name, a word about it, and a link to copy.
typedef Credit = ({String name, String note, String url});

/// Who made it, what it is made of, and how to say thanks.
///
/// Modelled on retro_toolbox's About screen, which is the other app in this
/// family: the mark and the build at the top, a word about playing fair, then
/// the source, the people, the long list of what this stands on, and the
/// coffee. Drawn with this app's own slabs and wells rather than borrowed
/// Material, so it belongs on the shelf next to the rest of Settings.
///
/// A link is copied rather than opened. The app carries no browser opener and
/// the room code already works this way, so a tap on anything here puts its
/// address on the clipboard and says so.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  static const _authors = <Credit>[
    (name: 'hiitsgabe', note: 'gabeismy.name', url: 'https://gabeismy.name'),
  ];

  /// Where the cards come from, and what carries a game between phones.
  static const _standsOn = <Credit>[
    (
      name: 'Scryfall',
      note: 'Magic card data and pictures',
      url: 'https://scryfall.com',
    ),
    (
      name: 'MTGJSON',
      note: 'the sets a draft is made of',
      url: 'https://mtgjson.com',
    ),
    (
      name: 'pokemon-tcg-data',
      note: 'Pokemon cards, the data behind the TCG API',
      url: 'https://github.com/PokemonTCG/pokemon-tcg-data',
    ),
    (
      name: 'Nostr',
      note: 'the public relays a table meets and plays on',
      url: 'https://nostr.com',
    ),
    (
      name: 'Pixelify Sans',
      note: 'the lettering, by Stijn Kramer (OFL)',
      url: 'https://fonts.google.com/specimen/Pixelify+Sans',
    ),
    (name: 'flutter', note: 'flutter.dev', url: 'https://flutter.dev'),
    (
      name: 'flutter_riverpod',
      note: 'pub.dev/packages/flutter_riverpod',
      url: 'https://pub.dev/packages/flutter_riverpod',
    ),
    (
      name: 'drift',
      note: 'pub.dev/packages/drift',
      url: 'https://pub.dev/packages/drift',
    ),
    (
      name: 'flutter_webrtc',
      note: 'voice, pub.dev/packages/flutter_webrtc',
      url: 'https://pub.dev/packages/flutter_webrtc',
    ),
    (
      name: 'web_socket_channel',
      note: 'the relays, pub.dev/packages/web_socket_channel',
      url: 'https://pub.dev/packages/web_socket_channel',
    ),
    (
      name: 'bip340',
      note: 'signing, pub.dev/packages/bip340',
      url: 'https://pub.dev/packages/bip340',
    ),
    (
      name: 'mobile_scanner',
      note: 'the QR camera, pub.dev/packages/mobile_scanner',
      url: 'https://pub.dev/packages/mobile_scanner',
    ),
    (
      name: 'qr_flutter',
      note: 'the QR a room shows, pub.dev/packages/qr_flutter',
      url: 'https://pub.dev/packages/qr_flutter',
    ),
    (
      name: 'gamepads',
      note: 'controller play, pub.dev/packages/gamepads',
      url: 'https://pub.dev/packages/gamepads',
    ),
    (
      name: 'mesh_gradient',
      note: 'the backdrop, pub.dev/packages/mesh_gradient',
      url: 'https://pub.dev/packages/mesh_gradient',
    ),
    (
      name: 'cached_network_image',
      note: 'card pictures, pub.dev/packages/cached_network_image',
      url: 'https://pub.dev/packages/cached_network_image',
    ),
    (
      name: 'file_picker',
      note: 'importing a file, pub.dev/packages/file_picker',
      url: 'https://pub.dev/packages/file_picker',
    ),
    (
      name: 'shared_preferences',
      note: 'pub.dev/packages/shared_preferences',
      url: 'https://pub.dev/packages/shared_preferences',
    ),
  ];

  void _copy(BuildContext context, String url) {
    Clipboard.setData(ClipboardData(text: url));
    Toast.show(context, 'Link copied', icon: Icons.check_rounded);
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

    return ScreenFrame(
      metrics: m,
      title: 'Credits',
      label: 'who made it, and of what',
      onBack: () => Navigator.of(context).maybePop(),
      children: [
        _Head(metrics: m),
        SizedBox(height: m.scaled(18)),

        // Retro's "Play fair" box. Here it is the thing that most needs
        // saying: the app ships empty and the cards are not ours.
        Well(
          metrics: m,
          edge: Palette.attention,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    size: m.scaled(18),
                    color: Palette.attention,
                  ),
                  SizedBox(width: m.scaled(8)),
                  Text('Bring your own cards', style: slabText(m.scaled(13))),
                ],
              ),
              SizedBox(height: m.scaled(8)),
              Text(
                'kitchentable is a table, not a card shop. It is not affiliated '
                'with Wizards of the Coast, Hasbro, The Pokemon Company or '
                'Nintendo. Card names, text and pictures belong to their '
                'publishers; you point the app at a source and what arrives '
                'came from you asking for it.',
                style: pixel(
                  size: m.scaled(12),
                  weight: 500,
                  height: 1.5,
                  color: Palette.inkMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: m.scaled(16)),

        MenuRow(
          key: const Key('credits-source'),
          title: 'Open source',
          subtitle: 'github.com/hiitsgabe/kitchentable',
          icon: Icons.code_rounded,
          tone: SlabTone.cool,
          metrics: m,
          autofocus: true,
          onActivate: () =>
              _copy(context, 'https://github.com/hiitsgabe/kitchentable'),
        ),
        SizedBox(height: m.scaled(12)),
        _Shelf(
          metrics: m,
          icon: Icons.person_rounded,
          title: 'Authors',
          items: _authors,
          onPick: (url) => _copy(context, url),
        ),
        SizedBox(height: m.scaled(12)),
        _Shelf(
          metrics: m,
          icon: Icons.favorite_rounded,
          title: 'Credits',
          items: _standsOn,
          onPick: (url) => _copy(context, url),
        ),

        SizedBox(height: m.scaled(24)),
        SettingsLabel(metrics: m, text: 'say thanks'),
        Text(
          'This app is free and made in spare time. If it earns you an evening, '
          'a coffee keeps it going.',
          style: pixel(
            size: m.scaled(12),
            weight: 500,
            height: 1.5,
            color: Palette.inkMuted,
          ),
        ),
        SizedBox(height: m.scaled(12)),
        MenuRow(
          key: const Key('credits-coffee'),
          title: 'Buy me a coffee',
          subtitle: 'buymeacoffee.com/hiitsgabe',
          icon: Icons.coffee_rounded,
          tone: SlabTone.warm,
          metrics: m,
          onActivate: () =>
              _copy(context, 'https://buymeacoffee.com/hiitsgabe'),
        ),

        SizedBox(height: m.scaled(24)),
        Center(
          child: Text(
            'Made for the kitchen table.',
            style: pixel(
              size: m.scaled(11),
              weight: 500,
              color: Palette.inkFaint,
            ),
          ),
        ),
        SizedBox(height: m.scaled(8)),
      ],
    );
  }
}

/// The mark, the name split into two weights the way the menu does it, and
/// the build under it.
class _Head extends StatelessWidget {
  const _Head({required this.metrics});

  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Column(
      children: [
        KitchentableMark(size: m.scaled(72)),
        SizedBox(height: m.scaled(12)),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'kitchen'),
              TextSpan(
                text: 'table',
                style: TextStyle(color: context.palette.accent),
              ),
            ],
          ),
          style: pixel(size: m.scaled(24), weight: 700, outlined: true),
        ),
        SizedBox(height: m.scaled(6)),
        Text(
          'dev.hiitsgabe.kitchentable',
          style: pixel(
            size: m.scaled(10),
            weight: 500,
            color: Palette.inkFaint,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: m.scaled(3)),
        Text(
          'build $_build',
          style: pixel(
            size: m.scaled(11),
            weight: 500,
            color: Palette.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// A group that opens to a list, the way retro_toolbox's expandable card does,
/// drawn as a slab that unfolds a well of rows.
class _Shelf extends StatefulWidget {
  const _Shelf({
    required this.metrics,
    required this.icon,
    required this.title,
    required this.items,
    required this.onPick,
  });

  final Metrics metrics;
  final IconData icon;
  final String title;
  final List<Credit> items;
  final void Function(String url) onPick;

  @override
  State<_Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<_Shelf> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Slab(
          key: Key('shelf-${widget.title.toLowerCase()}'),
          metrics: m,
          tone: SlabTone.plain,
          onActivate: () => setState(() => _open = !_open),
          semanticLabel:
              '${widget.title}, ${widget.items.length}. ${_open ? 'Open' : 'Closed'}',
          child: Row(
            children: [
              Icon(widget.icon, size: m.scaled(20), color: Palette.slabInk),
              SizedBox(width: m.scaled(12)),
              Expanded(
                child: Text(widget.title, style: slabText(m.scaled(16))),
              ),
              Text(
                '${widget.items.length}',
                style: pixel(
                  size: m.scaled(13),
                  weight: 600,
                  color: const Color(0xC0FFFFFF),
                ),
              ),
              SizedBox(width: m.scaled(8)),
              Icon(
                _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: m.scaled(20),
                color: Palette.slabInk,
              ),
            ],
          ),
        ),
        if (_open) ...[
          SizedBox(height: m.scaled(8)),
          Well(
            metrics: m,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, item) in widget.items.indexed) ...[
                  if (i > 0) SizedBox(height: m.scaled(6)),
                  _Row(metrics: m, item: item, onPick: widget.onPick),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// One line in a shelf, the ring on it, that copies its link when pressed.
class _Row extends StatelessWidget {
  const _Row({required this.metrics, required this.item, required this.onPick});

  final Metrics metrics;
  final Credit item;
  final void Function(String url) onPick;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Pressable(
      metrics: m,
      onPress: () => onPick(item.url),
      ring: false,
      semanticLabel: '${item.name}. ${item.note}. Copies the link',
      builder: (context, state) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: m.scaled(10),
          vertical: m.scaled(9),
        ),
        decoration: BoxDecoration(
          color: state.focused || state.hovered
              ? context.palette.tileFocused
              : Palette.surface,
          borderRadius: BorderRadius.circular(m.scaled(8)),
          border: Border.all(
            color: state.focused ? context.palette.accent : Palette.surfaceEdge,
            width: state.focused ? m.focusRing : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: pixel(size: m.scaled(13), weight: 600),
                  ),
                  SizedBox(height: m.scaled(2)),
                  Text(
                    item.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: pixel(
                      size: m.scaled(11),
                      weight: 500,
                      height: 1.35,
                      color: Palette.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: m.scaled(8)),
            Icon(
              Icons.copy_rounded,
              size: m.scaled(15),
              color: Palette.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}

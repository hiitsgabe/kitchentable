import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/basic_lands.dart';
import '../../net/loopback_transport.dart';
import '../../sources/model/catalog_card.dart';
import 'draft_controller.dart';
import 'draft_room.dart';
import 'draft_state.dart';
import 'draft_screen.dart';

/// The draft on one device, for looking at.
///
/// A scripted pod of two seats with a bot in the other chair, wired over the
/// loopback transport so the real [DraftRoom] drives it: the bot drains its
/// packs and passes them along, so the human's queue fills and the pack crack,
/// the picking and, once the packs are spent, the deck builder all play out
/// exactly as they would on the wire. The cards are made up here and fed in by
/// overriding the catalog providers, so it needs no import and no network.
class DraftDemoScreen extends StatefulWidget {
  const DraftDemoScreen({super.key, this.sealed = false});

  final bool sealed;

  @override
  State<DraftDemoScreen> createState() => _DraftDemoScreenState();
}

class _DraftDemoScreenState extends State<DraftDemoScreen> {
  final _net = LoopbackNetwork();
  late final _DemoPod _pod;
  late final DraftRoom _host;
  DraftRoom? _bot;

  @override
  void initState() {
    super.initState();
    _pod = _buildPod(sealed: widget.sealed);

    final meT = _net.join('me');
    final botT = _net.join('bot');

    // The bot is an ordinary guest that takes the first card of whatever pack
    // it is handed, which keeps the human's queue moving.
    final bot = _bot = DraftRoom.guest(transport: botT, hostId: 'me');
    bot.views.listen((v) {
      final pack = v.pack;
      if (v.phase == DraftPhase.picking && pack != null && pack.isNotEmpty) {
        Future.delayed(
          const Duration(milliseconds: 250),
          () => bot.pick(pack.first.uuid),
        );
      }
    });

    _host = DraftRoom.fromPacks(
      transport: meT,
      seatIds: const ['me', 'bot'],
      sealed: widget.sealed,
      packsPerSeat: _pod.packs,
    );
  }

  @override
  void dispose() {
    _host.close();
    _bot?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        draftCardsProvider.overrideWith((ref) async => _pod.cards),
        draftBasicsProvider.overrideWith((ref) async => _pod.basics),
      ],
      child: _DemoDriver(host: _host),
    );
  }
}

/// Lives inside the demo's own provider scope so the room it adopts and the
/// overridden catalog are the ones the screen reads.
class _DemoDriver extends ConsumerStatefulWidget {
  const _DemoDriver({required this.host});

  final DraftRoom host;

  @override
  ConsumerState<_DemoDriver> createState() => _DemoDriverState();
}

class _DemoDriverState extends ConsumerState<_DemoDriver> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(draftProvider.notifier).adopt(widget.host);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraftScreen(
      onBack: () => Navigator.of(context).maybePop(),
    );
  }
}

/// A scripted pod: the packs for every seat, plus the made-up cards they are
/// drawn from.
class _DemoPod {
  _DemoPod({required this.packs, required this.cards, required this.basics});

  final List<List<List<DraftCard>>> packs;
  final Map<String, CatalogCard> cards;
  final Map<String, CatalogCard> basics;
}

_DemoPod _buildPod({required bool sealed}) {
  const templates = <(String, String, double, String)>[
    ('Hedge Ranger', 'Creature — Elf Scout', 2, 'uncommon'),
    ('Embercall Drake', 'Creature — Dragon', 4, 'rare'),
    ('Tideflow Mage', 'Creature — Merfolk Wizard', 3, 'common'),
    ('Grave Verdict', 'Sorcery', 3, 'uncommon'),
    ('Kindled Fury', 'Instant', 1, 'common'),
    ('Sunlit Bastion', 'Enchantment', 2, 'common'),
    ('Thornwood Giant', 'Creature — Giant', 5, 'uncommon'),
    ('Stormcrest Angel', 'Creature — Angel', 6, 'mythic'),
    ('Murmuring Spirit', 'Creature — Spirit', 2, 'common'),
    ('Iron Ledger Golem', 'Artifact Creature — Golem', 4, 'common'),
    ('Oathsworn Knight', 'Creature — Human Knight', 3, 'rare'),
    ('Glimmer Pact', 'Instant', 2, 'uncommon'),
    ('Ashen Reckoner', 'Creature — Zombie', 4, 'common'),
    ('Verdant Surge', 'Sorcery', 2, 'common'),
    ('Coral Sentinel', 'Creature — Fish Soldier', 3, 'common'),
    ('Crownspire Herald', 'Creature — Angel', 5, 'rare'),
  ];

  final cards = <String, CatalogCard>{
    for (var i = 0; i < templates.length; i++)
      'demo-$i': CatalogCard(
        oracleId: 'demo-$i',
        name: templates[i].$1,
        typeLine: templates[i].$2,
        cmc: templates[i].$3,
        rarity: templates[i].$4,
      ),
  };

  final basics = <String, CatalogCard>{
    for (final name in basicLandNames)
      name: CatalogCard(
        oracleId: 'demo-land-$name',
        name: name,
        typeLine: 'Basic Land — $name',
        cmc: 0,
      ),
  };

  // Seeded so the pod is the same every open, which a screenshot wants.
  final rng = math.Random(42);
  var serial = 0;
  final rounds = sealed ? 6 : 3;

  List<DraftCard> rollPack() => [
    for (var k = 0; k < 15; k++)
      () {
        final t = rng.nextInt(templates.length);
        return DraftCard(
          uuid: 'c${serial++}',
          oracleId: 'demo-$t',
          rarity: templates[t].$4,
        );
      }(),
  ];

  final packs = <List<List<DraftCard>>>[
    for (var seat = 0; seat < 2; seat++)
      [for (var r = 0; r < rounds; r++) rollPack()],
  ];

  return _DemoPod(packs: packs, cards: cards, basics: basics);
}

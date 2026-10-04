import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../ui/atoms/pressable.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'die_view.dart';
import 'polyhedron.dart';
import 'tumble.dart';

/// The three dice, standing where the furniture of a table stands.
///
/// In this order because it is the order a player says them in, and the key on
/// each one names its sides rather than its number: the number changes every
/// roll and a key that moved with it would point at a different die each time.
final trayDice = [
  (sides: 20, solid: Polyhedron.d20),
  (sides: 12, solid: Polyhedron.d12),
  (sides: 6, solid: Polyhedron.d6),
];

/// How many turns a die makes on its way to its answer.
///
/// Three, because one reads as a nudge and six is a blur at this size: the die
/// is a third of a card across in the strip beside the board, so a face is
/// only a few points of paint and there is no point spinning it past the eye.
const _spin = 3.0;

/// Long enough to read as a throw and short enough not to be in the way.
const _throw = Duration(milliseconds: 700);

/// Three dice you can tap, in the strip across the board from the deck.
///
/// Drawn no wider than a card between the three of them, which is the whole of
/// why they are in a row rather than a stack. That strip's width is what the
/// board's own scale is read from, so a tray that reached past the graveyard
/// would shrink every card on the mat to pay for itself, and stacked down the
/// column three dice would be three more cards of height in the one place on a
/// phone that already runs out of it.
class DiceTray extends StatefulWidget {
  const DiceTray({
    required this.showing,
    required this.width,
    required this.onRoll,
    this.announced,
    this.metrics,
    super.key,
  });

  /// For the ring on a focused die. Null draws it at the handheld size.
  final Metrics? metrics;

  /// A throw somebody else made, which this tray has to act out.
  ///
  /// Without it a die rolled at the other end of a call is a number that
  /// quietly reads differently, and a die that lands on the number it was
  /// already on is nothing at all. [turn] rises with every announcement, so
  /// the same number twice is still two throws.
  final ({int die, int value, int turn})? announced;

  /// What each die last landed on, in tray order.
  ///
  /// Shorter than three on a table nobody has rolled on yet, and a die with no
  /// result of its own rests on its highest face: three holes where the dice
  /// should be reads as something broken rather than as a game not started.
  final List<int> showing;

  /// The width of the whole tray, which the three dice divide between them.
  final double width;

  /// Handed all three numbers **and** which one moved. The table's `dice` is
  /// the tray rather than a log of throws, so a replay has to be able to put
  /// every die back where it was; but a phone watching cannot tell which die
  /// was thrown from three numbers, and a die that lands on the number it was
  /// already on changes none of them.
  final void Function(int die, List<int> results) onRoll;

  @override
  State<DiceTray> createState() => _DiceTrayState();
}

class _DiceTrayState extends State<DiceTray>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: _throw,
  );

  /// The generator lives here and not in the reducer, which is the same rule
  /// the token ids follow: somebody has to own the randomness and it cannot be
  /// the thing a replay runs again.
  final _random = math.Random();

  /// Which die is in the air, and what it is going to land on.
  ///
  /// The number is held here rather than read back off [DiceTray.showing]
  /// while the die is turning, because a die that rolls the number it was
  /// already on would otherwise not move at all, and one throw in twenty
  /// sitting still reads as a tap that missed.
  int? _airborne;
  int _landing = 1;

  /// The last announcement acted out, so one is never performed twice.
  int _acted = 0;

  @override
  void initState() {
    super.initState();
    _acted = widget.announced?.turn ?? 0;
  }

  @override
  void didUpdateWidget(DiceTray old) {
    super.didUpdateWidget(old);
    final said = widget.announced;
    if (said == null || said.turn == _acted) return;
    _acted = said.turn;
    _tumble(said.die, said.value);
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  /// Turns one die over to a number somebody has already agreed on.
  ///
  /// The number is given rather than rolled: this is the throw being acted
  /// out, not a second throw. Whoever threw it put it on the wire and every
  /// phone has it; a tray that rolled its own would show four tables four
  /// different numbers.
  void _tumble(int i, int to) {
    if (i < 0 || i >= trayDice.length) return;
    setState(() {
      _airborne = i;
      _landing = to;
    });
    _roll.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _airborne = null);
    });
  }

  /// What die `i` is resting on: its own result, or its highest face on a
  /// table where nothing has been thrown yet.
  int _numberOn(int i) =>
      i < widget.showing.length ? widget.showing[i] : trayDice[i].sides;

  void _throwIt(int i) {
    final rolled = rollOne(trayDice[i].solid, _random);
    _tumble(i, rolled);

    widget.onRoll(i, [
      for (var at = 0; at < trayDice.length; at++)
        at == i ? rolled : _numberOn(at),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // Every size in here comes off the tray's own width and none of it off the
    // metrics, so the three dice and their two gaps add up to exactly the
    // width and no more. A point size anywhere in this subtree would be a
    // point size the board pays for: measured, a ten point caption beside an
    // eight point die made the column 41 wide where a card was 32, and the
    // card on the board went from 32.2 to 29.1 to pay for it.
    final side = widget.width / 3.2;
    final gap = (widget.width - side * trayDice.length) / (trayDice.length - 1);

    return SizedBox(
      width: widget.width,
      child: AnimatedBuilder(
        animation: _roll,
        builder: (context, _) => Row(
          children: [
            for (final (i, die) in trayDice.indexed) ...[
              if (i > 0) SizedBox(width: gap),
              _Die(
                key: Key('die-${die.sides}'),
                metrics: widget.metrics ?? Metrics.of(DeviceClass.handheld),
                solid: die.solid,
                number: i == _airborne ? _landing : _numberOn(i),
                turning: i == _airborne ? _roll.value : null,
                side: side,
                onTap: () => _throwIt(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One die and the number under it.
///
/// The number is under the die as well as on its face because the face is the
/// small part: a third of a card across, foreshortened, and dimmed by the same
/// shading that makes the solid read as a solid. The face tells you which way
/// the die is lying and the caption tells you what you rolled.
class _Die extends StatelessWidget {
  const _Die({
    required this.metrics,
    required this.solid,
    required this.number,
    required this.turning,
    required this.side,
    required this.onTap,
    super.key,
  });

  final Metrics metrics;
  final Polyhedron solid;
  final int number;

  /// How far through its throw this die is, or null if it is resting.
  final double? turning;

  final double side;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A number the die does not have would index off the end of its faces and
    // throw inside a painter, which is a red screen rather than a wrong die.
    // Nothing here writes one, but `dice` is on the table and plan 3 lets
    // somebody else fill it in.
    final face = (number - 1).clamp(0, solid.sides - 1);

    return SizedBox(
      width: side,
      child: Pressable(
        metrics: metrics,
        onPress: onTap,
        semanticLabel: 'd${solid.sides}, showing $number',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DieView(
              die: solid,
              showing: face,
              turn: turning == null
                  ? solid.settle(face)
                  : tumble(die: solid, face: face, spin: _spin, at: turning!),
              size: side,
            ),
            Text(
              '$number',
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: TextStyle(
                // Off the die and not off the metrics, for the reason the
                // tray's own comment gives: two digits at a third of the die
                // fit inside it at every card size there is.
                fontSize: side * 0.34,
                fontWeight: FontWeight.w700,
                color: turning == null ? Palette.ink : Palette.inkFaint,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One die, thrown once, landing on [to], and then resting there.
///
/// For the toast that says somebody else rolled. A line of text with the
/// number in it is accurate and it is not a die being thrown, and the
/// person at the other end of the call watched theirs tumble: this is the
/// same throw, the same spin and the same seven tenths of a second, drawn
/// where the news arrives rather than in a tray that may not be open.
///
/// Owns its own controller rather than borrowing the tray's, because the
/// tray may not be on screen and a toast must not depend on it.
class RollingDie extends StatefulWidget {
  const RollingDie({
    super.key,
    required this.solid,
    required this.to,
    required this.size,
  });

  final Polyhedron solid;

  /// The number it lands on, which was agreed on by everybody before this
  /// was built. Nothing here rolls anything: it acts out a throw that
  /// already happened.
  final int to;

  final double size;

  @override
  State<RollingDie> createState() => _RollingDieState();
}

class _RollingDieState extends State<RollingDie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: _throw,
  )..forward();

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final face = (widget.to - 1).clamp(0, widget.solid.sides - 1);
    return AnimatedBuilder(
      animation: _roll,
      builder: (context, _) => DieView(
        die: widget.solid,
        showing: face,
        turn: _roll.isCompleted
            ? widget.solid.settle(face)
            : tumble(
                die: widget.solid,
                face: face,
                spin: _spin,
                at: _roll.value,
              ),
        size: widget.size,
      ),
    );
  }
}

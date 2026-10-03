import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../ui/atoms/slab.dart';
import '../../../ui/atoms/text_field_box.dart';
import '../../../ui/tokens/app_palette.dart';
import '../../../ui/tokens/lettering.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../chat.dart';

/// What has been said, and a box to say something.
///
/// A drawer behind a button rather than a panel that is always there, which
/// is what Board Game Arena does with the same shape of game, and capped at
/// a share of the screen for the same reason it caps its own: the table is
/// what people came for. See
/// docs/benchmarks/2026-10-03-chat-and-voice-in-a-game.md.
///
/// Yours on the right, everybody else's on the left, consecutive lines from
/// one person grouped under one name, newest at the bottom.
class ChatSheet extends StatefulWidget {
  const ChatSheet({
    super.key,
    required this.metrics,
    required this.room,
    required this.onSay,
  });

  final Metrics metrics;
  final ChatRoom room;
  final void Function(String text) onSay;

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final _typed = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toTheBottom());
  }

  @override
  void didUpdateWidget(ChatSheet old) {
    super.didUpdateWidget(old);
    if (widget.room.lines.length != old.room.lines.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toTheBottom());
    }
  }

  @override
  void dispose() {
    _typed.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolled for you. Reaching for a scrollbar in the middle of a turn is
  /// the thing the benchmark's one sourced rule says not to make anybody do.
  void _toTheBottom() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  void _send() {
    final said = _typed.text.trim();
    if (said.isEmpty) return;
    widget.onSay(said);
    _typed.clear();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    final lines = widget.room.lines;

    return Padding(
      // Above the keyboard, which is the whole of why this is here.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              m.safeInset,
              m.scaled(14),
              m.safeInset,
              m.scaled(8),
            ),
            child: Row(
              children: [
                Text(
                  'TABLE TALK',
                  style: pixel(
                    size: m.scaled(12),
                    weight: 600,
                    color: Palette.inkMuted,
                    letterSpacing: 1.4,
                  ),
                ),
                const Spacer(),
                Text(
                  lines.isEmpty ? 'nothing yet' : '${lines.length}',
                  style: pixel(
                    size: m.scaled(12),
                    weight: 500,
                    color: Palette.inkFaint,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: lines.isEmpty
                ? _Nothing(metrics: m)
                : ListView.builder(
                    key: const Key('chat-lines'),
                    controller: _scroll,
                    padding: EdgeInsets.symmetric(horizontal: m.safeInset),
                    itemCount: lines.length,
                    itemBuilder: (context, i) => _Line(
                      metrics: m,
                      line: lines[i],
                      // Grouped: a name is drawn only when the person
                      // changes, which is what stops four lines from one
                      // person being four names.
                      named: i == 0 || lines[i - 1].by != lines[i].by,
                    ),
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              m.safeInset,
              m.scaled(8),
              m.safeInset,
              m.scaled(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Shortcuts(
                    shortcuts: const {
                      SingleActivator(LogicalKeyboardKey.enter): _SayIt(),
                    },
                    child: Actions(
                      actions: {
                        _SayIt: CallbackAction<_SayIt>(
                          onInvoke: (_) {
                            _send();
                            return null;
                          },
                        ),
                      },
                      child: TextFieldBox(
                        key: const Key('chat-box'),
                        metrics: m,
                        controller: _typed,
                        hint: 'say something',
                        autofocus: true,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: m.scaled(10)),
                Slab(
                  key: const Key('chat-send'),
                  metrics: m,
                  tone: SlabTone.choice,
                  onActivate: _send,
                  semanticLabel: 'Send',
                  padding: EdgeInsets.all(m.scaled(11)),
                  child: Icon(
                    Icons.send_rounded,
                    size: m.scaled(18),
                    color: Palette.slabInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SayIt extends Intent {
  const _SayIt();
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.metrics});

  final Metrics metrics;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: metrics.scaled(24)),
    child: Text(
      'Nobody has said anything yet.',
      textAlign: TextAlign.center,
      style: pixel(
        size: metrics.scaled(12),
        weight: 500,
        color: Palette.inkFaint,
      ),
    ),
  );
}

/// One line, on the side of the table it came from.
class _Line extends StatelessWidget {
  const _Line({required this.metrics, required this.line, required this.named});

  final Metrics metrics;
  final ChatLine line;
  final bool named;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final mine = line.mine;

    return Padding(
      padding: EdgeInsets.only(top: m.scaled(named ? 10 : 3)),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (named && !mine)
            Padding(
              padding: EdgeInsets.only(left: m.scaled(4), bottom: m.scaled(3)),
              child: Text(
                line.name,
                style: pixel(
                  size: m.scaled(11),
                  weight: 600,
                  color: Palette.inkFaint,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: m.scaled(11),
                vertical: m.scaled(8),
              ),
              decoration: BoxDecoration(
                color: mine ? context.palette.accent : Palette.trayWell,
                borderRadius: BorderRadius.circular(m.scaled(10)),
                border: Border.all(color: Palette.outline, width: m.scaled(2)),
              ),
              child: Text(
                line.text,
                style: pixel(
                  size: m.scaled(13),
                  weight: 500,
                  height: 1.35,
                  color: mine ? Palette.slabInk : Palette.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../play/widgets/sheet_parts.dart';

/// Asks before leaving a draft, and leaves only on a yes.
///
/// Leaving is the one thing on a draft screen nobody came to do, and the
/// pool goes with it: a tap that landed on the way out by accident should
/// cost a second look, not three packs.
Future<void> confirmLeaveDraft(
  BuildContext context,
  Metrics m,
  VoidCallback leave,
) async {
  final sure = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Palette.surface,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: EdgeInsets.all(m.scaled(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeading(metrics: m, text: 'Leave the draft?'),
            SizedBox(height: m.scaled(8)),
            Text(
              'Your picks stay with the table. You can come back in from '
              'the room while it is running.',
              style: TextStyle(
                fontSize: m.scaled(13),
                height: 1.35,
                color: Palette.inkMuted,
              ),
            ),
            SizedBox(height: m.scaled(16)),
            Row(
              children: [
                Expanded(
                  child: SheetChoice(
                    metrics: m,
                    key: const Key('stay-in-draft'),
                    icon: Icons.close_rounded,
                    label: 'Stay',
                    onTap: () => Navigator.of(sheet).pop(false),
                  ),
                ),
                SizedBox(width: m.scaled(10)),
                Expanded(
                  child: SheetChoice(
                    metrics: m,
                    key: const Key('leave-draft'),
                    icon: Icons.logout_rounded,
                    label: 'Leave',
                    loud: true,
                    onTap: () => Navigator.of(sheet).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  if (sure == true) leave();
}

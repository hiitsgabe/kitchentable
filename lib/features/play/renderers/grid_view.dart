import 'package:flutter/material.dart';

import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';

/// Everyone at once, each board filling its share.
///
/// Laid out by how many and how wide, the way the benchmark found every
/// client does it: two players side by side on a wide screen and stacked on
/// a tall one; three with you across the bottom; four as a two by two grid,
/// which is Quadrant, four-corner, and the thing Cockatrice found four rows
/// could not do. Past four the grid keeps four cells and scrolls.
///
/// You are at the bottom, and on a tall screen with three players yours is
/// the taller cell so your two rows of cards stay readable: the equal split
/// is the rule until it would cost you a row.
class TableGrid extends StatelessWidget {
  const TableGrid({
    super.key,
    required this.metrics,
    required this.seats,
    required this.mineId,
    required this.board,
  });

  final Metrics metrics;

  /// Every seat, in table order.
  final List<SeatView> seats;

  final String mineId;

  /// One seat's dressed board, for the seat passed.
  final Widget Function(SeatView seat) board;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final gap = m.scaled(8);
    final mine = seats.where((s) => s.seatId == mineId).firstOrNull;
    final others = seats.where((s) => s.seatId != mineId).toList();
    if (mine == null) return _rows(others.map(board).toList(), gap);
    final me = board(mine);

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight;
        if (others.isEmpty) return me;
        if (wide) {
          return switch (others.length) {
            1 => _side([board(others[0]), me], gap),
            2 => _rows([
                _side([board(others[0]), board(others[1])], gap),
                me,
              ], gap),
            3 => _rows([
                _side([board(others[0]), board(others[1])], gap),
                _side([me, board(others[2])], gap),
              ], gap),
            _ => _scrolling(
                [for (final s in others) board(s), me],
                gap,
                cellHeight: (box.maxHeight - gap) / 2,
              ),
          };
        }
        // Tall: the others side by side across the top, yours full width
        // below. Four cells on a phone left your board one column wide
        // beside the rail; a row of opponents at the smaller card and your
        // board across the whole width is Forge's Rows and MTGO's top half.
        // Two players split the height evenly; more give you the larger
        // share, since theirs are a glance and yours is where you play.
        final top = others.length == 1
            ? board(others[0])
            : _acrossTop(others.map(board).toList(), gap, box.maxWidth);
        return _rows(
          [top, me],
          gap,
          flex: others.length == 1 ? const [1, 1] : const [2, 3],
        );
      },
    );
  }

  /// Opponents in one row. Up to three share the width; more scroll
  /// sideways, each at least wide enough for two of their cards.
  Widget _acrossTop(List<Widget> cells, double gap, double width) {
    if (cells.length <= 3) return _side(cells, gap);
    final cellWidth = ((width - gap * 2) / 3).clamp(120.0, double.infinity);
    return ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final (i, cell) in cells.indexed) ...[
          if (i > 0) SizedBox(width: gap),
          SizedBox(width: cellWidth, child: cell),
        ],
      ],
    );
  }

  Widget _rows(List<Widget> cells, double gap, {List<int>? flex}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, cell) in cells.indexed) ...[
            if (i > 0) SizedBox(height: gap),
            Expanded(flex: flex?[i] ?? 1, child: cell),
          ],
        ],
      );

  Widget _side(List<Widget> cells, double gap) => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, cell) in cells.indexed) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: cell),
          ],
        ],
      );

  /// Two by two, as many rows as it takes, each row half the viewport.
  Widget _scrolling(List<Widget> cells, double gap, {required double cellHeight}) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      rows.add(SizedBox(
        height: cellHeight,
        child: _side(cells.sublist(i, (i + 2).clamp(0, cells.length)), gap),
      ));
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) SizedBox(height: gap),
            row,
          ],
        ],
      ),
    );
  }
}

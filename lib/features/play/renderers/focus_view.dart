import 'package:flutter/material.dart';

import '../../../table/view/seat_view.dart';

/// One board fills the whole area; the others are a swipe away.
///
/// Pages in table order starting on yours. On a phone you swipe; on a
/// desktop the seat rail picks, and the rail's pick lands here as
/// [watchedSeatId]. This is untap's Full and TableCommander's Single, with
/// the rail keeping every other player's life on screen while you read one
/// board.
class FocusView extends StatefulWidget {
  const FocusView({
    super.key,
    required this.seats,
    required this.mineId,
    required this.watchedSeatId,
    required this.onWatched,
    required this.board,
  });

  final List<SeatView> seats;
  final String mineId;

  /// The seat to show, or null for yours.
  final String? watchedSeatId;

  /// Said when a swipe lands on a page, so the rail follows.
  final void Function(String seatId) onWatched;

  final Widget Function(SeatView seat) board;

  @override
  State<FocusView> createState() => _FocusViewState();
}

class _FocusViewState extends State<FocusView> {
  late final PageController _pages;

  /// Yours first, then the rest in table order.
  List<SeatView> get _order {
    final i = widget.seats.indexWhere((s) => s.seatId == widget.mineId);
    if (i < 0) return widget.seats;
    return [...widget.seats.sublist(i), ...widget.seats.sublist(0, i)];
  }

  int _pageOf(String? seatId) {
    final i = _order.indexWhere((s) => s.seatId == seatId);
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _pages = PageController(initialPage: _pageOf(widget.watchedSeatId));
  }

  @override
  void didUpdateWidget(FocusView old) {
    super.didUpdateWidget(old);
    final page = _pageOf(widget.watchedSeatId);
    if (old.watchedSeatId != widget.watchedSeatId &&
        _pages.hasClients &&
        _pages.page?.round() != page) {
      _pages.animateToPage(
        page,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return PageView.builder(
      key: const Key('focus-pages'),
      controller: _pages,
      itemCount: order.length,
      onPageChanged: (i) => widget.onWatched(order[i].seatId),
      itemBuilder: (context, i) => widget.board(order[i]),
    );
  }
}

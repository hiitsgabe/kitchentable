import '../actions/table_action.dart';
import '../model/table_state.dart';

/// Why an action was refused, in words a player can act on.
class Refusal {
  const Refusal(this.reason);
  final String reason;
}

/// Whatever decides whether a thing may happen.
///
/// The only one that exists permits everything, and that is the product
/// decision, not a stub: a kitchen table game is played by people who settle
/// rules by talking. The interface is here so a real engine can be dropped in
/// without the screen changing, which is the whole argument in the spec.
abstract interface class Referee {
  /// Null to allow.
  Refusal? review(TableState table, TableAction action);

  /// Which cards this card may legally be pointed at.
  ///
  /// Null means the referee does not know, which is different from an empty
  /// list meaning there are none. The screen has to tell those apart: one is
  /// draw nothing special, the other is light nothing up.
  List<String>? legalTargets(TableState table, String cardId);
}

class PermissiveReferee implements Referee {
  const PermissiveReferee();

  @override
  Refusal? review(TableState table, TableAction action) => null;

  @override
  List<String>? legalTargets(TableState table, String cardId) => null;
}

import '../../sources/catalog/catalog_db.dart';
import '../model/deck.dart';
import 'decklist_parser.dart';

class ResolvedDecklist {
  const ResolvedDecklist({
    required this.slots,
    required this.notFound,
    required this.ignoredLines,
  });

  final List<DeckSlot> slots;

  /// Names the catalog has never heard of. Almost always a typo or a card from
  /// a set the player has not imported, and either way the player has to see it
  /// rather than end up with a deck quietly short of four cards.
  final List<String> notFound;

  final List<String> ignoredLines;

  bool get isClean => notFound.isEmpty && ignoredLines.isEmpty;
  int get resolvedCount => slots.fold(0, (n, s) => n + s.quantity);
}

/// Turns a pasted list into deck slots, looking every name up in the catalog.
///
/// Separate from the parser on purpose. Reading the text and finding the card
/// fail for different reasons, and a player needs to be told which happened:
/// a line the parser could not read is a formatting problem, a name the catalog
/// does not know is a typo or a missing source.
Future<ResolvedDecklist> resolveDecklist(
  CatalogDb db,
  DecklistParseResult parsed,
) async {
  final found = await db.cardsByExactNames(parsed.entries.map((e) => e.name));

  final slots = <DeckSlot>[];
  final notFound = <String>[];

  for (final entry in parsed.entries) {
    final card = found[entry.name.toLowerCase()];
    if (card == null) {
      notFound.add(entry.name);
      continue;
    }
    slots.add(DeckSlot(
      card: card,
      quantity: entry.quantity,
      sideboard: entry.sideboard,
    ));
  }

  return ResolvedDecklist(
    slots: slots,
    notFound: notFound,
    ignoredLines: parsed.ignored,
  );
}

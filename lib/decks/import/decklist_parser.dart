/// One line of a pasted decklist, before any card has been looked up.
class DecklistEntry {
  const DecklistEntry({
    required this.quantity,
    required this.name,
    this.sideboard = false,
    this.setCode,
  });

  final int quantity;
  final String name;
  final bool sideboard;

  /// Kept when the line carried one, ignored for now. Two printings of a card
  /// play identically, so the catalog is keyed by oracle id and a set code only
  /// matters the day somebody wants a specific art.
  final String? setCode;

  @override
  String toString() => '$quantity $name${sideboard ? ' [SB]' : ''}';
}

class DecklistParseResult {
  const DecklistParseResult({required this.entries, required this.ignored});

  final List<DecklistEntry> entries;

  /// Lines that were not blank, not a comment and not a section header, and
  /// still could not be read. Shown to the player rather than dropped: a
  /// silent skip in an importer is how a deck quietly comes out wrong.
  final List<String> ignored;

  int get cardCount =>
      entries.where((e) => !e.sideboard).fold(0, (n, e) => n + e.quantity);
  int get sideboardCount =>
      entries.where((e) => e.sideboard).fold(0, (n, e) => n + e.quantity);
}

final _entry = RegExp(
  r'^\s*'
  r'(?:(\d+)\s*[xX]?\s+)?' // 4, 4x, 4 x, or nothing at all
  r'(.+?)' // the name, lazily, so the trailing junk below wins
  r'(?:\s+\(([A-Za-z0-9]{2,6})\)(?:\s+[A-Za-z0-9\-★]+)?)?' // (SET) 123
  r'\s*$',
);

final _sideboardHeader = RegExp(
  r'^\s*(sideboard|side ?board)\s*:?\s*$',
  caseSensitive: false,
);

final _deckHeader = RegExp(
  r'^\s*(deck|main ?deck|maindeck|commander|companion)\s*:?\s*$',
  caseSensitive: false,
);

/// Reads the format every card shop and deck site spits out.
///
/// Handles `4 Lightning Bolt`, `4x Lightning Bolt`, `1 Sol Ring (C21) 263`, a
/// bare `Lightning Bolt` meaning one, `//` and `#` comments, blank lines, and a
/// `Sideboard` header switching everything after it.
///
/// It deliberately does NOT look anything up. Matching a name against the
/// catalog is a separate job with its own failure mode, and mixing the two
/// makes it impossible to tell a typo from a card you do not own yet.
DecklistParseResult parseDecklist(String input) {
  final entries = <DecklistEntry>[];
  final ignored = <String>[];
  var sideboard = false;

  for (final raw in input.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('//') || line.startsWith('#')) continue;

    if (_sideboardHeader.hasMatch(line)) {
      sideboard = true;
      continue;
    }
    if (_deckHeader.hasMatch(line)) {
      sideboard = false;
      continue;
    }

    final match = _entry.firstMatch(line);
    final name = match?.group(2)?.trim();
    if (match == null || name == null || name.isEmpty) {
      ignored.add(line);
      continue;
    }

    final quantity = int.tryParse(match.group(1) ?? '1') ?? 1;
    if (quantity < 1) {
      ignored.add(line);
      continue;
    }

    entries.add(DecklistEntry(
      quantity: quantity,
      name: name,
      sideboard: sideboard,
      setCode: match.group(3),
    ));
  }

  return DecklistParseResult(entries: entries, ignored: ignored);
}

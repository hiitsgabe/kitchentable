import 'model/source_def.dart';

/// Sizes checked against the live endpoints on 2026 09 21 (Scryfall) and
/// 2026 10 04 (pokemon-tcg-data, the sum of its 176 set files).
///
/// No MTGJSON row any more. It was "sets for draft", and there is no draft
/// to feed: a source nothing reads is a download that changes nothing,
/// which is a worse row than none. It comes back with the draft.
///
/// This is `final` rather than `const` because `Uri` has no const constructor,
/// so a SourceDef carrying an endpoint can never be a compile time constant.
final knownSources = <SourceDef>[
  SourceDef(
    id: 'scryfall_oracle',
    name: 'Scryfall',
    subtitle: 'card catalog',
    kind: SourceKind.catalog,
    endpoint: Uri(
      scheme: 'https',
      host: 'api.scryfall.com',
      path: '/bulk-data/oracle-cards',
    ),
    approximateBytes: 24710557,
  ),
  SourceDef(
    id: 'pokemon_tcg_data',
    name: 'Pokemon',
    subtitle: 'card catalog',
    kind: SourceKind.catalog,
    // The list of sets. The cards are read from beside it, one file per
    // set, straight off the repository behind the Pokemon TCG API.
    endpoint: Uri(
      scheme: 'https',
      host: 'raw.githubusercontent.com',
      path: '/PokemonTCG/pokemon-tcg-data/master/sets/en.json',
    ),
    approximateBytes: 26659752,
  ),
  SourceDef(
    id: 'local_file',
    name: 'Local file',
    subtitle: 'a Scryfall or Pokemon file already on this device',
    kind: SourceKind.localFile,
  ),
];

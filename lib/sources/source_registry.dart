import 'model/source_def.dart';

/// Sizes checked against the live endpoints on 2026 09 21 (Scryfall) and
/// 2026 10 04 (pokemon-tcg-data, the sum of its 176 set files, and the
/// gzipped MTGJSON set list).
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
    id: 'mtgjson_sets',
    name: 'MTGJSON',
    subtitle: 'the sets, for draft',
    kind: SourceKind.draftSets,
    // The list of every set. A set's packs are read from beside it, one
    // file per set, when a draft asks for that set.
    endpoint: Uri(
      scheme: 'https',
      host: 'mtgjson.com',
      path: '/api/v5/SetList.json.gz',
    ),
    approximateBytes: 2486786,
  ),
  SourceDef(
    id: 'local_file',
    name: 'Local file',
    subtitle: 'a Scryfall or Pokemon file already on this device',
    kind: SourceKind.localFile,
  ),
];

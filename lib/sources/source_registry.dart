import 'model/source_def.dart';

/// Sizes checked against the live endpoints on 2026 09 21.
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
    id: 'mtgjson_sets',
    name: 'MTGJSON',
    subtitle: 'sets for draft',
    kind: SourceKind.draftSets,
    approximateBytes: 1100000,
    available: false,
  ),
  SourceDef(
    id: 'pokemon_tcg_data',
    name: 'Pokemon',
    subtitle: 'card catalog',
    kind: SourceKind.catalog,
    available: false,
  ),
  SourceDef(
    id: 'local_file',
    name: 'Local file',
    subtitle: 'a dump already on this device',
    kind: SourceKind.localFile,
    available: false,
  ),
];

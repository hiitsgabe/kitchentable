enum SourceKind { catalog, draftSets, localFile, url }

/// A place cards can come from. The app knows the address. It does not go
/// there until somebody switches it on.
class SourceDef {
  const SourceDef({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.kind,
    this.endpoint,
    this.approximateBytes,
    this.available = true,
  });

  final String id;
  final String name;
  final String subtitle;
  final SourceKind kind;
  final Uri? endpoint;

  /// Shown to the player before they touch the row. Nobody should be surprised
  /// by a download.
  final int? approximateBytes;

  /// False for sources we have not built yet, so the row can say so instead of
  /// failing when tapped.
  final bool available;

  /// Always false. There is no source this app turns on by itself.
  bool get enabledByDefault => false;
}

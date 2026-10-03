import 'package:flutter/material.dart';

/// What is behind the app.
///
/// A list rather than a single choice, because the point is that the player
/// picks. The default is the animated one in black and pink.
enum BackdropKind {
  /// Swirling paint, the default: polar spin, folded coordinates, three
  /// colours out of the two that were picked.
  paint,

  /// Soft drifting blobs. Painted by hand rather than by a shader, so it
  /// survives anywhere the shader does not.
  drift,

  /// Slow fluid mesh. Black with pink bleeding through.
  aurora,

  /// Two colours, still. Cheapest on a battery and on a weak handheld.
  flat,

  /// A picture the player chose.
  image;

  String get label => switch (this) {
        BackdropKind.paint => 'Paint',
        BackdropKind.aurora => 'Aurora',
        BackdropKind.drift => 'Drift',
        BackdropKind.flat => 'Flat',
        BackdropKind.image => 'Your own picture',
      };

  String get describe => switch (this) {
        BackdropKind.paint => 'swirling paint, the default',
        BackdropKind.aurora => 'slow fluid colour, needs a shader',
        BackdropKind.drift => 'soft blobs, drawn without a shader',
        BackdropKind.flat => 'two colours, still, cheapest of all',
        BackdropKind.image => 'point it at a file on this device',
      };

  bool get animated =>
      this == BackdropKind.paint ||
      this == BackdropKind.aurora ||
      this == BackdropKind.drift;
}

class BackdropStyle {
  const BackdropStyle({
    this.kind = BackdropKind.paint,
    this.top = const Color(0xFFFF2E88),
    this.bottom = const Color(0xFF07060A),
    this.imagePath,
    this.imageData,
  });

  final BackdropKind kind;

  /// The colour that shows, and the colour it fades into. Named for what they
  /// do rather than for a position, because the flat one is a gradient and the
  /// animated ones are not.
  final Color top;
  final Color bottom;

  /// A path on a device that has a file system.
  final String? imagePath;

  /// The picture itself, base64 JPEG. A browser hands out a handle to a file
  /// rather than a name and the handle dies with the tab, so the bytes are
  /// what survives a reload. Shrunk before it is stored.
  final String? imageData;

  BackdropStyle copyWith({
    BackdropKind? kind,
    Color? top,
    Color? bottom,
    String? imagePath,
    String? imageData,
    bool clearImage = false,
  }) =>
      BackdropStyle(
        kind: kind ?? this.kind,
        top: top ?? this.top,
        bottom: bottom ?? this.bottom,
        imagePath: clearImage ? null : (imagePath ?? this.imagePath),
        imageData: clearImage ? null : (imageData ?? this.imageData),
      );

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'top': top.toARGB32(),
        'bottom': bottom.toARGB32(),
        'imagePath': imagePath,
        'imageData': imageData,
      };

  static BackdropStyle fromJson(Map<String, Object?> json) => BackdropStyle(
        kind: BackdropKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => BackdropKind.paint,
        ),
        top: Color((json['top'] as int?) ?? 0xFFFF2E88),
        bottom: Color((json['bottom'] as int?) ?? 0xFF07060A),
        imagePath: json['imagePath'] as String?,
        imageData: json['imageData'] as String?,
      );
}

/// The colours offered in settings. Kept short on purpose: a colour picker is a
/// lot of screen for a decision most people make once.
const backdropPresets = <String, (Color, Color)>{
  'Pink on black': (Color(0xFFFF2E88), Color(0xFF07060A)),
  'Violet on black': (Color(0xFF7C5CFF), Color(0xFF06050B)),
  'Teal on black': (Color(0xFF00E0A4), Color(0xFF04080A)),
  'Amber on black': (Color(0xFFFFB03A), Color(0xFF0A0703)),
  'Felt green': (Color(0xFF2FA36B), Color(0xFF060D09)),
  'Ash': (Color(0xFF8A8A94), Color(0xFF0C0C0F)),
};

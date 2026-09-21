import 'package:flutter/material.dart';

/// What is behind the app.
///
/// A list rather than a single choice, because the point is that the player
/// picks. The default is the animated one in black and pink.
enum BackdropKind {
  /// Slow fluid mesh, the default. Black with pink bleeding through.
  aurora,

  /// Soft drifting blobs, painted by hand rather than by a shader, so it
  /// survives anywhere the shader does not.
  drift,

  /// Two colours, still. Cheapest on a battery and on a weak handheld.
  flat,

  /// A picture the player chose.
  image;

  String get label => switch (this) {
        BackdropKind.aurora => 'Aurora',
        BackdropKind.drift => 'Drift',
        BackdropKind.flat => 'Flat',
        BackdropKind.image => 'Your own picture',
      };

  String get describe => switch (this) {
        BackdropKind.aurora => 'slow fluid colour, the default',
        BackdropKind.drift => 'soft blobs, gentler on a battery',
        BackdropKind.flat => 'two colours, still, cheapest of all',
        BackdropKind.image => 'point it at a file on this device',
      };

  bool get animated => this == BackdropKind.aurora || this == BackdropKind.drift;
}

class BackdropStyle {
  const BackdropStyle({
    this.kind = BackdropKind.aurora,
    this.top = const Color(0xFFFF2E88),
    this.bottom = const Color(0xFF07060A),
    this.imagePath,
  });

  final BackdropKind kind;

  /// The colour that shows, and the colour it fades into. Named for what they
  /// do rather than for a position, because the flat one is a gradient and the
  /// animated ones are not.
  final Color top;
  final Color bottom;

  final String? imagePath;

  BackdropStyle copyWith({
    BackdropKind? kind,
    Color? top,
    Color? bottom,
    String? imagePath,
  }) =>
      BackdropStyle(
        kind: kind ?? this.kind,
        top: top ?? this.top,
        bottom: bottom ?? this.bottom,
        imagePath: imagePath ?? this.imagePath,
      );

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'top': top.toARGB32(),
        'bottom': bottom.toARGB32(),
        'imagePath': imagePath,
      };

  static BackdropStyle fromJson(Map<String, Object?> json) => BackdropStyle(
        kind: BackdropKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => BackdropKind.aurora,
        ),
        top: Color((json['top'] as int?) ?? 0xFFFF2E88),
        bottom: Color((json['bottom'] as int?) ?? 0xFF07060A),
        imagePath: json['imagePath'] as String?,
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

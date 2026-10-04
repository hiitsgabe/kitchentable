import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../ui/atoms/tray.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/app_palette.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../../table/room/room.dart';

/// Whether this device can point a camera at anything.
///
/// The scanner covers phones, macOS and the web; a Linux or Windows desktop
/// has no plugin behind it. The join screen asks rather than offering a
/// button that cannot work. A web build on a machine with no camera still
/// gets the offer, because only the browser knows that, and it says so when
/// the camera will not start.
bool get canScan =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// The camera, pointed at somebody else's screen.
///
/// The host's room shows a QR and a link and no code at all, so the two ways
/// in are the two things they can actually hand over. This is the one that
/// needs no typing and no messaging app in between: you are in the same
/// place, and you point your phone at theirs.
///
/// Returns the room code, or null if the camera was closed or refused.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  /// Said once. A camera pointed at a QR fires the same code many times a
  /// second, and popping a screen twice is an error.
  bool _done = false;

  /// What went wrong, in the player's words rather than the plugin's.
  String? _trouble;

  @override
  void dispose() {
    unawaited(_camera.dispose());
    super.dispose();
  }

  void _saw(BarcodeCapture capture) {
    if (_done) return;
    for (final found in capture.barcodes) {
      final code = codeFrom(found.rawValue ?? '');
      if (code == null) continue;
      _done = true;
      Navigator.of(context).pop(code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );

    return ScreenFrame(
      metrics: m,
      title: 'Scan the QR',
      label: _trouble == null
          ? 'point this at the other screen'
          : 'the camera could not start',
      onBack: () => Navigator.of(context).pop(),
      children: [
        if (_trouble case final why?)
          Well(
            metrics: m,
            edge: Palette.attention,
            child: Text(
              why,
              key: const Key('scan-trouble'),
              style: pixel(
                size: m.scaled(12),
                weight: 500,
                height: 1.45,
                color: Palette.ink,
              ),
            ),
          )
        else ...[
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(m.scaled(12)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: context.palette.accent,
                    width: m.scaled(2),
                  ),
                  borderRadius: BorderRadius.circular(m.scaled(12)),
                ),
                child: MobileScanner(
                  key: const Key('scanner'),
                  controller: _camera,
                  onDetect: _saw,
                  errorBuilder: (context, error) {
                    // Said in the frame rather than thrown. A camera that
                    // will not open is a sentence and a way round, not a
                    // dead end.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _trouble == null) {
                        setState(() => _trouble = _saying(error));
                      }
                    });
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
          SizedBox(height: m.scaled(12)),
          Text(
            'The person hosting has it on their room screen. Nothing is sent '
            'anywhere: the QR is read here, on this device.',
            style: pixel(
              size: m.scaled(12),
              weight: 500,
              height: 1.5,
              color: Palette.inkMuted,
            ),
          ),
        ],
      ],
    );
  }

  /// One sentence per cause, the way the microphone's failures get one each.
  static String _saying(MobileScannerException error) =>
      switch (error.errorCode) {
        MobileScannerErrorCode.permissionDenied =>
          'This device would not let the app use the camera. Allow it in '
              'your browser or system settings, or paste the link instead.',
        MobileScannerErrorCode.unsupported =>
          'This device cannot scan a QR code. Paste the link instead.',
        _ => 'The camera could not be started. Paste the link instead.',
      };
}

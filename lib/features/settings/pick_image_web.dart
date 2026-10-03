import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Whether this build can open a picture off the device.
bool get canPickImage => true;

/// The longest side a stored picture is kept at.
///
/// A backdrop is behind the app at the size of a screen, and a phone camera's
/// picture is several times that. It is also kept in the same preferences
/// store as everything else, which a browser caps at a few megabytes, so a
/// photo straight off a camera would fill it on its own.
const _longestSide = 1600;

/// How hard it is squeezed. A backdrop is dimmed and sat behind text, so the
/// artefacts nobody would accept in a card picture do not show here.
const _quality = 0.75;

/// A picture the player chose, as base64 JPEG, or null if they chose none.
///
/// Base64 and not a path: a browser hands out a handle to a file rather than
/// a name, and the handle dies with the tab. The bytes are what survives a
/// reload.
Future<String?> pickImage() {
  final input =
      web.document.createElement('input') as web.HTMLInputElement
        ..type = 'file'
        ..accept = 'image/*';
  final chosen = Completer<String?>();

  input.onchange = (web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!chosen.isCompleted) chosen.complete(null);
      return;
    }
    final reader = web.FileReader();
    reader.onload = (web.Event _) {
      final result = reader.result;
      if (result == null) {
        if (!chosen.isCompleted) chosen.complete(null);
        return;
      }
      _shrink((result as JSString).toDart).then((data) {
        if (!chosen.isCompleted) chosen.complete(data);
      });
    }.toJS;
    reader.onerror = (web.Event _) {
      if (!chosen.isCompleted) chosen.complete(null);
    }.toJS;
    reader.readAsDataURL(files.item(0)!);
  }.toJS;

  // A cancelled chooser fires nothing at all in most browsers, so the future
  // would hang for the life of the tab. `cancel` is the modern event for it.
  input.addEventListener(
    'cancel',
    (web.Event _) {
      if (!chosen.isCompleted) chosen.complete(null);
    }.toJS,
  );

  input.click();
  return chosen.future;
}

/// Draws [dataUrl] into a canvas no bigger than [_longestSide] and reads it
/// back as JPEG, which is what gets stored.
Future<String?> _shrink(String dataUrl) {
  final done = Completer<String?>();
  final image = web.document.createElement('img') as web.HTMLImageElement;

  image.onload = (web.Event _) {
    final wide = image.naturalWidth;
    final tall = image.naturalHeight;
    if (wide == 0 || tall == 0) {
      if (!done.isCompleted) done.complete(null);
      return;
    }
    final longest = wide > tall ? wide : tall;
    final scale = longest > _longestSide ? _longestSide / longest : 1.0;

    final canvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement
          ..width = (wide * scale).round()
          ..height = (tall * scale).round();
    final paper = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    paper.drawImage(image, 0, 0, canvas.width.toDouble(), canvas.height.toDouble());

    final out = canvas.toDataURL('image/jpeg', _quality.toJS);
    final comma = out.indexOf(',');
    if (!done.isCompleted) {
      done.complete(comma < 0 ? null : out.substring(comma + 1));
    }
  }.toJS;
  image.onerror = (web.Event _, [JSAny? _, JSAny? _, JSAny? _, JSAny? _]) {
    if (!done.isCompleted) done.complete(null);
  }.toJS;

  image.src = dataUrl;
  return done.future;
}

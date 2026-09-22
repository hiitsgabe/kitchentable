import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'model/card_instance.dart';

/// Turns a seed string into an int that every platform agrees on.
///
/// Not `seed.hashCode`, which was the first answer and is wrong. It is stable
/// across runs, but it is a different function on the VM than on dart2js, and
/// this app ships both. Measured on 2026 09 22:
///
///     'abc'  VM 756227931   JS 102006619
///     'abd'  VM 458030030   JS 340630478
///
/// A phone and a browser at the same table would derive different orders from
/// the identical committed seed, and the commitment would be worth nothing
/// while looking like it worked.
///
/// SHA-256 has a fixed specification and no runtime opinion, so its bytes are
/// the same everywhere by construction. `Random(int)` itself is portable:
/// `Random(42)` gives the same sequence on both, which is how the fault was
/// pinned to the derivation rather than to the generator.
int seedToInt(String seed) {
  final digest = sha256.convert(utf8.encode(seed)).bytes;
  var value = 0;
  // Four bytes, kept inside the 32 bits dart2js can hold exactly. Random takes
  // the low bits anyway, so a wider fold would buy nothing and cost precision
  // on the web.
  for (var i = 0; i < 4; i++) {
    value = (value << 8) | digest[i];
  }
  return value;
}

/// A Fisher Yates driven by a seed, so the same seed always gives the same
/// order. Deterministic on purpose: it is what makes a shuffle checkable by
/// somebody who was not holding the cards.
List<CardInstance> shuffleWithSeed(List<CardInstance> cards, String seed) {
  final random = Random(seedToInt(seed));
  final out = [...cards];

  for (var i = out.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final swap = out[i];
    out[i] = out[j];
    out[j] = swap;
  }

  return out;
}

/// What a seat says before it shuffles, so that what it says afterwards can be
/// checked. A hash gives nothing away and cannot be changed later, which is
/// the whole trick.
String commitToSeed(String seed) =>
    sha256.convert(utf8.encode(seed)).toString();

bool seedMatches(String commitment, String seed) =>
    commitToSeed(seed) == commitment;

/// A seed nobody chose on purpose. Not cryptographic, and it does not need to
/// be: it is committed to before use, so guessing it later buys nothing.
String freshSeed() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

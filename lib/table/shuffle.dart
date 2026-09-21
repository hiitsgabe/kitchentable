import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'model/card_instance.dart';

/// A Fisher Yates driven by a seed, so the same seed always gives the same
/// order. Deterministic on purpose: it is what makes a shuffle checkable by
/// somebody who was not holding the cards.
List<CardInstance> shuffleWithSeed(List<CardInstance> cards, String seed) {
  final random = Random(seed.hashCode);
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

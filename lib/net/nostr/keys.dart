import 'dart:math';

import 'package:bip340/bip340.dart' as bip340;

/// A Nostr identity: a secp256k1 private key and the public key it derives.
///
/// The public key is who this device is to every peer, and the one word
/// everything above the transport uses to name it. The private key never
/// leaves this object except as a signature.
class Keys {
  Keys._(this.private, this.public);

  /// The private key as 64 hex characters, which is what `bip340` speaks.
  final String private;

  /// The x only public key as 64 hex characters, which is what Nostr speaks.
  final String public;

  /// From a private key already held, say one read back from settings.
  factory Keys.fromPrivate(String private) =>
      Keys._(private, bip340.getPublicKey(private));

  /// A fresh identity from the platform's secure random source.
  ///
  /// A 256 bit value is a valid private key unless it is zero or above the
  /// curve order, which is a chance in 2^128 and still not a chance worth
  /// taking, so it is checked and drawn again.
  factory Keys.mint() {
    final random = Random.secure();
    while (true) {
      final private = hexOf(List.generate(32, (_) => random.nextInt(256)));
      try {
        return Keys.fromPrivate(private);
      } on Error {
        // Out of range. The next draw will not be.
      }
    }
  }

  /// A BIP-340 Schnorr signature over a 32 byte hash given as hex.
  ///
  /// The auxiliary randomness is drawn fresh each time, as the BIP says it
  /// should be: a deterministic nonce would be fine and a repeated one would
  /// give the private key away.
  String sign(String hashHex) {
    final aux = hexOf(List.generate(32, (_) => Random.secure().nextInt(256)));
    return bip340.sign(private, hashHex, aux);
  }

  /// Whether [sigHex] is [pubkey]'s signature over [hashHex].
  static bool verify(String pubkey, String hashHex, String sigHex) {
    try {
      return bip340.verify(pubkey, hashHex, sigHex);
    } on Object {
      // A malformed key or signature is not a valid one, and the library
      // says so by throwing rather than returning false.
      return false;
    }
  }

  /// The public key only. This is what ends up in a log.
  @override
  String toString() => 'Keys($public)';
}

/// Lowercase hex, the way Nostr writes every key, id and signature.
String hexOf(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

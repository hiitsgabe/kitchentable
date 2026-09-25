import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bip340/bip340.dart' as bip340;
import 'package:crypto/crypto.dart';

/// A Nostr relay on a loopback port, speaking exactly the NIP-01 the client
/// needs and nothing it does not.
///
/// It is a real `HttpServer` with real sockets rather than a stream pair in
/// memory, because the thing the client has to get right is reconnecting to a
/// socket that went away, and a fake that cannot drop a connection cannot test
/// that. `dart:io` means this never runs under `--platform chrome`, which is
/// the precedent every other network test here already set.
///
/// It stores nothing. Every event the client will ever send it is ephemeral
/// and a real relay drops those on the floor after fanning them out, so a
/// `REQ` here sees only what is published after it, and its `EOSE` comes
/// straight back. A test that publishes before it subscribes sees nothing,
/// which is what would happen on a real relay.
///
/// It verifies signatures on its own, from the JSON, with `bip340` and
/// `sha256` directly and none of the client's code. That is deliberate: if
/// the client and the relay shared one idea of an event's id, a mistake in it
/// would be invisible from both sides.
class FakeRelay {
  FakeRelay._(this._server);

  final HttpServer _server;
  final List<_Client> _clients = [];

  /// Ids of every event this relay accepted, in the order they arrived.
  final List<String> accepted = [];

  /// Ids of every event this relay refused, with the reason it sent back.
  final Map<String, String> rejected = {};

  /// How many events went out to subscribers, per subscription id.
  final Map<String, int> forwarded = {};

  static Future<FakeRelay> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final relay = FakeRelay._(server);
    server.listen(relay._serve);
    return relay;
  }

  Uri get url => Uri.parse('ws://127.0.0.1:${_server.port}');

  /// Sockets open right now.
  int get connections => _clients.length;

  /// Subscription ids open right now, across every socket.
  List<String> get subscriptions =>
      [for (final c in _clients) ...c.filters.keys];

  /// The relay goes away under the client: every socket is closed from this
  /// side. The server keeps listening, so a client that comes back finds it.
  Future<void> dropConnections() async {
    final open = List.of(_clients);
    for (final c in open) {
      await c.socket.close();
    }
  }

  /// What a hostile relay would do: hand every matching subscriber a message
  /// nobody verified. The client is the last line and this is how a test
  /// reaches it.
  void inject(Map<String, dynamic> event) => _fanOut(event);

  Future<void> close() async {
    await dropConnections();
    await _server.close(force: true);
  }

  Future<void> _serve(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    final client = _Client(socket);
    _clients.add(client);
    socket.listen(
      (data) => _handle(client, data),
      onDone: () => _clients.remove(client),
      onError: (_) => _clients.remove(client),
    );
  }

  void _handle(_Client client, dynamic data) {
    final List<dynamic> message;
    try {
      message = jsonDecode(data as String) as List<dynamic>;
    } catch (_) {
      client.send(['NOTICE', 'not a json array']);
      return;
    }
    switch (message[0]) {
      case 'EVENT':
        final event = message[1] as Map<String, dynamic>;
        final id = event['id'] as String;
        final why = _whyInvalid(event);
        if (why != null) {
          rejected[id] = why;
          client.send(['OK', id, false, why]);
          return;
        }
        accepted.add(id);
        _fanOut(event);
        client.send(['OK', id, true, '']);
      case 'REQ':
        final subId = message[1] as String;
        client.filters[subId] = message[2] as Map<String, dynamic>;
        client.send(['EOSE', subId]);
      case 'CLOSE':
        client.filters.remove(message[1] as String);
      default:
        client.send(['NOTICE', 'unknown verb ${message[0]}']);
    }
  }

  void _fanOut(Map<String, dynamic> event) {
    for (final client in _clients) {
      for (final entry in client.filters.entries) {
        if (!_matches(entry.value, event)) continue;
        forwarded[entry.key] = (forwarded[entry.key] ?? 0) + 1;
        client.send(['EVENT', entry.key, event]);
      }
    }
  }

  /// `kinds` and every `#x` tag filter, as NIP-01 defines them: a filter
  /// matches when every field it names matches, a field matches when the
  /// event's value is one of the listed ones, and for a tag filter when any
  /// of the event's tags of that name has a listed value.
  static bool _matches(Map<String, dynamic> filter, Map<String, dynamic> event) {
    final kinds = filter['kinds'] as List<dynamic>?;
    if (kinds != null && !kinds.contains(event['kind'])) return false;
    final tags = (event['tags'] as List<dynamic>).cast<List<dynamic>>();
    for (final entry in filter.entries) {
      if (!entry.key.startsWith('#')) continue;
      final name = entry.key.substring(1);
      final wanted = entry.value as List<dynamic>;
      final present = tags
          .where((t) => t.isNotEmpty && t[0] == name && t.length > 1)
          .map((t) => t[1]);
      if (!present.any(wanted.contains)) return false;
    }
    return true;
  }

  static String? _whyInvalid(Map<String, dynamic> event) {
    final serialized = jsonEncode([
      0,
      event['pubkey'],
      event['created_at'],
      event['kind'],
      event['tags'],
      event['content'],
    ]);
    final id = sha256.convert(utf8.encode(serialized)).toString();
    if (id != event['id']) return 'invalid: id does not match';
    final good = bip340.verify(
      event['pubkey'] as String,
      id,
      event['sig'] as String,
    );
    if (!good) return 'invalid: bad signature';
    return null;
  }
}

class _Client {
  _Client(this.socket);

  final WebSocket socket;
  final Map<String, Map<String, dynamic>> filters = {};

  void send(List<dynamic> message) => socket.add(jsonEncode(message));
}

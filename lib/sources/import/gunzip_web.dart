import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Decompresses with the browser's own DecompressionStream, which is the same
/// zlib every tab already carries. Nothing is bundled and nothing is
/// reimplemented in Dart.
///
/// The compressed bytes are gathered first, then handed to the browser, then
/// read back chunk by chunk. Gathering costs one copy of the compressed file,
/// about 24 MB for the Scryfall catalog. What matters is that the OTHER side
/// stays incremental: the decompressed JSONL is many times larger and is never
/// held whole, it flows out in chunks that the line splitter and the batched
/// inserts consume as they arrive.
Stream<List<int>> gunzipStream(Stream<List<int>> compressed) async* {
  final gathered = BytesBuilder(copy: false);
  await for (final chunk in compressed) {
    gathered.add(chunk);
  }

  final decompressor = web.DecompressionStream('gzip');

  // Feeding and draining have to happen at the same time. The browser applies
  // backpressure, so awaiting the write before starting to read would deadlock
  // on any file bigger than one internal buffer.
  final writer = decompressor.writable.getWriter();
  final feeding = () async {
    await writer.write(gathered.takeBytes().toJS).toDart;
    await writer.close().toDart;
  }();

  final reader =
      decompressor.readable.getReader() as web.ReadableStreamDefaultReader;

  try {
    while (true) {
      final result = await reader.read().toDart;
      if (result.done) break;
      final value = result.value;
      if (value == null) continue;
      yield (value as JSUint8Array).toDart;
    }
  } finally {
    await feeding;
  }
}

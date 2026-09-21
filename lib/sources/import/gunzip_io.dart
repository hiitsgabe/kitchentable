import 'dart:io';

Stream<List<int>> gunzipStream(Stream<List<int>> compressed) =>
    compressed.transform(gzip.decoder);

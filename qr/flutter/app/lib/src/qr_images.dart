import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'qr_assets.dart';

/// What the image at [index] encodes; see bench/scripts/make-qr-images.swift.
String expectedPayload(int index) =>
    'https://example.com/benchmark/qr/${index.toString().padLeft(3, '0')}';

String imageName(int index) => 'qr-${index.toString().padLeft(3, '0')}.png';

/// Copies the bundled images into the app's own storage and returns their
/// paths in name order.
///
/// `mobile_scanner.analyzeImage()` takes a file path, and a Flutter asset is
/// not a file. This is the preparation step, which is not measured.
Future<List<String>> unpackImages() async {
  final documents = await getApplicationDocumentsDirectory();
  final directory = Directory('${documents.path}/qr');
  await directory.create(recursive: true);

  final paths = <String>[];
  for (var index = 0; index < qrImageCount; index++) {
    final name = imageName(index);
    final file = File('${directory.path}/$name');
    // An empty file means a half-finished copy from an earlier launch.
    if (!file.existsSync() || await file.length() == 0) {
      final data = await rootBundle.load('assets/qr/$name');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    paths.add(file.path);
  }
  return paths;
}

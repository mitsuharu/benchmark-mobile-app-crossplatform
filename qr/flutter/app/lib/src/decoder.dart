import 'package:mobile_scanner/mobile_scanner.dart';

import 'qr_images.dart';

/// One run of the decode loop.
class DecodeRun {
  const DecodeRun({
    required this.decoded,
    required this.durationsUs,
    required this.startedAt,
    required this.finishedAt,
  });

  /// How many images decoded to the payload they were generated with.
  final int decoded;

  /// How long each image took, in microseconds.
  final List<int> durationsUs;

  final DateTime startedAt;
  final DateTime finishedAt;
}

/// How far the decode loop has got. The screen reads it on its own timer, so
/// redrawing never lands between two decodes.
class DecodeProgress {
  int current = 0;
}

/// Decodes every image in order, one after the other, with mobile_scanner.
///
/// Nothing is logged in here: the timings are kept in memory and written out
/// once the loop is over, so the log does not land inside what is measured.
Future<DecodeRun> decodeAll(List<String> paths, DecodeProgress progress) async {
  final controller = MobileScannerController();
  final durationsUs = List<int>.filled(paths.length, 0);
  var decoded = 0;
  final watch = Stopwatch();
  final startedAt = DateTime.now();

  try {
    for (var index = 0; index < paths.length; index++) {
      watch.reset();
      watch.start();
      final capture = await controller.analyzeImage(
        paths[index],
        formats: const [BarcodeFormat.qrCode],
      );
      watch.stop();
      durationsUs[index] = watch.elapsedMicroseconds;
      if (capture?.barcodes.firstOrNull?.rawValue == expectedPayload(index)) {
        decoded++;
      }
      progress.current = index + 1;
    }
  } finally {
    await controller.dispose();
  }

  return DecodeRun(
    decoded: decoded,
    durationsUs: durationsUs,
    startedAt: startedAt,
    finishedAt: DateTime.now(),
  );
}

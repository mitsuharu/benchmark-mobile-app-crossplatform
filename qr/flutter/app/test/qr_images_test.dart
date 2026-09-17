import 'package:flutter_test/flutter_test.dart';
import 'package:qrflutterapp/src/qr_images.dart';

void main() {
  test('expectedPayload pads the index to three digits', () {
    expect(expectedPayload(0), 'https://example.com/benchmark/qr/000');
    expect(expectedPayload(7), 'https://example.com/benchmark/qr/007');
    expect(expectedPayload(499), 'https://example.com/benchmark/qr/499');
  });

  test('imageName matches the generated file names', () {
    expect(imageName(0), 'qr-000.png');
    expect(imageName(499), 'qr-499.png');
  });
}

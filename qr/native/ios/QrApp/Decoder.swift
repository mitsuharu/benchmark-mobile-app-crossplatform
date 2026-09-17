import Foundation
import Vision

/// One run of the decode loop.
struct DecodeRun {
  /// How many images decoded to the payload they were generated with.
  let decoded: Int
  /// How long each image took, in microseconds.
  let durationsUs: [Int64]
  let startedAt: Date
  let finishedAt: Date
}

/// How far the decode loop has got. The screen reads it on its own timer, so
/// redrawing never lands between two decodes.
final class DecodeProgress: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0

  var current: Int {
    lock.lock()
    defer { lock.unlock() }
    return value
  }

  func set(_ next: Int) {
    lock.lock()
    value = next
    lock.unlock()
  }
}

/// Decodes every image in order, one after the other, with Vision.
///
/// Nothing is logged in here: the timings are kept in memory and written out
/// once the loop is over, so the log does not land inside what is measured.
func decodeAll(paths: [String], progress: DecodeProgress) -> DecodeRun {
  var durationsUs = [Int64](repeating: 0, count: paths.count)
  var decoded = 0
  let startedAt = Date()

  for (index, path) in paths.enumerated() {
    let began = DispatchTime.now().uptimeNanoseconds
    // A request keeps its results, so each image gets a fresh one.
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]
    let handler = VNImageRequestHandler(url: URL(fileURLWithPath: path))
    let value = try? { () -> String? in
      try handler.perform([request])
      return (request.results?.first as? VNBarcodeObservation)?.payloadStringValue
    }()
    durationsUs[index] = Int64((DispatchTime.now().uptimeNanoseconds - began) / 1_000)
    if value == expectedPayload(index) {
      decoded += 1
    }
    progress.set(index + 1)
  }

  return DecodeRun(
    decoded: decoded, durationsUs: durationsUs, startedAt: startedAt, finishedAt: Date())
}

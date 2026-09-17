import Foundation

/// What the image at `index` encodes; see bench/scripts/make-qr-images.swift.
func expectedPayload(_ index: Int) -> String {
  String(format: "https://example.com/benchmark/qr/%03d", index)
}

/// Copies the bundled images into Documents and returns the paths in name
/// order.
///
/// Every implementation decodes from a file path (see AGENTS.md). The images
/// are already files here, but they are unpacked anyway so all four start from
/// the same place. This is the preparation step, which is not measured.
func unpackImages() throws -> [String] {
  guard let source = Bundle.main.resourceURL?.appendingPathComponent("qr") else {
    throw QrImagesError.missingBundle
  }
  let documents = try FileManager.default.url(
    for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
  let destination = documents.appendingPathComponent("qr")
  try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

  let names = try FileManager.default.contentsOfDirectory(atPath: source.path)
    .filter { $0.hasSuffix(".png") }
    .sorted()
  return try names.map { name in
    let file = destination.appendingPathComponent(name)
    // An empty file means a half-finished copy from an earlier launch.
    let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    if size == 0 {
      try? FileManager.default.removeItem(at: file)
      try FileManager.default.copyItem(at: source.appendingPathComponent(name), to: file)
    }
    return file.path
  }
}

enum QrImagesError: LocalizedError {
  case missingBundle

  var errorDescription: String? {
    switch self {
    case .missingBundle: return "bundled images are missing"
    }
  }
}

#!/usr/bin/env swift  //
// Generates the QR code images the decode benchmark reads.
//
//   swift bench/scripts/make-qr-images.swift <out-dir> [count] [pixels]
//
// Core Image and ImageIO ship with macOS, so this needs no dependencies —
// the same reason bench/scripts/mp4-to-gif.swift is written this way.
//
// Every image holds a different payload so a decoder cannot cache a result,
// and the payload carries its own index so a run can check it decoded the
// image it thinks it did.

import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
  FileHandle.standardError.write(
    Data("usage: make-qr-images.swift <out-dir> [count] [pixels]\n".utf8))
  exit(1)
}

let outDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
let count = arguments.count > 2 ? Int(arguments[2]) ?? 100 : 100
let pixels = arguments.count > 3 ? Int(arguments[3]) ?? 512 : 512

/// The payload of image `index`, also written into the file name.
func payload(for index: Int) -> String {
  "https://example.com/benchmark/qr/\(String(format: "%03d", index))"
}

let context = CIContext()

try FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)

for index in 0..<count {
  guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
    FileHandle.standardError.write(Data("CIQRCodeGenerator is unavailable\n".utf8))
    exit(1)
  }
  filter.setValue(Data(payload(for: index).utf8), forKey: "inputMessage")
  // "M" recovers from ~15% damage, the level most QR generators default to.
  filter.setValue("M", forKey: "inputCorrectionLevel")

  guard let generated = filter.outputImage else {
    FileHandle.standardError.write(Data("failed to generate image \(index)\n".utf8))
    exit(1)
  }

  // The generator draws one pixel per module; scale it up to the target size
  // with nearest-neighbour sampling so the modules stay sharp.
  let scale = CGFloat(pixels) / generated.extent.width
  let scaled = generated.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

  guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
    FileHandle.standardError.write(Data("failed to render image \(index)\n".utf8))
    exit(1)
  }

  let file = outDirectory.appendingPathComponent(String(format: "qr-%03d.png", index))
  guard
    let destination = CGImageDestinationCreateWithURL(
      file as CFURL, UTType.png.identifier as CFString, 1, nil)
  else {
    FileHandle.standardError.write(Data("failed to open \(file.path)\n".utf8))
    exit(1)
  }
  CGImageDestinationAddImage(destination, cgImage, nil)
  guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write(Data("failed to write \(file.path)\n".utf8))
    exit(1)
  }
}

print("wrote \(count) images of \(pixels)x\(pixels) px to \(outDirectory.path)")

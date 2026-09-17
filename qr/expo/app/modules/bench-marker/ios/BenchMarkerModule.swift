import ExpoModulesCore
import Foundation
import os

/// Writes the benchmark markers described in AGENTS.md to the platform log.
///
/// JavaScript takes the timestamps and hands them over through this module;
/// only `processStart` is taken here, because JavaScript cannot see it.
/// `console.log` is not used: it does not reach the app log in a release build.
public class BenchMarkerModule: Module {
  public func definition() -> ModuleDefinition {
    Name("BenchMarker")

    // Synchronous, so reporting a marker cannot be deferred past the moment
    // it is measuring.
    Function("mark") { (name: String, epochMs: Double) in
      BenchMarker.mark(name, epochMs: Int64(epochMs))
    }

    /// Emits `processStart` as well, the one marker JavaScript cannot know.
    Function("markLaunch") { (name: String, epochMs: Double) in
      if let start = BenchMarker.processStartEpochMs() {
        BenchMarker.mark("processStart", epochMs: start)
      }
      BenchMarker.mark(name, epochMs: Int64(epochMs))
    }

    // A figure rather than a time; see AGENTS.md.
    Function("markValue") { (name: String, value: String) in
      BenchMarker.markValue(name, value: value)
    }

    // The benchmark's preparation step, which is not measured: unpack the
    // bundled QR images into the app's own storage so the decode loop can
    // read them by file path, like the other implementations do.
    Function("prepareImages") { () -> [String] in
      try QrImages.unpack()
    }
  }
}

enum BenchMarker {
  private static let logger = Logger(subsystem: "bench", category: "marker")

  static func mark(_ name: String, epochMs: Int64) {
    // Interpolated values are redacted as <private> in release builds unless
    // they are explicitly public.
    logger.notice("BENCH|\(name, privacy: .public)|\(epochMs, privacy: .public)")
    // On a physical iPhone the app log carries only the process's own output,
    // not unified logging, so the line goes to stderr as well.
    fputs("BENCH|\(name)|\(epochMs)\n", stderr)
  }

  static func markValue(_ name: String, value: String) {
    logger.notice("BENCHVAL|\(name, privacy: .public)|\(value, privacy: .public)")
    fputs("BENCHVAL|\(name)|\(value)\n", stderr)
  }

  /// When the kernel started this process, which is where a cold start begins.
  static func processStartEpochMs() -> Int64? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else {
      return nil
    }
    let start = info.kp_proc.p_un.__p_starttime
    let seconds = TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1_000_000
    return Int64((seconds * 1000).rounded())
  }
}

enum QrImages {
  /// Copies `qr/*.png` out of the app bundle into Documents, and returns the
  /// paths in name order. Images already there are left alone.
  static func unpack() throws -> [String] {
    guard let source = Bundle.main.resourceURL?.appendingPathComponent("qr") else {
      throw NSError(domain: "bench", code: 1, userInfo: [NSLocalizedDescriptionKey: "no bundle"])
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
}

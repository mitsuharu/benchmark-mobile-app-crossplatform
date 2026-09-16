import Flutter
import Foundation
import os

/// Writes the benchmark markers described in AGENTS.md to the platform log.
///
/// Dart takes the timestamps and hands them over on `bench/marker`; only
/// `processStart` is taken here, because Dart cannot see it.
enum BenchMarker {
  static let channelName = "bench/marker"

  private static let logger = Logger(subsystem: "bench", category: "marker")

  static func mark(_ name: String, epochMs: Int64) {
    // Interpolated values are redacted as <private> in release builds unless
    // they are explicitly public.
    logger.notice("BENCH|\(name, privacy: .public)|\(epochMs, privacy: .public)")
    // On a physical iPhone the app log carries only the process's own output,
    // not unified logging, so the line goes to stderr as well.
    fputs("BENCH|\(name)|\(epochMs)\n", stderr)
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

  /// Answers the Dart side's calls. `markLaunch` also emits `processStart`.
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard
        let arguments = call.arguments as? [String: Any],
        let name = arguments["name"] as? String,
        let epochMs = arguments["epochMs"] as? NSNumber
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      if call.method == "markLaunch", let start = processStartEpochMs() {
        mark("processStart", epochMs: start)
      }
      mark(name, epochMs: epochMs.int64Value)
      result(nil)
    }
  }
}

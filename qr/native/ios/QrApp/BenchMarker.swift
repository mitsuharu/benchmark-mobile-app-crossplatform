import Foundation
import os

/// Emits the benchmark markers described in AGENTS.md.
///
/// The runner reads these from the app log, so the format is part of the
/// contract: `BENCH|<name>|<epochMs>` for times, `BENCHVAL|<name>|<value>`
/// for figures.
enum BenchMarker {
  private static let logger = Logger(subsystem: "bench", category: "marker")
  private static var didMarkLaunch = false

  static func mark(_ name: String, epochMs: Int64) {
    // Interpolated values are redacted as <private> in release builds unless
    // they are explicitly public.
    logger.notice("BENCH|\(name, privacy: .public)|\(epochMs, privacy: .public)")
    // On a physical iPhone the app log carries only the process's own output,
    // not unified logging, so the line goes to stderr as well.
    fputs("BENCH|\(name)|\(epochMs)\n", stderr)
  }

  static func mark(_ name: String, at date: Date = Date()) {
    mark(name, epochMs: Int64((date.timeIntervalSince1970 * 1000).rounded()))
  }

  static func markValue(_ name: String, value: String) {
    logger.notice("BENCHVAL|\(name, privacy: .public)|\(value, privacy: .public)")
    fputs("BENCHVAL|\(name)|\(value)\n", stderr)
  }

  /// The first frame of the screen, with the process start alongside it.
  static func markLaunch() {
    guard !didMarkLaunch else { return }
    didMarkLaunch = true
    DispatchQueue.main.async {
      if let processStart = processStartDate() {
        mark("processStart", at: processStart)
      }
      mark("homeFirstFrame")
    }
  }

  /// When the kernel started this process, which is where a cold start begins.
  private static func processStartDate() -> Date? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else {
      return nil
    }
    let start = info.kp_proc.p_un.__p_starttime
    return Date(
      timeIntervalSince1970: TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1_000_000
    )
  }
}

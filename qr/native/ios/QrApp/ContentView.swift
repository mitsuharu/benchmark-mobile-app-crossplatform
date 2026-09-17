import SwiftUI

/// How often the screen redraws while decoding; see AGENTS.md.
private let progressInterval = 0.1

private enum Phase: Equatable {
  case preparing
  case ready
  case running
  case failed(String)
  case done(decoded: Int, totalMs: Int, perImageMs: Double)
}

/// The QR decode benchmark, written natively: unpack the bundled images, then
/// decode them one after the other with Vision.
struct ContentView: View {
  @State private var phase: Phase = .preparing
  @State private var paths: [String] = []
  @State private var done = 0
  @State private var elapsed: TimeInterval = 0

  /// The decode loop only writes this counter; the screen reads it on a timer
  /// so a redraw never lands between two decodes.
  @State private var progress = DecodeProgress()
  @State private var startedAt = Date()
  private let ticker = Timer.publish(every: progressInterval, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("QR デコード").font(.title)
      Text("native · Vision").font(.subheadline).foregroundStyle(.secondary)

      switch phase {
      case .preparing:
        Text("画像を展開中...")
      case .failed(let message):
        Text("失敗: \(message)").foregroundStyle(.red)
      default:
        Text("準備完了: \(paths.count) 枚")
      }

      if phase == .ready || isDone {
        Button("デコードを開始", action: start)
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("startDecode")
      }

      if phase == .running {
        Text("デコード中: \(done) / \(paths.count)").font(.title3.bold())
        Text(String(format: "経過: %.1f 秒", elapsed))
      }

      if case .done(let decoded, let totalMs, let perImageMs) = phase {
        Text("デコード完了: \(decoded) / \(paths.count)").font(.title3.bold())
        Text("合計: \(totalMs) ms")
        Text(String(format: "1 枚あたり: %.2f ms", perImageMs))
      }

      Spacer()
    }
    .padding(24)
    .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear {
      BenchMarker.markLaunch()
      prepare()
    }
    .onReceive(ticker) { _ in
      guard phase == .running else { return }
      done = progress.current
      elapsed = Date().timeIntervalSince(startedAt)
    }
  }

  private var isDone: Bool {
    if case .done = phase { return true }
    return false
  }

  private func prepare() {
    guard phase == .preparing else { return }
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let prepared = try unpackImages()
        DispatchQueue.main.async {
          paths = prepared
          phase = .ready
        }
      } catch {
        DispatchQueue.main.async { phase = .failed(error.localizedDescription) }
      }
    }
  }

  private func start() {
    progress = DecodeProgress()
    done = 0
    elapsed = 0
    startedAt = Date()
    phase = .running

    let paths = paths
    let progress = progress
    DispatchQueue.global(qos: .userInitiated).async {
      let run = decodeAll(paths: paths, progress: progress)
      // Written now that the loop is over, so logging stays out of the
      // measurement (see AGENTS.md).
      BenchMarker.mark("decodeStarted", at: run.startedAt)
      BenchMarker.mark("decodeFinished", at: run.finishedAt)
      BenchMarker.markValue("decodedCount", value: String(run.decoded))
      BenchMarker.markValue(
        "decodeDurationsUs", value: run.durationsUs.map(String.init).joined(separator: ","))

      let sorted = run.durationsUs.sorted()
      let totalMs = Int((run.finishedAt.timeIntervalSince(run.startedAt) * 1000).rounded())
      DispatchQueue.main.async {
        done = run.durationsUs.count
        phase = .done(
          decoded: run.decoded,
          totalMs: totalMs,
          perImageMs: Double(sorted[sorted.count / 2]) / 1000
        )
      }
    }
  }
}

#Preview {
  ContentView()
}

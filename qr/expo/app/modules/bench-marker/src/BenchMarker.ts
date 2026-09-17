import { NativeModule, requireNativeModule } from 'expo'

/** The markers the app reports for the benchmark (see AGENTS.md). */
export type BenchMarkerName =
  | 'homeFirstFrame'
  | 'decodeStarted'
  | 'decodeFinished'

declare class BenchMarkerModule extends NativeModule {
  /** Writes `BENCH|<name>|<epochMs>` to the platform log. */
  mark(name: BenchMarkerName, epochMs: number): void
  /** The same, plus the `processStart` marker only the native side knows. */
  markLaunch(name: BenchMarkerName, epochMs: number): void
  /** Writes `BENCHVAL|<name>|<value>`, for figures rather than times. */
  markValue(name: string, value: string): void
  /**
   * Unpacks the bundled QR images into the app's own storage and returns
   * their paths. The benchmark's preparation step, which is not measured.
   */
  prepareImages(): string[]
}

export default requireNativeModule<BenchMarkerModule>('BenchMarker')

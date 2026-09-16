import { NativeModule, requireNativeModule } from 'expo'

/** The markers the app reports for the benchmark (see AGENTS.md). */
export type BenchMarkerName =
  | 'homeFirstFrame'
  | 'searchOpenTapped'
  | 'searchFirstFrame'
  | 'searchTapped'
  | 'searchRendered'
  | 'resultsReceived'
  | 'commandSent'
  | 'keywordApplied'

declare class BenchMarkerModule extends NativeModule {
  /** Writes `BENCH|<name>|<epochMs>` to the platform log. */
  mark(name: BenchMarkerName, epochMs: number): void
  /** The same, plus the `processStart` marker only the native side knows. */
  markLaunch(name: BenchMarkerName, epochMs: number): void
}

export default requireNativeModule<BenchMarkerModule>('BenchMarker')

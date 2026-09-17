/**
 * Reports the benchmark markers to the native log.
 *
 * The time is taken here, on the JS side; the native module writes the line.
 * `console.log` would not do: it reaches neither unified logging nor logcat
 * in a release build, and the runner reads the app log.
 */
import BenchMarker, { type BenchMarkerName } from './src/BenchMarker'

export type { BenchMarkerName }

export function markBench(name: BenchMarkerName, at: number = Date.now()) {
  BenchMarker.mark(name, at)
}

/**
 * Reports a marker once the change that was just committed has been drawn:
 * a commit is applied to the native views before the next frame, and
 * `requestAnimationFrame` runs at the start of that frame.
 */
export function markAfterFrame(name: BenchMarkerName) {
  requestAnimationFrame(() => markBench(name))
}

/** Unpacks the bundled QR images and returns their paths, in name order. */
export function prepareImages(): string[] {
  return BenchMarker.prepareImages()
}

/** Reports a figure (not a time), such as the per-image durations. */
export function markBenchValue(name: string, value: string) {
  BenchMarker.markValue(name, value)
}

/**
 * Marks the first frame of the home screen, with `processStart` alongside it.
 */
export function markLaunchAfterFrame() {
  requestAnimationFrame(() =>
    BenchMarker.markLaunch('homeFirstFrame', Date.now()),
  )
}

/**
 * The QR decode benchmark: what gets measured, how a run is driven, and how
 * one run's log becomes numbers.
 *
 * It shares the marker format and the agent-device wrapper with the main
 * benchmark, but the apps, the scenario and the metrics are its own
 * (see AGENTS.md).
 */
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import { summarize } from './stats.mjs'

export const QR_FRAMEWORKS = ['native', 'flutter', 'expo']

const BENCH_ROOT = fileURLToPath(new URL('..', import.meta.url))

const APP_IDS = {
  native: 'com.example.benchmark.qr.nativeapp',
  flutter: 'com.example.benchmark.qr.qrflutterapp',
  expo: 'com.example.benchmark.qr.expoapp',
}

export function qrAppId(framework) {
  const id = APP_IDS[framework]
  if (!id) {
    throw new Error(`Unknown framework "${framework}"`)
  }
  return id
}

/** Where scripts/build.sh puts the build, under the `qr-` framework names. */
export function qrArtifactPath(framework, platform) {
  const file = platform === 'ios' ? 'App.app' : 'app-release.apk'
  const dir = platform === 'ios' ? 'ios-device' : 'android'
  return path.join(
    BENCH_ROOT,
    'artifacts',
    'release',
    `qr-${framework}`,
    dir,
    file,
  )
}

/** How agent-device reaches the one screen. */
export const QR_SELECTORS = {
  ios: { start: 'id="startDecode"' },
  android: { start: 'id="startDecode"' },
}

/** Text that proves the run has finished. `完了` alone also matches 準備完了. */
export const DECODE_DONE_TEXT = 'デコード完了'

export const QR_WAIT_MS = 600_000

/**
 * The figures the apps write as `BENCHVAL|<name>|<value>` (see AGENTS.md).
 * Times stay in the `BENCH|` markers; this carries what a timestamp cannot.
 */
const VALUE = /BENCHVAL\|([A-Za-z]+)\|([0-9,]+)/

export function parseValues(log) {
  const values = {}
  for (const line of log.split('\n')) {
    const match = VALUE.exec(line)
    if (match) {
      values[match[1]] = match[2]
    }
  }
  return values
}

/** The duration of each decode, in milliseconds. */
export function durationsMs(values) {
  const raw = values.decodeDurationsUs
  if (!raw) {
    return []
  }
  return raw
    .split(',')
    .map((value) => Number(value) / 1000)
    .filter((value) => Number.isFinite(value))
}

/**
 * One run's numbers: how long the whole loop took, and the spread over the
 * images inside it.
 */
export function computeQrRun(markers, values) {
  const at = (name) =>
    markers.find((marker) => marker.name === name)?.epochMs ?? null
  const start = at('decodeStarted')
  const finish = at('decodeFinished')
  const processStart = at('processStart')
  const firstFrame = at('homeFirstFrame')
  const perImage = durationsMs(values)

  return {
    coldStartMs:
      processStart != null && firstFrame != null
        ? firstFrame - processStart
        : null,
    totalMs: start != null && finish != null ? finish - start : null,
    images: perImage.length,
    decodedCount:
      values.decodedCount != null ? Number(values.decodedCount) : null,
    perImageMs: summarize(perImage),
  }
}

#!/usr/bin/env node
/**
 * Records the QR decode GIFs in qr/README.md: each app decoding the same 500
 * images, with its progress and elapsed time on screen.
 *
 *   node demo-qr.mjs --platform android --serial <serial> --seconds 22
 *   node demo-qr.mjs --platform ios --udid <udid> --seconds 30
 *
 * Every recording runs for the same number of seconds, so the three GIFs can
 * be put side by side and read against each other: the slower ones are still
 * counting when the faster one has stopped.
 *
 * Build and install the apps first (scripts/build.sh qr-<framework> ...).
 */
import { execFile } from 'node:child_process'
import { mkdir, mkdtemp } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseArgs, promisify } from 'node:util'

import { AgentDevice } from './lib/agent-device.mjs'
import {
  QR_FRAMEWORKS,
  QR_SELECTORS,
  QR_WAIT_MS,
  qrAppId,
  qrArtifactPath,
} from './lib/qr.mjs'
import { PLATFORMS } from './lib/targets.mjs'

const { values: options } = parseArgs({
  options: {
    platform: { type: 'string' },
    framework: { type: 'string', default: 'all' },
    udid: { type: 'string' },
    serial: { type: 'string' },
    seconds: { type: 'string', default: '22' },
    out: { type: 'string', default: '../docs/media' },
    width: { type: 'string', default: '270' },
    fps: { type: 'string', default: '8' },
    'skip-install': { type: 'boolean', default: false },
  },
})

const platform = options.platform
if (!PLATFORMS.includes(platform)) {
  console.error(`--platform must be one of: ${PLATFORMS.join(', ')}`)
  process.exit(1)
}
const frameworks =
  options.framework === 'all' ? QR_FRAMEWORKS : options.framework.split(',')
/** The length of the GIF. */
const gifSeconds = Number(options.seconds)
/**
 * The recorder does not stop to the second, and can hand back less than it
 * was asked for, so it runs with headroom and the GIF is trimmed after.
 */
const recordMs = (gifSeconds + 5) * 1000

const target = [
  '--platform',
  platform,
  ...(options.udid ? ['--udid', options.udid] : []),
  ...(options.serial ? ['--serial', options.serial] : []),
]

const BENCH_ROOT = path.dirname(fileURLToPath(import.meta.url))
const outDir = path.resolve(BENCH_ROOT, options.out)
const workDir = await mkdtemp(path.join(tmpdir(), 'qr-demo-'))

async function record(framework) {
  const id = qrAppId(framework)
  const selectors = QR_SELECTORS[platform]
  const device = new AgentDevice({ session: `qr-demo-${platform}` })
  const video = path.join(workDir, `qr-${platform}-${framework}.mp4`)

  if (!options['skip-install']) {
    await device.call(
      ['install', id, qrArtifactPath(framework, platform), ...target],
      {
        timeoutMs: 900_000,
      },
    )
  }
  await device.call(['open', id, '--relaunch', ...target])
  await device.call(['wait', selectors.start, String(QR_WAIT_MS)])

  await device.call(['record', 'start', video, '--quality', 'high'])
  try {
    // A beat before the tap, so the GIF starts from the same still frame.
    await device.call(['wait', '800'])
    await device.call(['press', selectors.start])
    await device.call(['wait', String(recordMs)], {
      timeoutMs: recordMs + 60_000,
    })
  } finally {
    await device.call(['record', 'stop'])
    await device.call(['close']).catch(() => {})
  }

  const gif = path.join(outDir, `qr-${platform}-${framework}.gif`)
  // Trimmed so the three GIFs of a platform are the same length and can be
  // read against each other.
  const { stdout } = await promisify(execFile)('swift', [
    path.join(BENCH_ROOT, 'scripts', 'mp4-to-gif.swift'),
    video,
    gif,
    options.width,
    options.fps,
    String(gifSeconds),
    // The lower half of the screen is empty; dropping it makes the numbers
    // readable when the three GIFs sit next to each other.
    '0.45',
  ])
  console.log(`[qr-demo] ${stdout.trim()}`)
}

await mkdir(outDir, { recursive: true })
for (const framework of frameworks) {
  await record(framework)
}

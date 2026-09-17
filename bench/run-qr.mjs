#!/usr/bin/env node
/**
 * Runs the QR decode benchmark against the builds in artifacts/release/qr-*
 * and writes the raw numbers to results/qr/<platform>-<framework>.json.
 *
 *   node run-qr.mjs --platform android --serial <serial>
 *   node run-qr.mjs --platform ios --udid <udid> --framework expo
 *
 * Physical devices only, release builds only (see AGENTS.md): the apps do
 * several seconds of work per run, which a simulator would not represent.
 */
import { mkdir, readdir, readFile, stat, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseArgs } from 'node:util'

import { AgentDevice } from './lib/agent-device.mjs'
import { iterationLabel, splitByIteration } from './lib/log-segments.mjs'
import { parseMarkers } from './lib/markers.mjs'
import {
  computeQrRun,
  DECODE_DONE_TEXT,
  parseValues,
  QR_FRAMEWORKS,
  QR_SELECTORS,
  QR_WAIT_MS,
  qrAppId,
  qrArtifactPath,
} from './lib/qr.mjs'
import { memoryKb } from './lib/scenario.mjs'
import { summarize } from './lib/stats.mjs'
import { PLATFORMS } from './lib/targets.mjs'

const { values: options } = parseArgs({
  options: {
    platform: { type: 'string' },
    framework: { type: 'string', default: 'all' },
    iterations: { type: 'string', default: '5' },
    warmup: { type: 'string', default: '1' },
    retries: { type: 'string', default: '2' },
    'settle-ms': { type: 'string', default: '2000' },
    udid: { type: 'string' },
    serial: { type: 'string' },
    // How the README names the device, e.g. "iPhone XR 実機（iOS 18.7）".
    'device-label': { type: 'string' },
    out: { type: 'string', default: 'results/qr' },
    'skip-install': { type: 'boolean', default: false },
    verbose: { type: 'boolean', default: false },
  },
})

const platform = options.platform
if (!PLATFORMS.includes(platform)) {
  console.error(`--platform must be one of: ${PLATFORMS.join(', ')}`)
  process.exit(1)
}
const frameworks =
  options.framework === 'all' ? QR_FRAMEWORKS : options.framework.split(',')
const iterations = Number(options.iterations)
const warmup = Number(options.warmup)
const retries = Number(options.retries)
const settleMs = Number(options['settle-ms'])

const target = [
  '--platform',
  platform,
  ...(options.udid ? ['--udid', options.udid] : []),
  ...(options.serial ? ['--serial', options.serial] : []),
]

const log = (line) => console.log(`[qr] ${line}`)

async function sizeOf(file) {
  const info = await stat(file)
  if (!info.isDirectory()) {
    return info.size
  }
  let total = 0
  for (const entry of await readdir(file)) {
    total += await sizeOf(path.join(file, entry))
  }
  return total
}

async function measure(framework) {
  const id = qrAppId(framework)
  const artifact = qrArtifactPath(framework, platform)
  const selectors = QR_SELECTORS[platform]
  const device = new AgentDevice({
    session: `qr-${platform}`,
    log: options.verbose ? log : () => {},
  })

  log(
    `${platform}/${framework}: installing ${path.relative(process.cwd(), artifact)}`,
  )
  if (!options['skip-install']) {
    await device.call(['install', id, artifact, ...target], {
      timeoutMs: 900_000,
    })
  }
  const opened = await device.call(['open', id, '--relaunch', ...target])

  const readIfPresent = (file) => readFile(file, 'utf8').catch(() => '')
  const readSessionLog = async () => {
    const { path: logPath } = await device.call(['logs', 'path'])
    return `${await readIfPresent(`${logPath}.1`)}\n${await readIfPresent(logPath)}`
  }

  const total = warmup + iterations
  const runs = []
  try {
    for (let index = 0; index < total; index++) {
      for (let attempt = 0; ; attempt++) {
        await device.call(['logs', 'clear', '--restart'])
        await device.call(['logs', 'mark', iterationLabel(index)])
        try {
          // On a physical iPhone `logs clear --restart` has just relaunched
          // the app to capture its output; relaunching again would start a
          // process whose markers never reach the log.
          if (!(platform === 'ios')) {
            await device.call(['open', id, '--relaunch'])
          } else {
            await device.call(['open', id])
          }
          await device.call(['wait', selectors.start, String(QR_WAIT_MS)])
          await device.call(['press', selectors.start])
          await device.call([
            'wait',
            'text',
            DECODE_DONE_TEXT,
            String(QR_WAIT_MS),
          ])
          await device.call(['wait', String(settleMs)])
          const sample = await device.call(['perf', 'memory', 'sample'])
          // Let the log stream flush the run's markers.
          await device.call(['wait', '2000'])
          const [segment] = splitByIteration(
            (await readSessionLog()).replaceAll(
              iterationLabel(index),
              iterationLabel(0),
            ),
            1,
          )
          runs.push({
            ...computeQrRun(parseMarkers(segment), parseValues(segment)),
            memoryKb: memoryKb(sample, platform),
          })
          break
        } catch (error) {
          if (attempt >= retries) {
            throw error
          }
          log(
            `${platform}/${framework}: run ${index} failed, retrying (${error.message})`,
          )
        }
      }
      log(
        `${platform}/${framework}: run ${index + 1}/${total}${index < warmup ? ' (warm-up)' : ''}`,
      )
    }
  } finally {
    await device.call(['logs', 'stop']).catch(() => {})
  }
  await device.call(['close']).catch(() => {})

  const all = runs.map((run, index) => ({
    index,
    warmup: index < warmup,
    ...run,
  }))
  const measured = all.filter((run) => !run.warmup)
  const pick = (key) => summarize(measured.map((run) => run[key]))

  return {
    framework,
    platform,
    build: 'release',
    physical: true,
    appId: id,
    device: {
      name: opened.device,
      id: opened.id,
      ...(options['device-label'] ? { label: options['device-label'] } : {}),
    },
    measuredAt: new Date().toISOString(),
    agentDevice: await AgentDevice.version(),
    iterations,
    warmup,
    images: measured[0]?.images ?? null,
    appSizeBytes: await sizeOf(artifact),
    summary: {
      coldStartMs: pick('coldStartMs'),
      totalMs: pick('totalMs'),
      memoryKb: pick('memoryKb'),
      decodedCount: pick('decodedCount'),
      // Every image of every measured run, so the spread is over all of them.
      perImageMs: summarize(
        measured.flatMap((run) =>
          run.perImageMs ? [run.perImageMs.median] : [],
        ),
      ),
    },
    runs: all,
  }
}

const outDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  options.out,
)
await mkdir(outDir, { recursive: true })

for (const framework of frameworks) {
  const result = await measure(framework)
  const file = path.join(outDir, `${platform}-${framework}.json`)
  await writeFile(file, `${JSON.stringify(result, null, 2)}\n`)

  const { totalMs, perImageMs, decodedCount } = result.summary
  log(
    `${platform}/${framework}: total=${Math.round(totalMs?.median ?? 0)}ms ` +
      `perImage=${(perImageMs?.median ?? 0).toFixed(2)}ms decoded=${decodedCount?.median ?? '-'}`,
  )
  log(`${platform}/${framework}: wrote ${path.relative(process.cwd(), file)}`)
}

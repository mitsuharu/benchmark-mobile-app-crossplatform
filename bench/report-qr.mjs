#!/usr/bin/env node
/**
 * Turns results/qr/*.json into the tables of qr/README.md.
 *
 *   node report-qr.mjs            # print them
 *   node report-qr.mjs --write    # replace the section in ../qr/README.md
 *
 * The section sits between `<!-- qr:results:start -->` and
 * `<!-- qr:results:end -->`.
 */
import { readdir, readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { parseArgs } from 'node:util'

import { QR_FRAMEWORKS } from './lib/qr.mjs'
import { PLATFORMS } from './lib/targets.mjs'

const { values: options } = parseArgs({
  options: {
    results: { type: 'string', default: 'results/qr' },
    write: { type: 'boolean', default: false },
  },
})

const BENCH_ROOT = path.dirname(fileURLToPath(import.meta.url))
const README = path.join(BENCH_ROOT, '..', 'qr', 'README.md')
const START = '<!-- qr:results:start -->'
const END = '<!-- qr:results:end -->'

const PLATFORM_NAMES = { ios: 'iOS', android: 'Android' }
const FRAMEWORK_NAMES = { native: 'native', flutter: 'Flutter', expo: 'Expo' }
const LIBRARIES = {
  ios: { native: 'Vision', flutter: 'mobile_scanner', expo: 'nitro-zxing' },
  android: { native: 'ML Kit', flutter: 'mobile_scanner', expo: 'nitro-zxing' },
}

const ms = (summary) => (summary ? `${Math.round(summary.median)} ms` : '—')
const msFine = (summary) => (summary ? `${summary.median.toFixed(2)} ms` : '—')
const mb = (kb) => (kb / 1024).toFixed(1)
const memory = (summary) => (summary ? `${mb(summary.median)} MB` : '—')
const appSize = (result) => `${mb(result.appSizeBytes / 1024)} MB`

function table(header, rows) {
  const line = (cells) => `| ${cells.join(' | ')} |`
  return [
    line(header),
    line(header.map((_, index) => (index === 0 ? '---' : '---:'))),
    ...rows.map(line),
  ].join('\n')
}

async function loadResults() {
  const dir = path.resolve(BENCH_ROOT, options.results)
  const files = await readdir(dir).catch(() => [])
  const results = {}
  for (const file of files.filter((name) => name.endsWith('.json'))) {
    const result = JSON.parse(await readFile(path.join(dir, file), 'utf8'))
    results[`${result.platform}/${result.framework}`] = result
  }
  return results
}

function deviceLabel(result) {
  return result.device.label ?? `${result.device.name}（実機）`
}

function platformSection(platform, results) {
  const frameworks = QR_FRAMEWORKS.filter(
    (framework) => results[`${platform}/${framework}`],
  )
  if (frameworks.length === 0) {
    return null
  }
  const of = (framework) => results[`${platform}/${framework}`]
  const header = [
    '',
    ...frameworks.map((framework) => FRAMEWORK_NAMES[framework]),
  ]
  const sample = of(frameworks[0])
  const memoryKind = platform === 'ios' ? 'RSS' : 'PSS'
  const baseline = of('native')?.summary.perImageMs?.median

  return [
    `### ${PLATFORM_NAMES[platform]}：${deviceLabel(sample)}`,
    '',
    `リリースビルド。${sample.images} 枚を 1 回として、${sample.iterations} 回の中央値` +
      `（ウォームアップ ${sample.warmup} 回を除く）。`,
    '',
    '#### ライブラリ',
    '',
    table(header, [
      [
        'デコーダ',
        ...frameworks.map((framework) => LIBRARIES[platform][framework]),
      ],
    ]),
    '',
    '#### 時間',
    '',
    table(header, [
      [
        `${sample.images} 枚の合計`,
        ...frameworks.map((framework) => ms(of(framework).summary.totalMs)),
      ],
      [
        '1 枚あたり（中央値）',
        ...frameworks.map((framework) =>
          msFine(of(framework).summary.perImageMs),
        ),
      ],
      [
        'native を 1 とした比',
        ...frameworks.map((framework) => {
          const value = of(framework).summary.perImageMs?.median
          return baseline && value ? `${(value / baseline).toFixed(2)}` : '—'
        }),
      ],
      [
        'コールドスタート',
        ...frameworks.map((framework) => ms(of(framework).summary.coldStartMs)),
      ],
    ]),
    '',
    `#### デコード結果・メモリ（${memoryKind}）・アプリサイズ`,
    '',
    table(header, [
      [
        `デコードできた枚数（${sample.images} 枚中）`,
        ...frameworks.map(
          (framework) => `${of(framework).summary.decodedCount?.median ?? '—'}`,
        ),
      ],
      [
        'デコード後のメモリ',
        ...frameworks.map((framework) =>
          memory(of(framework).summary.memoryKb),
        ),
      ],
      [
        platform === 'ios' ? '.app（実機向け）' : 'APK',
        ...frameworks.map((framework) => appSize(of(framework))),
      ],
    ]),
  ].join('\n')
}

const results = await loadResults()
const rendered = PLATFORMS.map((platform) => platformSection(platform, results))
  .filter(Boolean)
  .join('\n\n')

if (!options.write) {
  console.log(rendered)
} else {
  const readme = await readFile(README, 'utf8')
  const from = readme.indexOf(START)
  const to = readme.indexOf(END)
  if (from === -1 || to === -1) {
    throw new Error(`qr/README.md has no ${START} ... ${END} section`)
  }
  await writeFile(
    README,
    `${readme.slice(0, from + START.length)}\n\n${rendered}\n\n${readme.slice(to)}`,
  )
  console.log(`Updated ${path.relative(process.cwd(), README)}`)
}

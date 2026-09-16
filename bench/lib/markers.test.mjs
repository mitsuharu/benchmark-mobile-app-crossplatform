import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { computeTimings, parseMarkers } from './markers.mjs'

describe('parseMarkers', () => {
  it('reads markers out of unified logging and logcat lines', () => {
    const log = [
      '2026-09-15 10:00:00.000 App[123:456] [bench:marker] BENCH|processStart|1000',
      '09-15 10:00:00.100  1234  1234 I Bench   : BENCH|homeFirstFrame|1350',
      'unrelated line',
    ].join('\n')

    assert.deepEqual(parseMarkers(log), [
      { name: 'processStart', epochMs: 1000 },
      { name: 'homeFirstFrame', epochMs: 1350 },
    ])
  })

  it('ignores redacted values', () => {
    // What a Logger interpolation without `privacy: .public` looks like.
    assert.deepEqual(parseMarkers('BENCH|<private>|<private>'), [])
  })

  it('keeps a marker once when it arrives through both unified logging and stderr', () => {
    const log = [
      '2026-09-15 10:00:00.000 App[123:456] [bench:marker] BENCH|searchOpenTapped|5000',
      'BENCH|searchOpenTapped|5000',
      'BENCH|searchFirstFrame|5300',
      'BENCH|searchOpenTapped|12000',
    ].join('\n')

    // The second visit must stay the second searchOpenTapped, not a copy of the first.
    assert.deepEqual(parseMarkers(log), [
      { name: 'searchOpenTapped', epochMs: 5000 },
      { name: 'searchFirstFrame', epochMs: 5300 },
      { name: 'searchOpenTapped', epochMs: 12000 },
    ])
  })
})

describe('computeTimings', () => {
  const run = [
    ['processStart', 1000],
    ['homeFirstFrame', 1400],
    ['searchOpenTapped', 5000],
    ['searchFirstFrame', 5300],
    ['searchTapped', 8000],
    ['resultsReceived', 8120],
    ['searchRendered', 8100],
    ['commandSent', 9000],
    ['keywordApplied', 9030],
    ['searchOpenTapped', 12000],
    ['searchFirstFrame', 12100],
  ].map(([name, epochMs]) => ({ name, epochMs }))

  it('measures each step of the scenario', () => {
    assert.deepEqual(computeTimings(run), {
      coldStartMs: 400,
      searchOpenColdMs: 300,
      searchOpenWarmMs: 100,
      searchRenderMs: 100,
      searchToHomeMs: 120,
      commandMs: 30,
    })
  })

  it('pairs markers by time, not by arrival order', () => {
    // A screen's markers can reach the log after the ones logged for it.
    const shuffled = [...run].reverse()

    assert.equal(computeTimings(shuffled).searchOpenWarmMs, 100)
  })

  it('reports a step that never finished as null', () => {
    const timings = computeTimings(
      run.filter((marker) => marker.name !== 'keywordApplied'),
    )

    assert.equal(timings.commandMs, null)
    assert.equal(timings.coldStartMs, 400)
  })

  it('reports a step that never started as null', () => {
    assert.equal(computeTimings([]).coldStartMs, null)
  })
})

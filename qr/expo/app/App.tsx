import { StatusBar } from 'expo-status-bar'
import { useCallback, useEffect, useRef, useState } from 'react'
import { Pressable, StyleSheet, Text, View } from 'react-native'

import {
  markBench,
  markBenchValue,
  markLaunchAfterFrame,
  prepareImages,
} from './modules/bench-marker'
import { decodeAll } from './src/decode'

type Phase = 'preparing' | 'ready' | 'running' | 'done' | 'failed'

/** How often the screen redraws while decoding; see AGENTS.md. */
const PROGRESS_INTERVAL_MS = 100

type Summary = {
  decoded: number
  totalMs: number
  perImageMs: number
}

/**
 * The QR decode benchmark, written entirely in React Native: unpack the
 * bundled images, then decode them one after the other with
 * react-native-nitro-zxing.
 */
export default function App() {
  const [phase, setPhase] = useState<Phase>('preparing')
  const [paths, setPaths] = useState<string[]>([])
  const [summary, setSummary] = useState<Summary | null>(null)
  const [error, setError] = useState<string | null>(null)
  // The decode loop only writes this counter; the screen reads it on a timer
  // so a redraw never lands between two decodes.
  const progress = useRef(0)
  const [done, setDone] = useState(0)
  const [elapsedMs, setElapsedMs] = useState(0)

  useEffect(() => markLaunchAfterFrame(), [])

  useEffect(() => {
    try {
      setPaths(prepareImages())
      setPhase('ready')
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : String(e))
      setPhase('failed')
    }
  }, [])

  const onStart = useCallback(async () => {
    progress.current = 0
    setDone(0)
    setElapsedMs(0)
    setPhase('running')
    const startedAt = Date.now()
    const ticker = setInterval(() => {
      setDone(progress.current)
      setElapsedMs(Date.now() - startedAt)
    }, PROGRESS_INTERVAL_MS)
    try {
      const run = await decodeAll(paths, progress)
      // Written now that the loop is over, so logging stays out of the
      // measurement (see AGENTS.md).
      markBench('decodeStarted', run.startedAt)
      markBench('decodeFinished', run.finishedAt)
      markBenchValue('decodedCount', String(run.decoded))
      markBenchValue('decodeDurationsUs', run.durationsUs.join(','))

      const totalMs = run.finishedAt - run.startedAt
      const sorted = [...run.durationsUs].sort((a, b) => a - b)
      setSummary({
        decoded: run.decoded,
        totalMs,
        perImageMs: sorted[Math.floor(sorted.length / 2)] / 1000,
      })
      setPhase('done')
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : String(e))
      setPhase('failed')
    } finally {
      clearInterval(ticker)
      setDone(progress.current)
    }
  }, [paths])

  return (
    <View style={styles.container}>
      <StatusBar style="dark" />
      <Text style={styles.title}>QR デコード</Text>
      <Text style={styles.subtitle}>react-native-nitro-zxing</Text>

      {phase === 'preparing' && (
        <Text style={styles.status}>画像を展開中...</Text>
      )}
      {phase === 'failed' && <Text style={styles.error}>失敗: {error}</Text>}
      {phase !== 'preparing' && phase !== 'failed' && (
        <Text style={styles.status}>準備完了: {paths.length} 枚</Text>
      )}

      {(phase === 'ready' || phase === 'done') && (
        <Pressable
          accessibilityRole="button"
          onPress={onStart}
          style={styles.start}
          testID="startDecode"
        >
          <Text style={styles.startLabel}>デコードを開始</Text>
        </Pressable>
      )}

      {phase === 'running' && (
        <>
          <Text style={styles.progress}>
            デコード中: {done} / {paths.length}
          </Text>
          <Text style={styles.status}>
            経過: {(elapsedMs / 1000).toFixed(1)} 秒
          </Text>
        </>
      )}

      {summary !== null && (
        <View style={styles.result}>
          <Text style={styles.done}>
            デコード完了: {summary.decoded} / {paths.length}
          </Text>
          <Text style={styles.line}>合計: {summary.totalMs} ms</Text>
          <Text style={styles.line}>
            1 枚あたり: {summary.perImageMs.toFixed(2)} ms
          </Text>
        </View>
      )}
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#fff',
    flex: 1,
    gap: 12,
    // Top-aligned like the native and Flutter apps, so the three screens
    // line up in the README's recordings.
    paddingHorizontal: 24,
    paddingTop: 64,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
  },
  subtitle: {
    color: '#6b7280',
    fontSize: 14,
  },
  status: {
    color: '#4b5563',
    fontSize: 16,
  },
  progress: {
    fontSize: 18,
    fontWeight: '600',
  },
  error: {
    color: '#b91c1c',
    fontSize: 14,
  },
  start: {
    alignItems: 'center',
    backgroundColor: '#111827',
    borderRadius: 10,
    marginTop: 8,
    paddingVertical: 14,
  },
  startLabel: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  result: {
    gap: 4,
    marginTop: 16,
  },
  done: {
    fontSize: 18,
    fontWeight: '700',
  },
  line: {
    color: '#4b5563',
    fontSize: 16,
  },
})

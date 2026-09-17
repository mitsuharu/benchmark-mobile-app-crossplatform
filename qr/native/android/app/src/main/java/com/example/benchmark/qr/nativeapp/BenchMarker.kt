package com.example.benchmark.qr.nativeapp

import android.os.Process
import android.os.SystemClock
import android.util.Log

/**
 * Emits the benchmark markers described in AGENTS.md.
 *
 * The runner reads these from logcat, so the format is part of the contract:
 * `BENCH|<name>|<epochMs>` for times, `BENCHVAL|<name>|<value>` for figures.
 */
object BenchMarker {
  private const val TAG = "Bench"
  private var didMarkLaunch = false

  fun mark(name: String, epochMs: Long = System.currentTimeMillis()) {
    Log.i(TAG, "BENCH|$name|$epochMs")
  }

  fun markValue(name: String, value: String) {
    Log.i(TAG, "BENCHVAL|$name|$value")
  }

  /** The first frame of the screen, with the process start alongside it. */
  fun markLaunch() {
    if (didMarkLaunch) return
    didMarkLaunch = true
    mark("processStart", processStartEpochMs())
    mark("homeFirstFrame")
  }

  /** When this process started, converted from uptime to wall-clock time. */
  private fun processStartEpochMs(): Long =
    System.currentTimeMillis() - (SystemClock.uptimeMillis() - Process.getStartUptimeMillis())
}

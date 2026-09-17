package com.example.benchmark.qr.qrflutterapp

import android.os.Process
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Writes the benchmark markers described in AGENTS.md to logcat.
 *
 * Dart takes the timestamps and hands them over on `bench/marker`; only
 * `processStart` is taken here, because Dart cannot see it.
 */
object BenchMarker {
  const val CHANNEL_NAME = "bench/marker"

  private const val TAG = "Bench"

  fun mark(name: String, epochMs: Long) {
    Log.i(TAG, "BENCH|$name|$epochMs")
  }

  /** When this process started, converted from uptime to wall-clock time. */
  fun processStartEpochMs(): Long =
    System.currentTimeMillis() - (SystemClock.uptimeMillis() - Process.getStartUptimeMillis())

  /** A figure rather than a time; see AGENTS.md. */
  fun markValue(name: String, value: String) {
    Log.i(TAG, "BENCHVAL|$name|$value")
  }

  /** Answers the Dart side's calls. `markLaunch` also emits `processStart`. */
  fun register(messenger: BinaryMessenger) {
    MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
      val name = call.argument<String>("name")
      if (name == null) {
        result.notImplemented()
        return@setMethodCallHandler
      }
      if (call.method == "markValue") {
        markValue(name, call.argument<String>("value") ?: "")
        result.success(null)
        return@setMethodCallHandler
      }
      val epochMs = call.argument<Number>("epochMs")
      if (epochMs == null) {
        result.notImplemented()
        return@setMethodCallHandler
      }
      if (call.method == "markLaunch") {
        mark("processStart", processStartEpochMs())
      }
      mark(name, epochMs.toLong())
      result.success(null)
    }
  }
}

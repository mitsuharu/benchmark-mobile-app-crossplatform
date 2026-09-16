package expo.modules.benchmarker

import android.os.Process
import android.os.SystemClock
import android.util.Log
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

/**
 * Writes the benchmark markers described in AGENTS.md to logcat.
 *
 * JavaScript takes the timestamps and hands them over through this module;
 * only `processStart` is taken here, because JavaScript cannot see it.
 * `console.log` is not used: it does not reach logcat in a release build.
 */
class BenchMarkerModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("BenchMarker")

    // Synchronous, so reporting a marker cannot be deferred past the moment
    // it is measuring.
    Function("mark") { name: String, epochMs: Double -> mark(name, epochMs.toLong()) }

    // Emits `processStart` as well, the one marker JavaScript cannot know.
    Function("markLaunch") { name: String, epochMs: Double ->
      mark("processStart", processStartEpochMs())
      mark(name, epochMs.toLong())
    }
  }

  private fun mark(name: String, epochMs: Long) {
    Log.i("Bench", "BENCH|$name|$epochMs")
  }

  /** When this process started, converted from uptime to wall-clock time. */
  private fun processStartEpochMs(): Long =
    System.currentTimeMillis() - (SystemClock.uptimeMillis() - Process.getStartUptimeMillis())
}

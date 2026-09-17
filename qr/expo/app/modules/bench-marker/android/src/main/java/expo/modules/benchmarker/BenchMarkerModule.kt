package expo.modules.benchmarker

import android.os.Process
import android.os.SystemClock
import android.util.Log
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import java.io.File

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

    // A figure rather than a time; see AGENTS.md.
    Function("markValue") { name: String, value: String -> markValue(name, value) }

    // The benchmark's preparation step, which is not measured: unpack the
    // bundled QR images into the app's own storage so the decode loop can
    // read them by file path, like the other implementations do.
    Function("prepareImages") { unpackImages() }
  }

  /**
   * Copies the PNGs under `assets/qr` out of the APK into filesDir, and
   * returns the paths in name order. Images already there are left alone.
   * An APK asset has no file path of its own, which is why this exists.
   *
   * (A KDoc cannot say `qr` followed by a slash and a star: Kotlin nests
   * block comments, so that would open one.)
   */
  private fun unpackImages(): List<String> {
    val context = appContext.reactContext ?: error("no context")
    val destination = File(context.filesDir, "qr")
    destination.mkdirs()
    val names = (context.assets.list("qr") ?: emptyArray()).filter { it.endsWith(".png") }.sorted()
    return names.map { name ->
      val file = File(destination, name)
      // An empty file means a half-finished copy from an earlier launch.
      if (!file.exists() || file.length() == 0L) {
        context.assets.open("qr/$name").use { input ->
          file.outputStream().use { output -> input.copyTo(output) }
        }
      }
      file.absolutePath
    }
  }

  private fun markValue(name: String, value: String) {
    Log.i("Bench", "BENCHVAL|$name|$value")
  }

  private fun mark(name: String, epochMs: Long) {
    Log.i("Bench", "BENCH|$name|$epochMs")
  }

  /** When this process started, converted from uptime to wall-clock time. */
  private fun processStartEpochMs(): Long =
    System.currentTimeMillis() - (SystemClock.uptimeMillis() - Process.getStartUptimeMillis())
}

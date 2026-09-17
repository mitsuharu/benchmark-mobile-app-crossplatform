package com.example.benchmark.qr.nativeapp

import android.content.Context
import java.io.File

/** What the image at [index] encodes; see bench/scripts/make-qr-images.swift. */
fun expectedPayload(index: Int): String =
  "https://example.com/benchmark/qr/%03d".format(index)

/**
 * Copies the PNGs bundled under the `qr` assets directory into the app's own
 * storage, and returns the paths in name order.
 *
 * The benchmark decodes from file paths (see AGENTS.md), and an APK asset has
 * no path of its own. This is the preparation step, which is not measured.
 */
fun unpackImages(context: Context): List<String> {
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

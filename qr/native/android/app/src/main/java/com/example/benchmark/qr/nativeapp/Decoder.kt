package com.example.benchmark.qr.nativeapp

import android.net.Uri
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.android.gms.tasks.Tasks
import android.content.Context
import java.io.File
import java.util.concurrent.atomic.AtomicInteger

/** One run of the decode loop. */
data class DecodeRun(
  /** How many images decoded to the payload they were generated with. */
  val decoded: Int,
  /** How long each image took, in microseconds. */
  val durationsUs: LongArray,
  val startedAt: Long,
  val finishedAt: Long,
)

/**
 * Decodes every image in order, one after the other, with ML Kit.
 *
 * Nothing is logged in here: the timings are kept in memory and written out
 * once the loop is over, so the log does not land inside what is measured.
 * `Tasks.await` blocks, which is what keeps the loop sequential — this runs
 * on a background thread.
 */
fun decodeAll(
  context: Context,
  paths: List<String>,
  /**
   * How far the loop has got. Only a counter is written: the screen reads it
   * on its own timer so redrawing does not land between two decodes.
   */
  progress: AtomicInteger,
): DecodeRun {
  // QR only, like the other implementations ask for: leaving every format on
  // makes ML Kit look for barcodes the benchmark never uses.
  val options =
    BarcodeScannerOptions.Builder().setBarcodeFormats(Barcode.FORMAT_QR_CODE).build()
  val scanner = BarcodeScanning.getClient(options)
  val durationsUs = LongArray(paths.size)
  var decoded = 0

  val startedAt = System.currentTimeMillis()
  try {
    paths.forEachIndexed { index, path ->
      val began = System.nanoTime()
      val image = InputImage.fromFilePath(context, Uri.fromFile(File(path)))
      val barcodes: List<Barcode> = Tasks.await(scanner.process(image))
      durationsUs[index] = (System.nanoTime() - began) / 1_000
      if (barcodes.firstOrNull()?.rawValue == expectedPayload(index)) {
        decoded++
      }
      progress.set(index + 1)
    }
  } finally {
    scanner.close()
  }
  return DecodeRun(decoded, durationsUs, startedAt, System.currentTimeMillis())
}

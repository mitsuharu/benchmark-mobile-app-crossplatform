import { loadImage } from 'react-native-nitro-image'
import { createBarcodeScanner } from 'react-native-nitro-zxing'

import { expectedPayload } from './images'

export type DecodeRun = {
  /** How many images decoded to the payload they were generated with. */
  decoded: number
  /** How long each image took, in microseconds. */
  durationsUs: number[]
  startedAt: number
  finishedAt: number
}

/**
 * Decodes every image in order, one after the other.
 *
 * Nothing is logged in here: the timestamps are kept in memory and written out
 * once the loop is over, so the log does not land inside what is measured.
 */
export async function decodeAll(
  paths: string[],
  /**
   * How far the loop has got. Only a counter is written: the screen reads it
   * on its own timer so redrawing does not land between two decodes.
   */
  progress: { current: number },
): Promise<DecodeRun> {
  const scanner = createBarcodeScanner({ barcodeFormats: ['qr-code'] })
  const durationsUs = new Array<number>(paths.length)
  let decoded = 0

  const startedAt = Date.now()
  try {
    for (let index = 0; index < paths.length; index++) {
      const began = performance.now()
      const image = await loadImage({ filePath: paths[index] })
      const barcodes = await scanner.scanCodesInImageAsync(image)
      image.dispose()
      durationsUs[index] = Math.round((performance.now() - began) * 1000)
      if (barcodes[0]?.rawValue === expectedPayload(index)) {
        decoded++
      }
      progress.current = index + 1
    }
  } finally {
    scanner.dispose()
  }
  return { decoded, durationsUs, startedAt, finishedAt: Date.now() }
}

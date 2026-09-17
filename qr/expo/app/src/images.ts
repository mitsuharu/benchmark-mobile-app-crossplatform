/**
 * What the image at `index` encodes; see bench/scripts/make-qr-images.swift.
 * Checking it proves the decoder read the image the run thinks it did.
 */
export function expectedPayload(index: number): string {
  return `https://example.com/benchmark/qr/${String(index).padStart(3, '0')}`
}

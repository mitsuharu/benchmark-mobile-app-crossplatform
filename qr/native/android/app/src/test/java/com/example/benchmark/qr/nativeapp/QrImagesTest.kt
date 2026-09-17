package com.example.benchmark.qr.nativeapp

import org.junit.Assert.assertEquals
import org.junit.Test

class QrImagesTest {
  @Test
  fun `expected payload pads the index to three digits`() {
    assertEquals("https://example.com/benchmark/qr/000", expectedPayload(0))
    assertEquals("https://example.com/benchmark/qr/007", expectedPayload(7))
    assertEquals("https://example.com/benchmark/qr/499", expectedPayload(499))
  }
}

package com.example.benchmark.nativeapp

import org.junit.Assert.assertEquals
import org.junit.Test

class AppConfigTest {
  @Test
  fun `uses GitHub when the build sets no base url`() {
    assertEquals("https://api.github.com", AppConfig.apiBaseUrl(""))
  }

  @Test
  fun `uses the configured base url`() {
    assertEquals("http://127.0.0.1:8787", AppConfig.apiBaseUrl("http://127.0.0.1:8787"))
  }
}

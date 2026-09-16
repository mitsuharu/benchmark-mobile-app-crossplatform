package com.example.benchmark.nativeapp

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

/**
 * Covers the home screen's own state: what it does with the events the search
 * screen hands it, and how that screen is launched.
 */
@RunWith(RobolectricTestRunner::class)
class HomeViewModelTest {
  private val channel = AppChannel()
  private val viewModel = HomeViewModel(channel)
  private val repository = SearchedRepository(1, "expo/expo", 51842, "TypeScript")

  @Test
  fun `starts empty`() {
    assertNull(viewModel.lastKeyword)
    assertNull(viewModel.errorMessage)
    assertTrue(viewModel.repositories.isEmpty())
  }

  @Test
  fun `keeps results from a successful search`() {
    channel.post(RepoSearchEvent.Succeeded("expo", listOf(repository)))

    assertEquals("expo", viewModel.lastKeyword)
    assertEquals(listOf(repository), viewModel.repositories)
    assertNull(viewModel.errorMessage)
  }

  @Test
  fun `a failure clears previous results`() {
    channel.post(RepoSearchEvent.Succeeded("expo", listOf(repository)))

    channel.post(RepoSearchEvent.Failed("expo", "API rate limit exceeded"))

    assertEquals("API rate limit exceeded", viewModel.errorMessage)
    assertTrue(viewModel.repositories.isEmpty())
    assertEquals("expo", viewModel.lastKeyword)
  }

  @Test
  fun `a success clears a previous failure`() {
    channel.post(RepoSearchEvent.Failed("expo", "boom"))

    channel.post(RepoSearchEvent.Succeeded("expo", listOf(repository)))

    assertNull(viewModel.errorMessage)
    assertEquals(1, viewModel.repositories.size)
  }

  @Test
  fun `effective keyword falls back when blank`() {
    viewModel.keyword = "   "
    assertEquals("expo", viewModel.effectiveKeyword)

    viewModel.keyword = ""
    assertEquals("expo", viewModel.effectiveKeyword)
  }

  @Test
  fun `effective keyword is trimmed`() {
    viewModel.keyword = "  jetpack-compose \n"
    assertEquals("jetpack-compose", viewModel.effectiveKeyword)
  }

  @Test
  fun `the search screen is launched with the keyword`() {
    val context = ApplicationProvider.getApplicationContext<Context>()

    val intent = RepoSearchActivity.createIntent(context, "jetpack-compose")

    assertEquals(RepoSearchActivity::class.java.name, intent.component?.className)
    assertEquals("jetpack-compose", intent.getStringExtra(RepoSearchActivity.EXTRA_KEYWORD))
  }
}

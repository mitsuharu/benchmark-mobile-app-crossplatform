package com.example.benchmark.nativeapp

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel

/**
 * The home screen's state: the keyword being typed, and what the search screen
 * reported back.
 *
 * The listener lives in the ViewModel rather than in the composable so it stays
 * registered while `RepoSearchActivity` is in the foreground — that is when the
 * results actually arrive.
 */
class HomeViewModel(private val channel: AppChannel = AppChannel.shared) : ViewModel() {
  var keyword by mutableStateOf(DEFAULT_KEYWORD)

  var lastKeyword by mutableStateOf<String?>(null)
    private set

  var repositories by mutableStateOf<List<SearchedRepository>>(emptyList())
    private set

  var errorMessage by mutableStateOf<String?>(null)
    private set

  private var listenerId = channel.addEventListener(::receive)

  /** The keyword handed to the search screen when it is created. */
  val effectiveKeyword: String
    get() = keyword.trim().ifEmpty { DEFAULT_KEYWORD }

  fun receive(event: RepoSearchEvent) {
    when (event) {
      is RepoSearchEvent.Succeeded -> {
        BenchMarker.mark("resultsReceived")
        lastKeyword = event.keyword
        repositories = event.repositories
        errorMessage = null
      }
      is RepoSearchEvent.Failed -> {
        lastKeyword = event.keyword
        repositories = emptyList()
        errorMessage = event.message
      }
    }
  }

  override fun onCleared() {
    channel.removeEventListener(listenerId)
    super.onCleared()
  }

  companion object {
    const val DEFAULT_KEYWORD = "expo"
  }
}

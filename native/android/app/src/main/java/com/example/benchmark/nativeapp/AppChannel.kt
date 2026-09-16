package com.example.benchmark.nativeapp

import java.util.UUID

/** One repository as the search screen reports it to the home screen. */
data class SearchedRepository(
  val id: Long,
  val fullName: String,
  val stars: Int,
  val language: String?,
)

/** What the search screen reports back. */
sealed interface RepoSearchEvent {
  data class Succeeded(val keyword: String, val repositories: List<SearchedRepository>) :
    RepoSearchEvent

  data class Failed(val keyword: String, val message: String) : RepoSearchEvent
}

/**
 * What is asked of the search screen while it is open. The mirror image of
 * [RepoSearchEvent].
 */
sealed interface RepoSearchCommand {
  /**
   * Replaces the keyword on a screen that is already open. The keyword given
   * to [RepoSearchActivity] only reaches the screen while it is being created.
   */
  data class SetKeyword(val keyword: String) : RepoSearchCommand
}

/**
 * The message bus between the two screens.
 *
 * Every implementation carries the same two kinds of traffic — results out of
 * the search screen, commands into it — so the measurements line up. Here both
 * ends are Kotlin in one process, which is the baseline the other frameworks
 * are measured against.
 *
 * Main thread only, like the UI on both ends.
 */
class AppChannel {
  private val eventListeners = LinkedHashMap<UUID, (RepoSearchEvent) -> Unit>()
  private val commandListeners = LinkedHashMap<UUID, (RepoSearchCommand) -> Unit>()

  fun addEventListener(listener: (RepoSearchEvent) -> Unit): UUID =
    UUID.randomUUID().also { eventListeners[it] = listener }

  fun removeEventListener(id: UUID) {
    eventListeners.remove(id)
  }

  fun post(event: RepoSearchEvent) {
    eventListeners.values.toList().forEach { it(event) }
  }

  fun addCommandListener(listener: (RepoSearchCommand) -> Unit): UUID =
    UUID.randomUUID().also { commandListeners[it] = listener }

  fun removeCommandListener(id: UUID) {
    commandListeners.remove(id)
  }

  fun send(command: RepoSearchCommand) {
    commandListeners.values.toList().forEach { it(command) }
  }

  companion object {
    val shared = AppChannel()
  }
}

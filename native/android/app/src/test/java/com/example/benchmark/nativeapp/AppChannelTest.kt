package com.example.benchmark.nativeapp

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Covers the message bus between the two screens. */
class AppChannelTest {
  private val channel = AppChannel()
  private val repository = SearchedRepository(65750241, "expo/expo", 51842, "TypeScript")

  @Test
  fun `delivers events to every listener`() {
    val first = mutableListOf<RepoSearchEvent>()
    val second = mutableListOf<RepoSearchEvent>()
    channel.addEventListener { first += it }
    channel.addEventListener { second += it }

    channel.post(RepoSearchEvent.Succeeded("expo", listOf(repository)))

    assertEquals(listOf(RepoSearchEvent.Succeeded("expo", listOf(repository))), first)
    assertEquals(first, second)
  }

  @Test
  fun `delivers nothing after the listener is removed`() {
    val events = mutableListOf<RepoSearchEvent>()
    val id = channel.addEventListener { events += it }

    channel.removeEventListener(id)
    channel.post(RepoSearchEvent.Failed("expo", "boom"))

    assertTrue(events.isEmpty())
  }

  @Test
  fun `sends commands to the screen`() {
    val commands = mutableListOf<RepoSearchCommand>()
    channel.addCommandListener { commands += it }

    channel.send(RepoSearchCommand.SetKeyword("swift"))

    assertEquals(listOf(RepoSearchCommand.SetKeyword("swift")), commands)
  }

  @Test
  fun `sending with no screen open is harmless`() {
    channel.send(RepoSearchCommand.SetKeyword("swift"))
  }

  @Test
  fun `events and commands travel separately`() {
    val events = mutableListOf<RepoSearchEvent>()
    val commands = mutableListOf<RepoSearchCommand>()
    channel.addEventListener { events += it }
    channel.addCommandListener { commands += it }

    channel.send(RepoSearchCommand.SetKeyword("swift"))

    assertTrue(events.isEmpty())
    assertEquals(1, commands.size)
  }
}

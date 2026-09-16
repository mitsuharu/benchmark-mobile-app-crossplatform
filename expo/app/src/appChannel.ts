/**
 * The message bus between the two screens.
 *
 * Every implementation carries the same two kinds of traffic — results out of
 * the search screen, commands into it — so the measurements line up. Here both
 * ends are JavaScript, and nothing crosses into the native side.
 */
import type { Repository } from './api/github'

/** One repository as the search screen reports it to the home screen. */
export type SearchedRepository = {
  id: number
  fullName: string
  stars: number
  language: string | null
}

export const searchedRepositoryOf = (
  repository: Repository,
): SearchedRepository => ({
  id: repository.id,
  fullName: repository.fullName,
  stars: repository.stars,
  language: repository.language,
})

/** What the search screen reports back. */
export type RepoSearchEvent =
  | {
      type: 'searchSucceeded'
      keyword: string
      repositories: SearchedRepository[]
    }
  | { type: 'searchFailed'; keyword: string; message: string }

/**
 * What is asked of the search screen while it is open. The mirror image of
 * `RepoSearchEvent`. The keyword given to the screen as a route param only
 * reaches it while it is being created.
 */
export type RepoSearchCommand = { type: 'setKeyword'; keyword: string }

type Listener<T> = (payload: T) => void

export class AppChannel {
  private eventListeners = new Set<Listener<RepoSearchEvent>>()
  private commandListeners = new Set<Listener<RepoSearchCommand>>()

  /** Returns the function that removes the listener again. */
  onEvent(listener: Listener<RepoSearchEvent>) {
    this.eventListeners.add(listener)
    return () => {
      this.eventListeners.delete(listener)
    }
  }

  post(event: RepoSearchEvent) {
    for (const listener of [...this.eventListeners]) {
      listener(event)
    }
  }

  onCommand(listener: Listener<RepoSearchCommand>) {
    this.commandListeners.add(listener)
    return () => {
      this.commandListeners.delete(listener)
    }
  }

  send(command: RepoSearchCommand) {
    for (const listener of [...this.commandListeners]) {
      listener(command)
    }
  }
}

export const appChannel = new AppChannel()

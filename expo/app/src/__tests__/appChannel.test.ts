import type { Repository } from '../api/github'
import {
  AppChannel,
  type RepoSearchCommand,
  type RepoSearchEvent,
  searchedRepositoryOf,
} from '../appChannel'

const repository: Repository = {
  id: 65750241,
  fullName: 'expo/expo',
  description: 'An open-source framework',
  stars: 51842,
  language: 'TypeScript',
  htmlUrl: 'https://github.com/expo/expo',
}

describe('AppChannel', () => {
  let channel: AppChannel

  beforeEach(() => {
    channel = new AppChannel()
  })

  it('delivers events to every listener', () => {
    const first: RepoSearchEvent[] = []
    const second: RepoSearchEvent[] = []
    channel.onEvent((event) => first.push(event))
    channel.onEvent((event) => second.push(event))

    channel.post({
      type: 'searchSucceeded',
      keyword: 'expo',
      repositories: [searchedRepositoryOf(repository)],
    })

    expect(first).toEqual(second)
    expect(first).toHaveLength(1)
    expect(first[0]).toMatchObject({ type: 'searchSucceeded', keyword: 'expo' })
  })

  it('delivers nothing after the listener is removed', () => {
    const events: RepoSearchEvent[] = []
    const remove = channel.onEvent((event) => events.push(event))

    remove()
    channel.post({ type: 'searchFailed', keyword: 'expo', message: 'boom' })

    expect(events).toHaveLength(0)
  })

  it('sends commands to the screen', () => {
    const commands: RepoSearchCommand[] = []
    channel.onCommand((command) => commands.push(command))

    channel.send({ type: 'setKeyword', keyword: 'swift' })

    expect(commands).toEqual([{ type: 'setKeyword', keyword: 'swift' }])
  })

  it('sending with no screen open is harmless', () => {
    expect(() =>
      channel.send({ type: 'setKeyword', keyword: 'swift' }),
    ).not.toThrow()
  })

  it('events and commands travel separately', () => {
    const events: RepoSearchEvent[] = []
    const commands: RepoSearchCommand[] = []
    channel.onEvent((event) => events.push(event))
    channel.onCommand((command) => commands.push(command))

    channel.send({ type: 'setKeyword', keyword: 'swift' })

    expect(events).toHaveLength(0)
    expect(commands).toHaveLength(1)
  })
})

describe('searchedRepositoryOf', () => {
  it('keeps only the fields the home screen consumes', () => {
    expect(searchedRepositoryOf({ ...repository, language: null })).toEqual({
      id: 65750241,
      fullName: 'expo/expo',
      stars: 51842,
      language: null,
    })
  })
})

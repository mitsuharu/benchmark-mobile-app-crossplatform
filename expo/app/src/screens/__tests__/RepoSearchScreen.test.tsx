import { fireEvent, render, waitFor } from '@testing-library/react-native'
import {
  initialWindowMetrics,
  SafeAreaProvider,
} from 'react-native-safe-area-context'

import { markAfterFrame, markBench } from '../../../modules/bench-marker'
import { searchRepositories } from '../../api/github'
import { appChannel, type RepoSearchEvent } from '../../appChannel'
import { RepoSearchScreen } from '../RepoSearchScreen'

jest.mock('../../api/github', () => ({ searchRepositories: jest.fn() }))
jest.mock('../../../modules/bench-marker', () => ({
  markBench: jest.fn(),
  markAfterFrame: jest.fn(),
  markLaunchAfterFrame: jest.fn(),
}))

const searchMock = searchRepositories as jest.MockedFunction<
  typeof searchRepositories
>

const results = [
  {
    id: 65750241,
    fullName: 'expo/expo',
    description: 'An open-source framework',
    stars: 51842,
    language: 'TypeScript',
    htmlUrl: 'https://github.com/expo/expo',
  },
  {
    id: 1,
    fullName: 'a/b',
    description: null,
    stars: 0,
    language: null,
    htmlUrl: 'https://github.com/a/b',
  },
]

const goBack = jest.fn()

/** The screen reads the safe-area insets, which come from a provider. */
const wrapper = ({ children }: { children: React.ReactNode }) => (
  <SafeAreaProvider initialMetrics={initialWindowMetrics ?? METRICS}>
    {children}
  </SafeAreaProvider>
)

const METRICS = {
  frame: { x: 0, y: 0, width: 390, height: 844 },
  insets: { top: 47, left: 0, right: 0, bottom: 34 },
}

// Only the parts of the navigator's props this screen reads.
const screenProps = (keyword = 'expo') =>
  ({
    route: { params: { keyword } },
    navigation: { goBack },
    // biome-ignore lint/suspicious/noExplicitAny: a stub of the navigator's props
  }) as any

describe('RepoSearchScreen', () => {
  beforeEach(() => jest.clearAllMocks())

  it('shows the keyword handed over by the home screen', async () => {
    const { getByText } = await render(
      <RepoSearchScreen {...screenProps('swift')} />,
      { wrapper },
    )

    expect(getByText('keyword: swift')).toBeTruthy()
  })

  it('does not search until the button is pressed', async () => {
    const { getByText } = await render(
      <RepoSearchScreen {...screenProps()} />,
      { wrapper },
    )

    expect(searchMock).not.toHaveBeenCalled()
    expect(getByText('ボタンを押すと検索結果が表示されます。')).toBeTruthy()
  })

  it('lists the repositories returned for the keyword', async () => {
    searchMock.mockResolvedValue(results)
    const { getByText } = await render(
      <RepoSearchScreen {...screenProps()} />,
      { wrapper },
    )

    await fireEvent.press(getByText('リポジトリを検索'))

    await waitFor(() => expect(getByText('expo/expo')).toBeTruthy())
    expect(searchMock).toHaveBeenCalledWith('expo', 20, expect.any(String))
    expect(getByText('★ 51,842 · TypeScript')).toBeTruthy()
    expect(getByText('★ 0')).toBeTruthy()
  })

  it('reports the results back to the home screen', async () => {
    searchMock.mockResolvedValue(results)
    const events: RepoSearchEvent[] = []
    const remove = appChannel.onEvent((event) => events.push(event))
    const { getByText } = await render(
      <RepoSearchScreen {...screenProps()} />,
      { wrapper },
    )

    await fireEvent.press(getByText('リポジトリを検索'))
    await waitFor(() => expect(events).toHaveLength(1))
    remove()

    expect(events[0]).toEqual({
      type: 'searchSucceeded',
      keyword: 'expo',
      repositories: [
        {
          id: 65750241,
          fullName: 'expo/expo',
          stars: 51842,
          language: 'TypeScript',
        },
        { id: 1, fullName: 'a/b', stars: 0, language: null },
      ],
    })
  })

  it('shows the failure and reports it to the home screen', async () => {
    searchMock.mockRejectedValue(new Error('API rate limit exceeded'))
    const events: RepoSearchEvent[] = []
    const remove = appChannel.onEvent((event) => events.push(event))
    const { getByText } = await render(
      <RepoSearchScreen {...screenProps()} />,
      { wrapper },
    )

    await fireEvent.press(getByText('リポジトリを検索'))

    await waitFor(() =>
      expect(getByText('API rate limit exceeded')).toBeTruthy(),
    )
    remove()
    expect(events[0]).toEqual({
      type: 'searchFailed',
      keyword: 'expo',
      message: 'API rate limit exceeded',
    })
  })

  it('goes back to the home screen', async () => {
    const { getByText } = await render(
      <RepoSearchScreen {...screenProps()} />,
      { wrapper },
    )

    await fireEvent.press(getByText('ホームに戻る'))

    expect(goBack).toHaveBeenCalledTimes(1)
  })

  it('sends a keyword over the channel when a preset is pressed', async () => {
    const commands: string[] = []
    const remove = appChannel.onCommand((command) =>
      commands.push(command.keyword),
    )
    const { getByText } = await render(
      <RepoSearchScreen {...screenProps()} />,
      { wrapper },
    )

    await fireEvent.press(getByText('swift'))
    remove()

    expect(commands).toEqual(['swift'])
    expect(markBench).toHaveBeenCalledWith('commandSent')
  })

  it('follows a keyword sent while the screen is open', async () => {
    searchMock.mockResolvedValue(results)
    const { getByText } = await render(
      <RepoSearchScreen {...screenProps()} />,
      { wrapper },
    )

    await fireEvent.press(getByText('swift'))

    await waitFor(() => expect(getByText('keyword: swift')).toBeTruthy())
    await fireEvent.press(getByText('リポジトリを検索'))
    await waitFor(() =>
      expect(searchMock).toHaveBeenCalledWith('swift', 20, expect.any(String)),
    )
  })

  it('clears the previous results when the keyword is replaced', async () => {
    searchMock.mockResolvedValue(results)
    const { getByText, queryByText } = await render(
      <RepoSearchScreen {...screenProps()} />,
      { wrapper },
    )
    await fireEvent.press(getByText('リポジトリを検索'))
    await waitFor(() => expect(getByText('expo/expo')).toBeTruthy())

    await fireEvent.press(getByText('kotlin'))

    await waitFor(() => expect(queryByText('expo/expo')).toBeNull())
  })

  it('marks each step of the benchmark scenario', async () => {
    searchMock.mockResolvedValue(results)
    const { getByText } = await render(
      <RepoSearchScreen {...screenProps()} />,
      { wrapper },
    )
    expect(markAfterFrame).toHaveBeenCalledWith('searchFirstFrame')

    await fireEvent.press(getByText('リポジトリを検索'))
    await waitFor(() => expect(getByText('expo/expo')).toBeTruthy())

    expect(markBench).toHaveBeenCalledWith('searchTapped')
    expect(markAfterFrame).toHaveBeenCalledWith('searchRendered')
  })
})

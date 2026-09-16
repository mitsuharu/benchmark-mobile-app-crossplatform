import { act, fireEvent, render, waitFor } from '@testing-library/react-native'

import { markBench, markLaunchAfterFrame } from '../../../modules/bench-marker'
import { appChannel } from '../../appChannel'
import { HomeScreen } from '../HomeScreen'

jest.mock('../../../modules/bench-marker', () => ({
  markBench: jest.fn(),
  markAfterFrame: jest.fn(),
  markLaunchAfterFrame: jest.fn(),
}))

const navigate = jest.fn()

// Only the parts of the navigator's props this screen reads.
// biome-ignore lint/suspicious/noExplicitAny: a stub of the navigator's props
const screenProps = () => ({ navigation: { navigate } }) as any

const repository = {
  id: 65750241,
  fullName: 'expo/expo',
  stars: 51842,
  language: 'TypeScript',
}

describe('HomeScreen', () => {
  beforeEach(() => jest.clearAllMocks())

  it('starts with no results', async () => {
    const { getByText } = await render(<HomeScreen {...screenProps()} />)

    expect(getByText('まだ結果を受け取っていません')).toBeTruthy()
  })

  it('marks the launch after the first frame', async () => {
    await render(<HomeScreen {...screenProps()} />)

    expect(markLaunchAfterFrame).toHaveBeenCalledTimes(1)
  })

  it('shows what the search screen reports', async () => {
    const { getByText } = await render(<HomeScreen {...screenProps()} />)

    await act(async () => {
      appChannel.post({
        type: 'searchSucceeded',
        keyword: 'expo',
        repositories: [repository],
      })
    })

    await waitFor(() => expect(getByText('keyword: expo')).toBeTruthy())
    expect(getByText('件数: 1')).toBeTruthy()
    expect(getByText('expo/expo')).toBeTruthy()
    expect(markBench).toHaveBeenCalledWith('resultsReceived')
  })

  it('a failure clears previous results', async () => {
    const { getByText, queryByText } = await render(
      <HomeScreen {...screenProps()} />,
    )
    await act(async () => {
      appChannel.post({
        type: 'searchSucceeded',
        keyword: 'expo',
        repositories: [repository],
      })
    })
    await waitFor(() => expect(getByText('expo/expo')).toBeTruthy())

    await act(async () => {
      appChannel.post({
        type: 'searchFailed',
        keyword: 'expo',
        message: 'API rate limit exceeded',
      })
    })

    await waitFor(() =>
      expect(getByText('API rate limit exceeded')).toBeTruthy(),
    )
    expect(queryByText('expo/expo')).toBeNull()
  })

  it('opens the search screen with the typed keyword', async () => {
    const { getByTestId, getByText } = await render(
      <HomeScreen {...screenProps()} />,
    )

    await fireEvent.changeText(getByTestId('keywordField'), '  swift-format ')
    await fireEvent.press(getByText('検索画面を開く'))

    expect(markBench).toHaveBeenCalledWith('searchOpenTapped')
    expect(navigate).toHaveBeenCalledWith('RepoSearch', {
      keyword: 'swift-format',
    })
  })

  it('falls back to the default keyword when the field is blank', async () => {
    const { getByTestId, getByText } = await render(
      <HomeScreen {...screenProps()} />,
    )

    await fireEvent.changeText(getByTestId('keywordField'), '   ')
    await fireEvent.press(getByText('検索画面を開く'))

    expect(navigate).toHaveBeenCalledWith('RepoSearch', { keyword: 'expo' })
  })
})

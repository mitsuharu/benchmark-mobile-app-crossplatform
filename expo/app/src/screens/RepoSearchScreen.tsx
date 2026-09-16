import type { NativeStackScreenProps } from '@react-navigation/native-stack'
import { useCallback, useEffect, useRef, useState } from 'react'
import {
  ActivityIndicator,
  FlatList,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native'
// React Native's own SafeAreaView is deprecated; this is the one
// react-navigation already depends on.
import { SafeAreaView } from 'react-native-safe-area-context'
import { markAfterFrame, markBench } from '../../modules/bench-marker'

import { type Repository, searchRepositories } from '../api/github'
import { appChannel, searchedRepositoryOf } from '../appChannel'
import { ActionButton } from '../components/ActionButton'
import { RepositoryRow } from '../components/RepositoryRow'
import { API_BASE_URL, PRESET_KEYWORDS } from '../config'
import type { RootStackParamList } from '../navigation'

const PER_PAGE = 20

type Props = NativeStackScreenProps<RootStackParamList, 'RepoSearch'>

/**
 * The second screen: searches GitHub for the keyword the home screen handed
 * over and lists the repositories.
 */
export function RepoSearchScreen({ route, navigation }: Props) {
  // The route param only arrives while this screen is being created, so
  // replacing the keyword on an open screen comes over the channel.
  const [keyword, setKeyword] = useState(route.params.keyword)
  const [repositories, setRepositories] = useState<Repository[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(
    () =>
      appChannel.onCommand((command) => {
        if (command.type === 'setKeyword') {
          setKeyword(command.keyword)
          setRepositories([])
          setError(null)
        }
      }),
    [],
  )

  // Benchmark markers (see AGENTS.md). Effects run after React has committed
  // the change; markAfterFrame waits for it to be drawn.
  useEffect(() => markAfterFrame('searchFirstFrame'), [])
  useEffect(() => {
    if (repositories.length > 0) {
      markAfterFrame('searchRendered')
    }
  }, [repositories])
  const isInitialKeyword = useRef(true)
  // biome-ignore lint/correctness/useExhaustiveDependencies: runs whenever the keyword changes
  useEffect(() => {
    if (isInitialKeyword.current) {
      isInitialKeyword.current = false
      return
    }
    markAfterFrame('keywordApplied')
  }, [keyword])

  const onPressSearch = useCallback(async () => {
    markBench('searchTapped')
    setIsLoading(true)
    setError(null)
    try {
      const results = await searchRepositories(keyword, PER_PAGE, API_BASE_URL)
      setRepositories(results)
      // Hand the results back to the home screen.
      appChannel.post({
        type: 'searchSucceeded',
        keyword,
        repositories: results.map(searchedRepositoryOf),
      })
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e)
      setRepositories([])
      setError(message)
      appChannel.post({ type: 'searchFailed', keyword, message })
    } finally {
      setIsLoading(false)
    }
  }, [keyword])

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>GitHub Repositories</Text>
        <Text style={styles.subtitle}>keyword: {keyword}</Text>
      </View>

      {/* Replacing the keyword on the open screen goes over the channel, the
          same path the other implementations take. */}
      <View style={styles.presets}>
        {PRESET_KEYWORDS.map((preset) => (
          <Pressable
            accessibilityRole="button"
            key={preset}
            onPress={() => {
              markBench('commandSent')
              appChannel.send({ type: 'setKeyword', keyword: preset })
            }}
            style={styles.preset}
          >
            <Text style={styles.presetLabel}>{preset}</Text>
          </Pressable>
        ))}
      </View>

      <View style={styles.actions}>
        <ActionButton
          disabled={isLoading}
          label={isLoading ? '検索中...' : 'リポジトリを検索'}
          onPress={onPressSearch}
        />
        <ActionButton
          label="ホームに戻る"
          onPress={() => navigation.goBack()}
          variant="secondary"
        />
      </View>

      {error !== null && <Text style={styles.error}>{error}</Text>}

      {isLoading && repositories.length === 0 ? (
        <ActivityIndicator style={styles.loading} size="large" />
      ) : (
        <FlatList
          contentContainerStyle={styles.listContent}
          data={repositories}
          keyExtractor={(item) => String(item.id)}
          ListEmptyComponent={
            error === null ? (
              <Text style={styles.empty}>
                ボタンを押すと検索結果が表示されます。
              </Text>
            ) : null
          }
          renderItem={({ item }) => <RepositoryRow repository={item} />}
        />
      )}
    </SafeAreaView>
  )
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#fff',
    flex: 1,
  },
  header: {
    paddingHorizontal: 20,
    paddingTop: 24,
  },
  title: {
    fontSize: 24,
    fontWeight: '700',
  },
  subtitle: {
    color: '#6b7280',
    fontSize: 14,
    marginTop: 4,
  },
  presets: {
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: 20,
    paddingTop: 16,
  },
  preset: {
    borderColor: '#6750a4',
    borderRadius: 20,
    borderWidth: 1,
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  presetLabel: {
    color: '#6750a4',
    fontSize: 14,
  },
  actions: {
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: 20,
    paddingVertical: 16,
  },
  error: {
    color: '#b91c1c',
    paddingBottom: 8,
    paddingHorizontal: 20,
  },
  loading: {
    marginTop: 32,
  },
  listContent: {
    paddingBottom: 32,
    paddingHorizontal: 20,
  },
  empty: {
    color: '#9ca3af',
    marginTop: 32,
    textAlign: 'center',
  },
})

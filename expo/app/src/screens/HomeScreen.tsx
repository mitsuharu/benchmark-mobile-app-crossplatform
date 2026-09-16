import type { NativeStackScreenProps } from '@react-navigation/native-stack'
import { useCallback, useEffect, useState } from 'react'
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native'

import { markBench, markLaunchAfterFrame } from '../../modules/bench-marker'
import { appChannel, type SearchedRepository } from '../appChannel'
import { DEFAULT_KEYWORD } from '../config'
import type { RootStackParamList } from '../navigation'

type Props = NativeStackScreenProps<RootStackParamList, 'Home'>

/**
 * The first screen: the keyword is typed here and handed to the search screen,
 * and the results come back over the app channel.
 */
export function HomeScreen({ navigation }: Props) {
  const [keyword, setKeyword] = useState(DEFAULT_KEYWORD)
  const [lastKeyword, setLastKeyword] = useState<string | null>(null)
  const [repositories, setRepositories] = useState<SearchedRepository[]>([])
  const [error, setError] = useState<string | null>(null)

  useEffect(() => markLaunchAfterFrame(), [])

  useEffect(
    () =>
      appChannel.onEvent((event) => {
        if (event.type === 'searchSucceeded') {
          markBench('resultsReceived')
          setLastKeyword(event.keyword)
          setRepositories(event.repositories)
          setError(null)
        } else {
          setLastKeyword(event.keyword)
          setRepositories([])
          setError(event.message)
        }
      }),
    [],
  )

  const onPressOpen = useCallback(() => {
    markBench('searchOpenTapped')
    navigation.navigate('RepoSearch', {
      keyword: keyword.trim() || DEFAULT_KEYWORD,
    })
  }, [keyword, navigation])

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.label}>検索ワード</Text>
        <TextInput
          autoCapitalize="none"
          autoCorrect={false}
          onChangeText={setKeyword}
          placeholder="keyword"
          style={styles.input}
          testID="keywordField"
          value={keyword}
        />

        <Pressable
          accessibilityRole="button"
          onPress={onPressOpen}
          style={styles.open}
          testID="openSearch"
        >
          <Text style={styles.openLabel}>検索画面を開く</Text>
        </Pressable>

        <Text style={[styles.label, styles.resultsLabel]}>
          検索画面から受け取った結果
        </Text>
        {error !== null ? (
          <Text style={styles.error}>{error}</Text>
        ) : lastKeyword === null ? (
          <Text style={styles.placeholder}>まだ結果を受け取っていません</Text>
        ) : (
          <View>
            <Text>keyword: {lastKeyword}</Text>
            <Text>件数: {repositories.length}</Text>
            {repositories.slice(0, 3).map((repository) => (
              <View key={repository.id} style={styles.row}>
                <Text style={styles.rowTitle}>{repository.fullName}</Text>
                <Text>
                  ★ {repository.stars}
                  {repository.language !== null
                    ? ` · ${repository.language}`
                    : ''}
                </Text>
              </View>
            ))}
          </View>
        )}
      </ScrollView>
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#fff',
    flex: 1,
  },
  content: {
    padding: 16,
  },
  label: {
    fontWeight: '600',
  },
  resultsLabel: {
    marginTop: 32,
  },
  input: {
    borderColor: '#6750a4',
    borderRadius: 4,
    borderWidth: 1,
    fontSize: 16,
    marginTop: 8,
    paddingHorizontal: 12,
    paddingVertical: 14,
  },
  open: {
    alignItems: 'center',
    backgroundColor: '#6750a4',
    borderRadius: 20,
    marginTop: 16,
    paddingVertical: 12,
  },
  openLabel: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
  },
  error: {
    color: '#b91c1c',
    marginTop: 8,
  },
  placeholder: {
    color: '#6b7280',
    marginTop: 8,
  },
  row: {
    borderTopColor: '#e5e7eb',
    borderTopWidth: StyleSheet.hairlineWidth,
    marginTop: 8,
    paddingTop: 8,
  },
  rowTitle: {
    fontWeight: '600',
  },
})

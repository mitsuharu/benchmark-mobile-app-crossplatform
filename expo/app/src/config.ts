export const DEFAULT_API_BASE_URL = 'https://api.github.com'

/**
 * Where the search screen sends its requests. The benchmark build points this
 * at bench/mock-server through `EXPO_PUBLIC_BENCH_API_BASE_URL`, which Metro
 * inlines while bundling; every other build talks to GitHub.
 */
export const API_BASE_URL =
  process.env.EXPO_PUBLIC_BENCH_API_BASE_URL || DEFAULT_API_BASE_URL

export const DEFAULT_KEYWORD = 'expo'

/** Keywords that can be pushed into the search screen while it is open. */
export const PRESET_KEYWORDS = ['expo', 'swift', 'kotlin']

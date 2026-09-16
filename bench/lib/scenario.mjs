/**
 * One run of the benchmark scenario, driven through agent-device.
 *
 * The durations come from the markers the apps log (see markers.mjs), not
 * from how long these commands take, so agent-device's own overhead does not
 * leak into the numbers. What this measures directly is memory, sampled once
 * the UI has settled at each stage.
 */

/**
 * How each platform exposes the controls. The labels are shared by every
 * implementation (AGENTS.md); only the way agent-device reaches them differs.
 */
export const SELECTORS = {
  ios: {
    openSearch: 'id="openSearch"',
    search: 'label="リポジトリを検索"',
    back: 'label="ホームに戻る"',
    // The keyword buttons above the list. `keyword: swift` is drawn as static
    // text once it applies, so asking for the button keeps this unambiguous.
    sendCommand: 'role="button" label="swift"',
  },
  android: {
    openSearch: 'id="openSearch"',
    // The buttons look different on each framework: React Native exposes a
    // Pressable and the Text inside it as two actionable nodes with the same
    // text, while a Compose button is an unlabelled group around its Text.
    // Finding by text and taking the first match hits the button in both.
    search: { find: 'リポジトリを検索' },
    back: { find: 'ホームに戻る' },
    sendCommand: { find: 'swift' },
  },
}

/** Text that proves each stage has been reached. */
export const SEARCH_BUTTON_TEXT = 'リポジトリを検索'
export const FIRST_RESULT_TEXT = 'expo/expo'
export const COMMAND_APPLIED_TEXT = 'keyword: swift'

export const WAIT_MS = 30_000

/** How many times "back" is tapped before the run is given up on. */
const BACK_ATTEMPTS = 3
const BACK_WAIT_MS = 5_000

/** Taps a control given as a selector or as `{ find: text }` (see SELECTORS). */
export function tap(device, target) {
  return device.call(
    typeof target === 'string'
      ? ['press', target]
      : ['find', target.find, 'click', '--first'],
  )
}

/** The process memory reported by `perf memory sample`, in kB. */
export function memoryKb(data, platform) {
  const memory = data?.metrics?.memory
  if (!memory?.available) {
    return null
  }
  // iOS simulators only expose the resident size (from `ps`). On Android, PSS
  // is the figure the system itself uses to account an app's memory.
  return (
    (platform === 'ios' ? memory.residentMemoryKb : memory.totalPssKb) ?? null
  )
}

/**
 * Relaunches the app and walks through the scenario once:
 * launch → open the search screen → search → replace the keyword →
 * back to the home screen → open the search screen again → back.
 *
 * With `relaunch: false` the app is expected to have just been launched
 * already (see run.mjs), and is only brought to the front.
 */
export async function runScenario(
  device,
  { appId, platform, settleMs, relaunch = true },
) {
  const selectors = SELECTORS[platform]
  const memory = {}

  const settleAndSample = async (stage) => {
    await device.call(['wait', String(settleMs)])
    memory[stage] = memoryKb(
      await device.call(['perf', 'memory', 'sample']),
      platform,
    )
  }
  const openSearch = async () => {
    await device.call(['press', selectors.openSearch])
    await device.call(['wait', 'text', SEARCH_BUTTON_TEXT, String(WAIT_MS)])
  }
  // The second visit taps "back" as soon as the screen's text is there, which
  // can be while it is still animating in — a tap then lands on a moving
  // target and does nothing. Tap again rather than fail the whole run.
  const backToHome = async () => {
    for (let attempt = 0; ; attempt++) {
      await tap(device, selectors.back)
      const timeout = attempt < BACK_ATTEMPTS - 1 ? BACK_WAIT_MS : WAIT_MS
      try {
        await device.call(['wait', selectors.openSearch, String(timeout)])
        return
      } catch (error) {
        if (attempt >= BACK_ATTEMPTS - 1) {
          throw error
        }
      }
    }
  }

  const opened = await device.call(
    relaunch ? ['open', appId, '--relaunch'] : ['open', appId],
  )
  await device.call(['wait', selectors.openSearch, String(WAIT_MS)])
  await settleAndSample('homeIdle')

  await openSearch()
  await settleAndSample('searchOpened')

  await tap(device, selectors.search)
  await device.call(['wait', 'text', FIRST_RESULT_TEXT, String(WAIT_MS)])
  await settleAndSample('afterSearch')

  await tap(device, selectors.sendCommand)
  await device.call(['wait', 'text', COMMAND_APPLIED_TEXT, String(WAIT_MS)])

  await backToHome()
  await settleAndSample('backToHome')

  // The second visit shows what the framework's screen machinery costs once
  // it is warm.
  await openSearch()
  await backToHome()

  return {
    startupRoundtripMs: opened?.startup?.durationMs ?? null,
    memoryKb: memory,
  }
}

/**
 * What gets measured: every implementation on every platform, and where the
 * benchmark build of each ends up (see scripts/build.sh).
 */
import path from 'node:path'
import { fileURLToPath } from 'node:url'

export const FRAMEWORKS = ['native', 'flutter', 'expo']
export const PLATFORMS = ['ios', 'android']

const BENCH_ROOT = fileURLToPath(new URL('..', import.meta.url))

/** Bundle id (iOS) / application id (Android) of each app. */
const APP_IDS = {
  // `native` is a Java keyword, so it cannot be a package segment on Android;
  // both platforms use the same id for the sake of one name per app.
  native: 'com.example.benchmark.nativeapp',
  flutter: 'com.example.benchmark.flutterapp',
  expo: 'com.example.benchmark.expoapp',
}

export function appId(framework, platform) {
  const id = APP_IDS[framework]
  if (!id) {
    throw new Error(`Unknown framework "${framework}"`)
  }
  return typeof id === 'string' ? id : id[platform]
}

/** How the apps are built; see scripts/build.sh. */
export const BUILDS = ['release', 'debug']

/**
 * The installable build that scripts/build.sh produces. An iOS build for a
 * physical device is a separate, signed build for iphoneos; Android runs the
 * same APK on emulators and devices.
 */
export function artifactPath(
  framework,
  platform,
  build = 'release',
  physical = false,
) {
  const file = platform === 'ios' ? 'App.app' : `app-${build}.apk`
  const dir = platform === 'ios' && physical ? 'ios-device' : platform
  return path.join(BENCH_ROOT, 'artifacts', build, framework, dir, file)
}

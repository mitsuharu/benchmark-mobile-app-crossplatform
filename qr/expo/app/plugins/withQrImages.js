const { cp, mkdir, rm } = require('node:fs/promises')
const path = require('node:path')

const { withDangerousMod, withXcodeProject } = require('@expo/config-plugins')

/**
 * Puts the QR images into the native app's resources.
 *
 * `expo-asset` cannot: it rejects file names with a hyphen on Android, and it
 * files `.png` under `res/drawable`, where the app gets a drawable rather than
 * a file path. The benchmark decodes from file paths (see AGENTS.md), so the
 * images go somewhere the app can copy real files out of:
 *
 * - Android: `assets/qr`, read back through the AssetManager.
 * - iOS: copied into the bundle as a `qr` folder by a build phase.
 *
 * `BenchMarkerModule.prepareImages` then unpacks them into the app's own
 * storage. That is the benchmark's preparation step, which is not measured.
 */
const SOURCE = 'assets/qr'
const PHASE = 'Copy QR images'

const withQrImagesAndroid = (config) =>
  withDangerousMod(config, [
    'android',
    async (config) => {
      const from = path.join(config.modRequest.projectRoot, SOURCE)
      const to = path.join(
        config.modRequest.platformProjectRoot,
        'app',
        'src',
        'main',
        'assets',
        'qr',
      )
      await rm(to, { recursive: true, force: true })
      await mkdir(path.dirname(to), { recursive: true })
      await cp(from, to, { recursive: true })
      return config
    },
  ])

const withQrImagesIosFiles = (config) =>
  withDangerousMod(config, [
    'ios',
    async (config) => {
      const from = path.join(config.modRequest.projectRoot, SOURCE)
      const to = path.join(config.modRequest.platformProjectRoot, 'qr')
      await rm(to, { recursive: true, force: true })
      await cp(from, to, { recursive: true })
      return config
    },
  ])

/**
 * Copies the folder into the built app. One build phase rather than 500 file
 * references keeps the project readable.
 */
const withQrImagesIosPhase = (config) =>
  withXcodeProject(config, (config) => {
    const project = config.modResults
    const existing = Object.values(
      project.hash.project.objects.PBXShellScriptBuildPhase ?? {},
    ).some((phase) => phase?.name === `"${PHASE}"`)
    if (!existing) {
      project.addBuildPhase([], 'PBXShellScriptBuildPhase', PHASE, null, {
        shellPath: '/bin/sh',
        shellScript:
          'ditto "$SRCROOT/qr" ' +
          '"$BUILT_PRODUCTS_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/qr"',
      })
    }
    return config
  })

module.exports = (config) =>
  withQrImagesIosPhase(withQrImagesIosFiles(withQrImagesAndroid(config)))

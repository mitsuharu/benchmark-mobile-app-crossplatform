const { mkdir, writeFile } = require('node:fs/promises')
const path = require('node:path')

const {
  withAndroidManifest,
  withDangerousMod,
} = require('@expo/config-plugins')

/**
 * Lets the benchmark build reach bench/mock-server over plain http on the
 * device's own loopback, which Android has blocked by default since API 28.
 *
 * `expo-build-properties` can only turn cleartext on for every host. The
 * native and Flutter implementations allow it for the loopback alone, so this
 * writes the same network security config to keep the three comparable.
 */
const FILE = 'network_security_config.xml'

const CONFIG = `<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- Written by plugins/withCleartextLoopback.js. -->
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">10.0.2.2</domain>
        <domain includeSubdomains="false">127.0.0.1</domain>
        <domain includeSubdomains="false">localhost</domain>
    </domain-config>
</network-security-config>
`

const withNetworkSecurityConfigFile = (config) =>
  withDangerousMod(config, [
    'android',
    async (config) => {
      const dir = path.join(
        config.modRequest.platformProjectRoot,
        'app',
        'src',
        'main',
        'res',
        'xml',
      )
      await mkdir(dir, { recursive: true })
      await writeFile(path.join(dir, FILE), CONFIG)
      return config
    },
  ])

const withNetworkSecurityConfigAttribute = (config) =>
  withAndroidManifest(config, (config) => {
    const application = config.modResults.manifest.application?.[0]
    if (application) {
      application.$['android:networkSecurityConfig'] =
        '@xml/network_security_config'
    }
    return config
  })

module.exports = (config) =>
  withNetworkSecurityConfigAttribute(withNetworkSecurityConfigFile(config))

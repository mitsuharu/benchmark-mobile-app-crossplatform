// AGP 9 compiles Kotlin itself (built-in Kotlin), so the module applies no
// Kotlin Android plugin. Listing the Kotlin compiler plugin here pins the
// Kotlin version that built-in Kotlin uses.
plugins {
  id("com.android.application") version "9.4.0" apply false
  id("org.jetbrains.kotlin.plugin.compose") version "2.4.20" apply false
}

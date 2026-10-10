plugins {
    kotlin("jvm")
    id("org.jetbrains.kotlin.plugin.compose")
}
kotlin { jvmToolchain(21) }
dependencies {
    val cv = "1.5.12"
    api("org.jetbrains.compose.desktop:desktop-jvm-linux-x64:$cv")
    api("org.jetbrains.compose.material3:material3-desktop:$cv")
    api("org.jetbrains.compose.material:material-icons-extended-desktop:$cv")
    api("org.jetbrains.kotlinx:kotlinx-coroutines-swing:1.8.1")
}

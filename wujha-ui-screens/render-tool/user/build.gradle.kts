plugins {
    kotlin("jvm")
    id("org.jetbrains.kotlin.plugin.compose")
    application
}
kotlin { jvmToolchain(21) }
val appSrc = "${rootDir}/../src/wujha-final/wujha-user/app/src/main/java"
sourceSets.main {
    kotlin.srcDir(appSrc)
    kotlin.exclude(
        "**/MainActivity.kt",
        "**/navigation/**",
        "**/data/notify/Notifier.kt",
        "**/data/storage/ImageCodec.kt",
        "**/ui/auth/GoogleSignInLauncher.kt",
    )
    resources.srcDir("${rootDir}/../src/wujha-final/wujha-user/app/src/main/res")
}
dependencies { implementation(project(":stubs")) }
application { mainClass.set("render.MainKt"); applicationDefaultJvmArgs = listOf("-Djava.awt.headless=true", "-Xmx3g") }

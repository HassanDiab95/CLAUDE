pluginManagement {
    repositories { maven("https://maven-central.storage-download.googleapis.com/maven2/"); gradlePluginPortal(); maven("https://maven.google.com/") }
}
dependencyResolutionManagement {
    repositories { maven("https://maven-central.storage-download.googleapis.com/maven2/"); maven("https://maven.google.com/") }
}
rootProject.name = "wujha-render"
include(":stubs", ":user", ":admin")

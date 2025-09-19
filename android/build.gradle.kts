// android/build.gradle.kts  (project-level, Kotlin DSL)

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin (use the version your project uses)
        classpath("com.android.tools.build:gradle:8.4.2")

        // ✅ Google Services plugin needed for Firebase (google-services.json)
        classpath("com.google.gms:google-services:4.4.2")

        // NOTE: Do not place app/library dependencies here.
        // Put them in app/build.gradle.kts instead.
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep default Gradle output paths so Flutter can locate APK/AAB artifacts.
// (Do NOT override buildDir unless you really need to.)

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
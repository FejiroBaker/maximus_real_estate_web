buildscript {
    val kotlinVersion = "2.1.0"

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.9.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(File("../build"))

subprojects {
    project.layout.buildDirectory.set(
        File("${rootProject.layout.buildDirectory.get()}/${project.name}")
    )
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
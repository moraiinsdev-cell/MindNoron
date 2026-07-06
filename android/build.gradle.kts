allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some Flutter plugins (e.g. file_picker -> flutter_plugin_android_lifecycle)
// require compiling against Android API 36, but Flutter 3.44's bundled default
// compileSdk is 34 and it does not propagate the app's value to plugin modules.
// Force every Android subproject up to at least 36 so the AAR-metadata checks
// pass. Reflection keeps this agnostic to the AGP version.
fun Project.raiseCompileSdkToAtLeast36() {
    val android = extensions.findByName("android") ?: return
    runCatching {
        val getter = android.javaClass.methods
            .firstOrNull { it.name == "getCompileSdk" && it.parameterCount == 0 }
        val setter = android.javaClass.methods
            .firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
        val current = getter?.invoke(android) as? Int
        if (setter != null && (current == null || current < 36)) {
            setter.invoke(android, 36)
        }
    }
}

subprojects {
    // evaluationDependsOn(":app") above can leave some modules already evaluated
    // by the time this runs, so apply immediately in that case and defer only
    // when the module is still pending.
    if (state.executed) {
        raiseCompileSdkToAtLeast36()
    } else {
        afterEvaluate { raiseCompileSdkToAtLeast36() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

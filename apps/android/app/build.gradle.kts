import com.android.build.api.variant.FilterConfiguration
import java.util.Properties
import javax.inject.Inject

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

val repoRoot: File = rootDir.resolve("../..").canonicalFile
val minApi = 26
val abis = providers.gradleProperty("po0.abis").orNull?.split(',')?.map(String::trim)
    ?: listOf("arm64-v8a", "armeabi-v7a", "x86_64")
val baseVersionCode = 2026103010
// Flutter's split-APK offsets: each native APK must out-number the Flutter APK of the same ABI to upgrade it.
val abiVersionOffset = mapOf("armeabi-v7a" to 1000, "arm64-v8a" to 2000, "x86_64" to 4000)

val signing = Properties().apply {
    rootDir.resolve("signing.properties").takeIf(File::isFile)?.inputStream()?.use(::load)
}

abstract class NativeBuild : DefaultTask() {
    @get:Inject
    abstract val exec: ExecOperations

    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val sources: ConfigurableFileCollection

    @get:Input
    abstract val commands: ListProperty<String>

    @get:Internal
    abstract val workDir: Property<File>

    @get:Internal
    abstract val ndkDir: DirectoryProperty

    @get:OutputDirectory
    abstract val outputDir: DirectoryProperty

    @TaskAction
    fun run() {
        val out = outputDir.get().asFile.apply { deleteRecursively(); mkdirs() }
        commands.get().forEach { command ->
            exec.exec {
                workingDir = this@NativeBuild.workDir.get()
                ndkDir.orNull?.asFile?.let { environment("ANDROID_NDK_HOME", it.absolutePath) }
                commandLine("bash", "-c", command.replace("{out}", out.absolutePath))
            }
        }
    }
}

fun NativeBuild.useAgpNdk() {
    ndkDir.set(androidComponents.sdkComponents.ndkDirectory)
}

fun NativeBuild.rustSources() {
    sources.from(fileTree(repoRoot.resolve("crates")) { include("**/*.rs", "**/*.toml") })
    sources.from(repoRoot.resolve("Cargo.toml"), repoRoot.resolve("Cargo.lock"))
    workDir.set(repoRoot)
}

val mihomo = tasks.register<NativeBuild>("buildMihomo") {
    sources.from(fileTree(repoRoot.resolve("mihomo/android")) { include("*.go", "go.mod", "go.sum", "build.sh") })
    sources.from(fileTree(repoRoot.resolve("mihomo/upstream")) { include("**/*.go", "go.mod", "go.sum") })
    workDir.set(repoRoot)
    useAgpNdk()
    commands.set(abis.map { "bash mihomo/android/build.sh $it {out} $minApi" })
}

val ffi = tasks.register<NativeBuild>("buildPo0Ffi") {
    rustSources()
    useAgpNdk()
    val targets = abis.joinToString(" ") { "-t $it" }
    commands.set(listOf("cargo ndk -P $minApi $targets -o {out} build --release -p po0-ffi"))
}

// Release libraries are stripped of UniFFI's metadata, so the bindings come from an unstripped host build.
val bindings = tasks.register<NativeBuild>("generateUniffiKotlin") {
    rustSources()
    commands.set(
        listOf(
            "cargo build -q -p po0-ffi",
            "cargo run -q -p po0-ffi --features cli --bin uniffi-bindgen -- generate" +
                " --library target/debug/libpo0_ffi.so --language kotlin --no-format --out-dir {out}",
        ),
    )
}

android {
    namespace = "io.github.yuuukicreation.po0clash"
    compileSdk = 37
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "io.github.yuuukicreation.po0clash"
        minSdk = minApi
        targetSdk = 36
        versionCode = baseVersionCode
        versionName = "7.0.0-beta.2"
    }

    signingConfigs {
        create("release") {
            storeFile = file("keystore.jks")
            storePassword = signing.getProperty("storePassword")
            keyAlias = signing.getProperty("keyAlias")
            keyPassword = signing.getProperty("keyPassword")
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".dev"
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include(*abis.toTypedArray())
            isUniversalApk = false
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    androidResources {
        localeFilters += listOf("en", "zh-rCN", "ja", "ru")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    lint {
        checkReleaseBuilds = false
    }
}

androidComponents {
    onVariants { variant ->
        variant.outputs.forEach { output ->
            val abi = output.filters.firstOrNull { it.filterType == FilterConfiguration.FilterType.ABI }?.identifier
            output.versionCode.set(baseVersionCode + (abiVersionOffset[abi] ?: 0))
        }
        variant.sources.jniLibs?.addGeneratedSourceDirectory(mihomo, NativeBuild::outputDir)
        variant.sources.jniLibs?.addGeneratedSourceDirectory(ffi, NativeBuild::outputDir)
        variant.sources.kotlin?.addGeneratedSourceDirectory(bindings, NativeBuild::outputDir)
    }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    implementation(libs.haze)
    implementation(libs.androidsvg)
    implementation(libs.kotlinx.coroutines.android)
    implementation("${libs.jna.get()}@aar")
    testImplementation(libs.junit)
}

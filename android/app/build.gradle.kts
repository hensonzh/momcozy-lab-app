import java.net.URI
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.security.MessageDigest

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val motionPoseModelUrl =
    "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task"
val motionPoseModelSha256 =
    "59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a"
val motionPoseModelFileName = "pose_landmarker_lite.task"
val motionPoseModelOverride = providers.environmentVariable("MOMCOZY_POSE_MODEL_FILE")
val motionPoseModelCacheFile = gradle.gradleUserHomeDir.resolve(
    "caches/momcozy/motion-pose/$motionPoseModelSha256/$motionPoseModelFileName",
)
val motionPoseModelDirectory = layout.buildDirectory.dir("generated/motionPoseModels")
val prepareMotionPoseModel by tasks.registering {
    val outputFile = motionPoseModelDirectory.map {
        it.file(motionPoseModelFileName)
    }
    inputs.property("modelUrl", motionPoseModelUrl)
    inputs.property("modelSha256", motionPoseModelSha256)
    inputs.property("modelOverride", motionPoseModelOverride.orElse(""))
    outputs.file(outputFile)
    doLast {
        val target = outputFile.get().asFile
        target.parentFile.mkdirs()

        if (target.isFile && target.sha256() == motionPoseModelSha256) {
            return@doLast
        }

        val overridePath = motionPoseModelOverride.orNull
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
        val source = if (overridePath != null) {
            file(overridePath).also { localModel ->
                check(localModel.isFile) {
                    "MOMCOZY_POSE_MODEL_FILE does not point to a readable file: $overridePath"
                }
                check(localModel.sha256() == motionPoseModelSha256) {
                    "MOMCOZY_POSE_MODEL_FILE checksum mismatch"
                }
            }
        } else {
            val cachedModel = motionPoseModelCacheFile
            if (!cachedModel.isFile || cachedModel.sha256() != motionPoseModelSha256) {
                check(!gradle.startParameter.isOffline) {
                    "MediaPipe pose model is not cached. Provide MOMCOZY_POSE_MODEL_FILE " +
                        "or run one non-offline build to populate ${cachedModel.absolutePath}."
                }

                cachedModel.parentFile.mkdirs()
                val staged = Files.createTempFile(
                    cachedModel.parentFile.toPath(),
                    "${cachedModel.name}.",
                    ".download",
                ).toFile()
                try {
                    val connection = URI(motionPoseModelUrl).toURL().openConnection().apply {
                        connectTimeout = 30_000
                        readTimeout = 120_000
                    }
                    connection.getInputStream().use { input ->
                        staged.outputStream().use { output -> input.copyTo(output) }
                    }
                    check(staged.sha256() == motionPoseModelSha256) {
                        "MediaPipe pose model checksum mismatch"
                    }
                    Files.move(
                        staged.toPath(),
                        cachedModel.toPath(),
                        StandardCopyOption.REPLACE_EXISTING,
                    )
                } finally {
                    staged.delete()
                }
            }
            cachedModel
        }

        Files.copy(
            source.toPath(),
            target.toPath(),
            StandardCopyOption.REPLACE_EXISTING,
        )
        check(target.sha256() == motionPoseModelSha256) {
            "Prepared MediaPipe pose model checksum mismatch"
        }
    }
}

fun java.io.File.sha256(): String {
    val digest = MessageDigest.getInstance("SHA-256")
    inputStream().use { input ->
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            digest.update(buffer, 0, count)
        }
    }
    return digest.digest().joinToString("") { "%02x".format(it) }
}

val releaseStoreFilePath = System.getenv("MOMCOZY_FLUTTER_RELEASE_STORE_FILE")?.trim()
val releaseStorePassword = System.getenv("MOMCOZY_FLUTTER_RELEASE_STORE_PASSWORD")?.trim()
val releaseKeyAlias = System.getenv("MOMCOZY_FLUTTER_RELEASE_KEY_ALIAS")?.trim()
val releaseKeyPassword = System.getenv("MOMCOZY_FLUTTER_RELEASE_KEY_PASSWORD")?.trim()
val hasReleaseSigning =
    !releaseStoreFilePath.isNullOrEmpty() &&
        !releaseStorePassword.isNullOrEmpty() &&
        !releaseKeyAlias.isNullOrEmpty() &&
        !releaseKeyPassword.isNullOrEmpty()
val runsFlutterIntegrationTest = providers.gradleProperty("target").map { target ->
    target.replace('\\', '/').contains("/integration_test/")
}.orElse(false)

android {
    namespace = "com.momcozymai.momcozy_flutter_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Preserve the current application ID. Any future package migration
        // requires an explicit rollout and installed-data compatibility plan.
        applicationId = "com.momcozymai.app.flutterpoc"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("local") {
            dimension = "environment"
            applicationIdSuffix = ".local"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
        }
        create("play") {
            dimension = "environment"
            applicationId = "com.momcozy.mai"
        }
        create("production") {
            dimension = "environment"
        }
    }

    buildTypes {
        release {
            // Without CI signing env, release APKs are smoke artifacts only.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles("proguard-rules.pro")
            if (runsFlutterIntegrationTest.get()) {
                proguardFiles("proguard-integration-test-target-rules.pro")
            }
            testProguardFiles("proguard-android-test-rules.pro")
        }
    }

    testBuildType = "release"

    sourceSets.getByName("main").assets.srcDir(motionPoseModelDirectory.get().asFile)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

tasks.named("preBuild").configure {
    dependsOn(prepareMotionPoseModel)
}

dependencies {
    val cameraXVersion = "1.4.2"
    implementation("androidx.camera:camera-camera2:$cameraXVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraXVersion")
    implementation("androidx.camera:camera-view:$cameraXVersion")
    implementation("com.google.mediapipe:tasks-vision:0.10.29")
    androidTestImplementation(project(":integration_test"))
    if (runsFlutterIntegrationTest.get()) {
        add("releaseImplementation", project(":integration_test"))
    }
}

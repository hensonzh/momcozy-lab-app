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
val motionPoseModelDirectory = layout.buildDirectory.dir("generated/motionPoseModels")
val prepareMotionPoseModel by tasks.registering {
    val outputFile = motionPoseModelDirectory.map {
        it.file("pose_landmarker_lite.task")
    }
    inputs.property("modelUrl", motionPoseModelUrl)
    inputs.property("modelSha256", motionPoseModelSha256)
    outputs.file(outputFile)
    doLast {
        val target = outputFile.get().asFile
        target.parentFile.mkdirs()
        if (!target.exists() || target.sha256() != motionPoseModelSha256) {
            val staged = target.resolveSibling("${target.name}.download")
            URI(motionPoseModelUrl).toURL().openStream().use { input ->
                staged.outputStream().use { output -> input.copyTo(output) }
            }
            check(staged.sha256() == motionPoseModelSha256) {
                "MediaPipe pose model checksum mismatch"
            }
            Files.move(
                staged.toPath(),
                target.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
            )
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
        }
    }

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
}

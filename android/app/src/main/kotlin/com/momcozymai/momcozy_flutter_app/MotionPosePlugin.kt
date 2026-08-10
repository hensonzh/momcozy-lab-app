package com.momcozymai.momcozy_flutter_app

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.View
import androidx.camera.core.AspectRatio
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.pm.PackageInfoCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import java.io.ByteArrayOutputStream
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MotionPosePlugin(
    private val activity: Activity,
    flutterEngine: FlutterEngine,
) : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val methodChannel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        CONTROL_CHANNEL,
    )
    private val eventChannel = EventChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        EVENT_CHANNEL,
    )
    private var eventSink: EventChannel.EventSink? = null
    private var currentView: MotionPosePlatformView? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var startRequested = false

    init {
        methodChannel.setMethodCallHandler(::handleMethodCall)
        eventChannel.setStreamHandler(this)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            VIEW_TYPE,
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                    val useFrontCamera =
                        (args as? Map<*, *>)?.get("camera_facing")?.toString() != "back"
                    return MotionPosePlatformView(
                        context = context,
                        activity = activity,
                        useFrontCamera = useFrontCamera,
                        emit = ::emit,
                        emitError = ::emitError,
                        onDisposed = { disposed ->
                            if (currentView === disposed) currentView = null
                        },
                    ).also { view ->
                        currentView?.dispose()
                        currentView = view
                        if (startRequested && hasCameraPermission()) view.start()
                    }
                }
            },
        )
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> requestPermissions(result)
            "start" -> {
                if (!hasCameraPermission()) {
                    result.error("permission_denied", "Camera permission is required", null)
                    return
                }
                startRequested = true
                currentView?.start()
                result.success(null)
            }
            "stop" -> {
                startRequested = false
                currentView?.stop()
                result.success(null)
            }
            "captureKeyFrame" -> {
                val view = currentView
                if (!startRequested || view == null) {
                    result.error(
                        "key_frame_unavailable",
                        "Motion camera is not running",
                        null,
                    )
                    return
                }
                view.captureKeyFrame(call.arguments, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (hasCameraPermission()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_request_active", "A permission request is already active", null)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            CAMERA_PERMISSIONS,
            REQUEST_MOTION_PERMISSIONS,
        )
    }

    fun handlePermissionResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_MOTION_PERMISSIONS) return false
        pendingPermissionResult?.success(hasCameraPermission())
        pendingPermissionResult = null
        return true
    }

    fun dispose() {
        startRequested = false
        currentView?.dispose()
        currentView = null
        pendingPermissionResult?.error(
            "permission_request_cancelled",
            "Motion assessment permission request was cancelled",
            null,
        )
        pendingPermissionResult = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun emit(value: Map<String, Any>) {
        mainHandler.post { eventSink?.success(value) }
    }

    private fun emitError(code: String, message: String, cause: Throwable? = null) {
        val details = mapOf(
            "exception" to (cause?.javaClass?.name ?: "unknown"),
            "build" to currentVersionCode(),
            "abis" to Build.SUPPORTED_ABIS.toList(),
        )
        Log.e(TAG, "$code: $message", cause)
        mainHandler.post { eventSink?.error(code, message, details) }
    }

    private fun hasCameraPermission(): Boolean = CAMERA_PERMISSIONS.all { permission ->
        ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED
    }

    @Suppress("DEPRECATION")
    private fun currentVersionCode(): Long = runCatching {
        val packageInfo = activity.packageManager.getPackageInfo(activity.packageName, 0)
        PackageInfoCompat.getLongVersionCode(packageInfo)
    }.getOrDefault(-1L)

    companion object {
        const val CONTROL_CHANNEL = "com.momcozymai.motion_pose/control"
        const val EVENT_CHANNEL = "com.momcozymai.motion_pose/events"
        const val VIEW_TYPE = "com.momcozymai.motion_pose/preview"
        const val REQUEST_MOTION_PERMISSIONS = 44021
        private const val TAG = "MotionPosePlugin"
        private val CAMERA_PERMISSIONS = arrayOf(
            Manifest.permission.CAMERA,
        )
    }
}

private class MotionPosePlatformView(
    context: Context,
    private val activity: Activity,
    private val useFrontCamera: Boolean,
    private val emit: (Map<String, Any>) -> Unit,
    private val emitError: (String, String, Throwable?) -> Unit,
    private val onDisposed: (MotionPosePlatformView) -> Unit,
) : PlatformView {
    private val previewView = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }
    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var cameraProvider: ProcessCameraProvider? = null
    private var poseLandmarker: PoseLandmarker? = null
    @Volatile
    private var started = false

    @Volatile
    private var disposed = false
    private var lastSubmittedAtMs = 0L
    private val keyFrameLock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingKeyFrame: PendingKeyFrame? = null

    private val cameraSelector: CameraSelector
        get() = if (useFrontCamera) {
            CameraSelector.DEFAULT_FRONT_CAMERA
        } else {
            CameraSelector.DEFAULT_BACK_CAMERA
        }

    override fun getView(): View = previewView

    fun start() {
        if (disposed) return
        if (started) {
            if (poseLandmarker != null) emitModelReady()
            return
        }
        started = true
        val providerFuture = ProcessCameraProvider.getInstance(previewView.context)
        providerFuture.addListener(
            {
                if (!started || disposed) return@addListener
                try {
                    val provider = providerFuture.get()
                    cameraProvider = provider
                    bindPreview(provider)
                    initializePoseAnalysis(provider)
                } catch (error: Exception) {
                    started = false
                    emitError(
                        "camera_start_failed",
                        error.message ?: "Camera failed to start",
                        error,
                    )
                }
            },
            ContextCompat.getMainExecutor(previewView.context),
        )
    }

    private fun bindPreview(provider: ProcessCameraProvider) {
        provider.unbindAll()
        provider.bindToLifecycle(
            activity as LifecycleOwner,
            cameraSelector,
            previewUseCase(),
        )
    }

    private fun initializePoseAnalysis(provider: ProcessCameraProvider) {
        analysisExecutor.execute analysis@{
            val landmarker = try {
                createPoseLandmarker(previewView.context)
            } catch (error: RuntimeException) {
                if (started && !disposed) {
                    started = false
                    emitError(
                        "pose_model_initialization_failed",
                        error.message ?: "MediaPipe failed to initialize",
                        error,
                    )
                }
                return@analysis
            }
            ContextCompat.getMainExecutor(previewView.context).execute main@{
                if (!started || disposed) {
                    landmarker.close()
                    return@main
                }
                poseLandmarker = landmarker
                try {
                    bindCamera(provider)
                    emitModelReady()
                } catch (error: Exception) {
                    started = false
                    poseLandmarker?.close()
                    poseLandmarker = null
                    emitError(
                        "camera_start_failed",
                        error.message ?: "Camera analysis failed to start",
                        error,
                    )
                }
            }
        }
    }

    private fun previewUseCase(): Preview = Preview.Builder()
        .setTargetAspectRatio(AspectRatio.RATIO_16_9)
        .build()
        .also { preview ->
            preview.setSurfaceProvider(previewView.surfaceProvider)
        }

    private fun bindCamera(provider: ProcessCameraProvider) {
        val preview = previewUseCase()
        val analysis = ImageAnalysis.Builder()
            .setTargetAspectRatio(AspectRatio.RATIO_16_9)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()
            .also { useCase ->
                useCase.setAnalyzer(analysisExecutor, ::analyze)
            }
        provider.unbindAll()
        provider.bindToLifecycle(
            activity as LifecycleOwner,
            cameraSelector,
            preview,
            analysis,
        )
    }

    private fun analyze(imageProxy: ImageProxy) {
        val now = SystemClock.uptimeMillis()
        if (!started || disposed || now - lastSubmittedAtMs < FRAME_INTERVAL_MS) {
            imageProxy.close()
            return
        }
        lastSubmittedAtMs = now
        val rotationDegrees = imageProxy.imageInfo.rotationDegrees
        val bitmap: Bitmap
        try {
            bitmap = rgbaBitmap(imageProxy)
        } finally {
            imageProxy.close()
        }
        val matrix = Matrix().apply {
            postRotate(rotationDegrees.toFloat())
        }
        val rotated = Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmap.width,
            bitmap.height,
            matrix,
            true,
        )
        if (rotated !== bitmap) bitmap.recycle()
        fulfillPendingKeyFrame(rotated)
        val input = BitmapImageBuilder(rotated).build()
        val landmarker = poseLandmarker
        if (landmarker == null) {
            input.close()
            return
        }
        try {
            landmarker.detectAsync(input, now)
        } catch (error: RuntimeException) {
            input.close()
            if (started && !disposed) {
                emitError(
                    "pose_inference_failed",
                    error.message ?: "MediaPipe pose inference failed",
                    error,
                )
            }
        }
    }

    private fun rgbaBitmap(imageProxy: ImageProxy): Bitmap {
        val plane = imageProxy.planes[0]
        val pixelStride = plane.pixelStride.coerceAtLeast(4)
        val paddedWidth = (plane.rowStride / pixelStride).coerceAtLeast(imageProxy.width)
        val padded = Bitmap.createBitmap(
            paddedWidth,
            imageProxy.height,
            Bitmap.Config.ARGB_8888,
        )
        plane.buffer.rewind()
        padded.copyPixelsFromBuffer(plane.buffer)
        if (paddedWidth == imageProxy.width) return padded
        val cropped = Bitmap.createBitmap(
            padded,
            0,
            0,
            imageProxy.width,
            imageProxy.height,
        )
        padded.recycle()
        return cropped
    }

    private fun createPoseLandmarker(context: Context): PoseLandmarker {
        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setModelAssetPath("pose_landmarker_lite.task")
                    .build(),
            )
            .setRunningMode(RunningMode.LIVE_STREAM)
            .setNumPoses(2)
            .setMinPoseDetectionConfidence(0.45f)
            .setMinPosePresenceConfidence(0.45f)
            .setMinTrackingConfidence(0.5f)
            .setResultListener(::onPoseResult)
            .setErrorListener { error ->
                if (started && !disposed) {
                    emitError(
                        "pose_inference_failed",
                        error.message ?: "MediaPipe pose inference failed",
                        error,
                    )
                }
            }
            .build()
        return PoseLandmarker.createFromOptions(context, options)
    }

    private fun onPoseResult(result: PoseLandmarkerResult, input: com.google.mediapipe.framework.image.MPImage) {
        try {
            if (!started || disposed) return
            val poses = result.landmarks().map { landmarks ->
                val encoded = landmarks.map { landmark ->
                    mapOf(
                        "x" to displayX(landmark.x()).toDouble(),
                        "y" to landmark.y().toDouble(),
                        "z" to landmark.z().toDouble(),
                        "visibility" to landmark.visibility().orElse(0f).toDouble(),
                        "presence" to landmark.presence().orElse(0f).toDouble(),
                    )
                }
                val reliable = landmarks.filter { landmark ->
                    landmark.visibility().orElse(0f) >= 0.35f &&
                        landmark.presence().orElse(0f) >= 0.35f
                }
                val extentLandmarks = reliable.ifEmpty { landmarks }
                val minX = extentLandmarks.minOf { displayX(it.x()) }
                val maxX = extentLandmarks.maxOf { displayX(it.x()) }
                val minY = extentLandmarks.minOf { it.y() }
                val maxY = extentLandmarks.maxOf { it.y() }
                mapOf(
                    "center_x" to ((minX + maxX) / 2f).toDouble(),
                    "center_y" to ((minY + maxY) / 2f).toDouble(),
                    "body_scale" to maxOf(maxX - minX, maxY - minY).toDouble(),
                    "landmarks" to encoded,
                )
            }
            emit(
                mapOf(
                    "event" to "observation",
                    "timestamp_ms" to result.timestampMs(),
                    "inference_ms" to (SystemClock.uptimeMillis() - result.timestampMs()).coerceAtLeast(0),
                    "input_width" to input.width,
                    "input_height" to input.height,
                    "engine" to "mediapipe_pose_landmarker",
                    "poses" to poses,
                ),
            )
        } finally {
            input.close()
        }
    }

    private fun displayX(value: Float): Float = if (useFrontCamera) 1f - value else value

    fun captureKeyFrame(arguments: Any?, result: MethodChannel.Result) {
        if (!started || disposed) {
            result.error("key_frame_unavailable", "Motion camera is not running", null)
            return
        }
        val values = arguments as? Map<*, *>
        val options = KeyFrameOptions(
            maxWidth = ((values?.get("max_width") as? Number)?.toInt() ?: 448)
                .coerceIn(160, 720),
            jpegQuality = ((values?.get("jpeg_quality") as? Number)?.toInt() ?: 60)
                .coerceIn(30, 85),
            maxBytes = ((values?.get("max_bytes") as? Number)?.toInt() ?: 122_880)
                .coerceIn(16_384, 245_760),
        )
        val request = PendingKeyFrame(
            id = "frame-${SystemClock.elapsedRealtimeNanos()}",
            options = options,
            result = result,
        )
        synchronized(keyFrameLock) {
            if (pendingKeyFrame != null) {
                result.error(
                    "key_frame_request_active",
                    "A key frame request is already active",
                    null,
                )
                return
            }
            pendingKeyFrame = request
        }
        mainHandler.postDelayed(
            { failPendingKeyFrame(request.id, "key_frame_timeout", "No camera frame was available in time") },
            KEY_FRAME_TIMEOUT_MS,
        )
    }

    private fun fulfillPendingKeyFrame(source: Bitmap) {
        val request = synchronized(keyFrameLock) {
            pendingKeyFrame.also { pendingKeyFrame = null }
        } ?: return
        try {
            val displayed = if (useFrontCamera) {
                val mirror = Matrix().apply {
                    setScale(-1f, 1f)
                    postTranslate(source.width.toFloat(), 0f)
                }
                Bitmap.createBitmap(
                    source.width,
                    source.height,
                    Bitmap.Config.ARGB_8888,
                ).also { target ->
                    android.graphics.Canvas(target).drawBitmap(source, mirror, null)
                }
            } else {
                source
            }
            val encoded = try {
                encodeBoundedJpeg(displayed, request.options)
            } finally {
                if (displayed !== source) displayed.recycle()
            }
            mainHandler.post {
                request.result.success(
                    mapOf(
                        "id" to request.id,
                        "bytes" to encoded.bytes,
                        "mime_type" to "image/jpeg",
                        "captured_at_ms" to System.currentTimeMillis(),
                        "width" to encoded.width,
                        "height" to encoded.height,
                    ),
                )
            }
        } catch (error: Exception) {
            mainHandler.post {
                request.result.error(
                    "key_frame_encoding_failed",
                    error.message ?: "Key frame encoding failed",
                    null,
                )
            }
        }
    }

    private fun encodeBoundedJpeg(source: Bitmap, options: KeyFrameOptions): EncodedKeyFrame {
        var width = minOf(source.width, options.maxWidth)
        var height = (source.height.toDouble() * width / source.width)
            .toInt()
            .coerceAtLeast(1)
        var scaled = if (width == source.width) {
            source
        } else {
            Bitmap.createScaledBitmap(source, width, height, true)
        }
        try {
            var quality = options.jpegQuality
            repeat(8) {
                val output = ByteArrayOutputStream()
                scaled.compress(Bitmap.CompressFormat.JPEG, quality, output)
                val bytes = output.toByteArray()
                if (bytes.size <= options.maxBytes) {
                    return EncodedKeyFrame(bytes, scaled.width, scaled.height)
                }
                if (quality > 30) {
                    quality = (quality - 10).coerceAtLeast(30)
                } else {
                    width = (scaled.width * 0.82).toInt().coerceAtLeast(160)
                    height = (scaled.height.toDouble() * width / scaled.width)
                        .toInt()
                        .coerceAtLeast(1)
                    if (width == scaled.width) return@repeat
                    val smaller = Bitmap.createScaledBitmap(scaled, width, height, true)
                    if (scaled !== source) scaled.recycle()
                    scaled = smaller
                }
            }
            throw IllegalStateException("Key frame exceeds the configured byte limit")
        } finally {
            if (scaled !== source) scaled.recycle()
        }
    }

    private fun failPendingKeyFrame(id: String?, code: String, message: String) {
        val request = synchronized(keyFrameLock) {
            val current = pendingKeyFrame
            if (current == null || (id != null && current.id != id)) null
            else current.also { pendingKeyFrame = null }
        } ?: return
        mainHandler.post { request.result.error(code, message, null) }
    }

    private fun emitModelReady() {
        emit(
            mapOf(
                "event" to "model_ready",
                "engine" to "mediapipe_pose_landmarker",
            ),
        )
    }

    fun stop() {
        started = false
        failPendingKeyFrame(null, "key_frame_cancelled", "Motion camera stopped")
        cameraProvider?.unbindAll()
        cameraProvider = null
        poseLandmarker?.close()
        poseLandmarker = null
    }

    override fun dispose() {
        if (disposed) return
        stop()
        disposed = true
        analysisExecutor.shutdownNow()
        onDisposed(this)
    }

    companion object {
        private const val FRAME_INTERVAL_MS = 66L
        private const val KEY_FRAME_TIMEOUT_MS = 1_200L
    }

    private data class KeyFrameOptions(
        val maxWidth: Int,
        val jpegQuality: Int,
        val maxBytes: Int,
    )

    private data class PendingKeyFrame(
        val id: String,
        val options: KeyFrameOptions,
        val result: MethodChannel.Result,
    )

    private data class EncodedKeyFrame(
        val bytes: ByteArray,
        val width: Int,
        val height: Int,
    )
}

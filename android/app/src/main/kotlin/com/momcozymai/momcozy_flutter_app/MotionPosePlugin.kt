package com.momcozymai.momcozy_flutter_app

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
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
                    return MotionPosePlatformView(
                        context = context,
                        activity = activity,
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

    private fun emitError(code: String, message: String) {
        mainHandler.post { eventSink?.error(code, message, null) }
    }

    private fun hasCameraPermission(): Boolean = CAMERA_PERMISSIONS.all { permission ->
        ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED
    }

    companion object {
        const val CONTROL_CHANNEL = "com.momcozymai.motion_pose/control"
        const val EVENT_CHANNEL = "com.momcozymai.motion_pose/events"
        const val VIEW_TYPE = "com.momcozymai.motion_pose/preview"
        const val REQUEST_MOTION_PERMISSIONS = 44021
        private val CAMERA_PERMISSIONS = arrayOf(
            Manifest.permission.CAMERA,
        )
    }
}

private class MotionPosePlatformView(
    context: Context,
    private val activity: Activity,
    private val emit: (Map<String, Any>) -> Unit,
    private val emitError: (String, String) -> Unit,
    private val onDisposed: (MotionPosePlatformView) -> Unit,
) : PlatformView {
    private val previewView = PreviewView(context).apply {
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
        scaleType = PreviewView.ScaleType.FILL_CENTER
    }
    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var cameraProvider: ProcessCameraProvider? = null
    private var poseLandmarker: PoseLandmarker? = null
    private var started = false
    private var disposed = false
    private var lastSubmittedAtMs = 0L

    override fun getView(): View = previewView

    fun start() {
        if (started || disposed) return
        started = true
        try {
            poseLandmarker = createPoseLandmarker(previewView.context)
        } catch (error: RuntimeException) {
            started = false
            emitError("pose_model_initialization_failed", error.message ?: "MediaPipe failed to initialize")
            return
        }
        val providerFuture = ProcessCameraProvider.getInstance(previewView.context)
        providerFuture.addListener(
            {
                if (!started || disposed) return@addListener
                try {
                    val provider = providerFuture.get()
                    cameraProvider = provider
                    bindCamera(provider)
                } catch (error: Exception) {
                    emitError("camera_start_failed", error.message ?: "Camera failed to start")
                }
            },
            ContextCompat.getMainExecutor(previewView.context),
        )
    }

    private fun bindCamera(provider: ProcessCameraProvider) {
        val preview = Preview.Builder()
            .setTargetAspectRatio(AspectRatio.RATIO_16_9)
            .build()
            .also {
            it.setSurfaceProvider(previewView.surfaceProvider)
        }
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
            CameraSelector.DEFAULT_FRONT_CAMERA,
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
        val bitmap = Bitmap.createBitmap(
            imageProxy.width,
            imageProxy.height,
            Bitmap.Config.ARGB_8888,
        )
        try {
            val buffer = imageProxy.planes[0].buffer
            buffer.rewind()
            bitmap.copyPixelsFromBuffer(buffer)
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
        poseLandmarker?.detectAsync(BitmapImageBuilder(rotated).build(), now)
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
                emitError("pose_inference_failed", error.message ?: "MediaPipe pose inference failed")
            }
            .build()
        return PoseLandmarker.createFromOptions(context, options)
    }

    private fun onPoseResult(result: PoseLandmarkerResult, input: com.google.mediapipe.framework.image.MPImage) {
        if (!started || disposed) return
        val poses = result.landmarks().map { landmarks ->
            val encoded = landmarks.map { landmark ->
                mapOf(
                    "x" to (1f - landmark.x()).toDouble(),
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
            val minX = extentLandmarks.minOf { 1f - it.x() }
            val maxX = extentLandmarks.maxOf { 1f - it.x() }
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
                "timestamp_ms" to result.timestampMs(),
                "inference_ms" to (SystemClock.uptimeMillis() - result.timestampMs()).coerceAtLeast(0),
                "input_width" to input.width,
                "input_height" to input.height,
                "engine" to "mediapipe_pose_landmarker",
                "poses" to poses,
            ),
        )
    }

    fun stop() {
        if (!started) return
        started = false
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
    }
}

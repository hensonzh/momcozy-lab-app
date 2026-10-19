package com.momcozymai.momcozy_flutter_app

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/** Streams authenticated backend PCM; the native player never sees text or credentials. */
class ChatFirstPcmPlayer(messenger: BinaryMessenger) {
    private val main = Handler(Looper.getMainLooper())
    private val writer = Executors.newSingleThreadExecutor()
    private var track: AudioTrack? = null
    private var generation = 0
    private var frames = 0L

    init {
        MethodChannel(messenger, "momcozy/chat_first_pcm").setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                closeTrack()
                val minSize = AudioTrack.getMinBufferSize(24000, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
                if (minSize <= 0) {
                    result.error("audio_unavailable", "PCM output is unavailable", null)
                    return
                }
                try {
                    track = AudioTrack.Builder()
                        .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
                        .setAudioFormat(AudioFormat.Builder().setSampleRate(24000)
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                        .setBufferSizeInBytes(maxOf(minSize * 4, 24000))
                        .setTransferMode(AudioTrack.MODE_STREAM)
                        .build()
                    if (track?.state != AudioTrack.STATE_INITIALIZED) throw IllegalStateException("AudioTrack init")
                    track?.play()
                    result.success(null)
                } catch (_: Exception) {
                    closeTrack()
                    result.error("audio_unavailable", "PCM output is unavailable", null)
                }
            }
            "write" -> {
                val data = call.arguments as? ByteArray
                val active = track
                if (data == null || data.size % 2 != 0 || active == null) {
                    result.error("invalid_pcm", "PCM frame is invalid", null)
                    return
                }
                val run = generation
                writer.execute {
                    var offset = 0
                    val deadline = System.currentTimeMillis() + 15_000
                    while (offset < data.size && run == generation && System.currentTimeMillis() < deadline) {
                        val count = active.write(data, offset, data.size - offset, AudioTrack.WRITE_NON_BLOCKING)
                        if (count < 0) break
                        if (count == 0) {
                            try { Thread.sleep(10) } catch (_: InterruptedException) { break }
                        } else offset += count
                    }
                    main.post {
                        if (run == generation && offset == data.size) {
                            frames += data.size / 2
                            result.success(null)
                        } else result.error("audio_stopped", "PCM playback stopped", null)
                    }
                }
            }
            "finish" -> {
                val active = track
                if (active == null) { result.success(null); return }
                val run = generation
                val target = frames
                writer.execute {
                    // Emulators and some output routes do not advance playbackHeadPosition
                    // reliably after a short final buffer. Bound the drain by PCM duration.
                    val remainingFrames = (target - active.playbackHeadPosition.toLong()).coerceAtLeast(0)
                    val drainMillis = (remainingFrames * 1000 / 24000 + 120).coerceAtMost(30_000)
                    try { Thread.sleep(drainMillis) } catch (_: InterruptedException) { /* Stopped. */ }
                    main.post { result.success(null) }
                }
            }
            "stop" -> { closeTrack(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    private fun closeTrack() {
        generation++
        frames = 0
        val old = track
        track = null
        if (old != null) {
            try { old.pause(); old.flush(); old.release() } catch (_: Exception) { /* Already closed. */ }
        }
    }
}

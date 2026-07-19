package com.momcozymai.momcozy_flutter_app

import android.os.SystemClock
import android.util.Log

internal class PumpAgentBackgroundRunner(
    private val uploadHandler: PumpAgentUploadChannelHandler,
    private val listener: Listener
) {
    fun interface Listener {
        fun onProgress(state: String, processAll: Int, elapsedSeconds: Int)
    }

    private val lock = Object()
    private var running = false
    private var progressWorker: Thread? = null
    private var networkWorker: Thread? = null
    private var state = "running"
    private var baseElapsedSeconds = 0
    private var elapsedBaseMs = 0L

    fun startOrUpdate(nextState: String, nextElapsedSeconds: Int) {
        val workersToStart = synchronized(lock) {
            val now = SystemClock.elapsedRealtime()
            val carriedElapsed = if (running) currentElapsedLocked(now) else 0
            state = safeState(nextState)
            baseElapsedSeconds = maxOf(nextElapsedSeconds.coerceAtLeast(0), carriedElapsed)
            elapsedBaseMs = now
            if (running) {
                emptyList()
            } else {
                running = true
                progressWorker = Thread(::runProgressLoop, "PumpAgentProgressRunner")
                networkWorker = Thread(::runNetworkLoop, "PumpAgentNetworkRunner")
                listOfNotNull(progressWorker, networkWorker)
            }
        }
        workersToStart.forEach { it.start() }
    }

    fun stop() {
        val workersToStop = synchronized(lock) {
            running = false
            val current = listOfNotNull(progressWorker, networkWorker)
            progressWorker = null
            networkWorker = null
            current
        }
        workersToStop.forEach { it.interrupt() }
    }

    private fun runProgressLoop() {
        while (isRunning()) {
            try {
                val snapshot = progressSnapshot()
                val progress = uploadHandler.sampleFromSnapshotForRunner(snapshot.elapsedSeconds)
                val processAll = progress["processAll"] ?: 0
                listener.onProgress(snapshot.state, processAll, snapshot.elapsedSeconds)
            } catch (error: Exception) {
                Log.w(TAG, "pump agent progress tick failed", error)
            }
            sleepTick()
        }
    }

    private fun runNetworkLoop() {
        while (isRunning()) {
            try {
                val snapshot = progressSnapshot()
                val progress = uploadHandler.runBackgroundNetworkTick()
                listener.onProgress(
                    snapshot.state,
                    progress["processAll"] ?: 0,
                    maxOf(progress["elapsedSeconds"] ?: 0, snapshot.elapsedSeconds)
                )
            } catch (error: Exception) {
                Log.w(TAG, "pump agent network tick failed", error)
            }
            sleepTick()
        }
    }

    private fun progressSnapshot(): RunnerProgressSnapshot {
        return synchronized(lock) {
            val now = SystemClock.elapsedRealtime()
            RunnerProgressSnapshot(
                state = state,
                elapsedSeconds = currentElapsedLocked(now)
            )
        }
    }

    private fun currentElapsedLocked(now: Long): Int {
        if (state != "running") return baseElapsedSeconds
        val deltaSeconds = ((now - elapsedBaseMs).coerceAtLeast(0L) / 1000L).toInt()
        return (baseElapsedSeconds + deltaSeconds).coerceAtLeast(0)
    }

    private fun isRunning(): Boolean {
        return synchronized(lock) { running }
    }

    private fun sleepTick() {
        try {
            Thread.sleep(PROGRESS_TICK_MS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
    }

    private fun safeState(value: String): String {
        return if (value == "paused") "paused" else "running"
    }

    private data class RunnerProgressSnapshot(
        val state: String,
        val elapsedSeconds: Int
    )

    private companion object {
        private const val TAG = "PumpAgentBgRunner"
        private const val PROGRESS_TICK_MS = 1_000L
    }
}

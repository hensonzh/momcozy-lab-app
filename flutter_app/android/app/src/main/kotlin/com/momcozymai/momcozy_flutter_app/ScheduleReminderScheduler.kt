package com.momcozymai.momcozy_flutter_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

internal data class ScheduleReminderSpec(
    val taskId: String,
    val date: String,
    val triggerAtMillis: Long,
)

internal object ScheduleReminderScheduler {
    private const val PREFS_NAME = "momcozy_schedule_reminders"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_OWNER_SCOPE = "owner_scope"
    private const val KEY_REMINDERS = "reminders_v1"
    private const val BASE_REQUEST_CODE = 63000
    private const val MAX_REMINDERS = 64
    private const val MIN_LEAD_MILLIS = 5000L

    fun setEnabled(
        context: Context,
        ownerScope: String,
        enabled: Boolean,
        reminders: List<ScheduleReminderSpec>,
    ): Int {
        cancelScheduled(context)
        val prefs = prefs(context)
        if (!enabled || ownerScope.isBlank()) {
            prefs.edit()
                .putBoolean(KEY_ENABLED, false)
                .remove(KEY_OWNER_SCOPE)
                .remove(KEY_REMINDERS)
                .apply()
            return 0
        }

        val now = System.currentTimeMillis()
        val normalized = reminders
            .asSequence()
            .filter { it.taskId.isNotBlank() && it.date.matches(DATE_PATTERN) }
            .filter { it.triggerAtMillis > now + MIN_LEAD_MILLIS }
            .distinctBy { "${it.taskId}:${it.triggerAtMillis}" }
            .sortedBy { it.triggerAtMillis }
            .take(MAX_REMINDERS)
            .toList()
        val persisted = JSONArray()
        for ((index, reminder) in normalized.withIndex()) {
            val requestCode = BASE_REQUEST_CODE + index
            schedule(context, requestCode, reminder)
            persisted.put(
                JSONObject()
                    .put("request_code", requestCode)
                    .put("task_id", reminder.taskId)
                    .put("date", reminder.date)
                    .put("trigger_at_millis", reminder.triggerAtMillis)
            )
        }
        prefs.edit()
            .putBoolean(KEY_ENABLED, true)
            .putString(KEY_OWNER_SCOPE, ownerScope.take(200))
            .putString(KEY_REMINDERS, persisted.toString())
            .apply()
        return normalized.size
    }

    fun isEnabled(context: Context): Boolean = prefs(context).getBoolean(KEY_ENABLED, false)

    fun reschedulePersisted(context: Context) {
        if (!isEnabled(context)) return
        val existing = readPersisted(context)
        val ownerScope = prefs(context).getString(KEY_OWNER_SCOPE, "").orEmpty()
        setEnabled(
            context = context,
            ownerScope = ownerScope,
            enabled = ownerScope.isNotBlank(),
            reminders = existing.map { it.second },
        )
    }

    fun consumeTriggered(context: Context, requestCode: Int): ScheduleReminderSpec? {
        if (!isEnabled(context)) return null
        val existing = readPersisted(context)
        val match = existing.firstOrNull { it.first == requestCode } ?: return null
        val remaining = JSONArray()
        for ((code, reminder) in existing) {
            if (code == requestCode) continue
            remaining.put(
                JSONObject()
                    .put("request_code", code)
                    .put("task_id", reminder.taskId)
                    .put("date", reminder.date)
                    .put("trigger_at_millis", reminder.triggerAtMillis)
            )
        }
        prefs(context).edit().putString(KEY_REMINDERS, remaining.toString()).apply()
        return match.second
    }

    private fun cancelScheduled(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        for ((requestCode, _) in readPersisted(context)) {
            val pendingIntent = alarmPendingIntent(context, requestCode, null)
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
    }

    private fun schedule(context: Context, requestCode: Int, reminder: ScheduleReminderSpec) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val operation = alarmPendingIntent(context, requestCode, reminder)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                reminder.triggerAtMillis,
                operation,
            )
        } else {
            @Suppress("DEPRECATION")
            alarmManager.set(AlarmManager.RTC_WAKEUP, reminder.triggerAtMillis, operation)
        }
    }

    private fun alarmPendingIntent(
        context: Context,
        requestCode: Int,
        reminder: ScheduleReminderSpec?,
    ): PendingIntent {
        val intent = Intent(context, ScheduleReminderReceiver::class.java)
            .setPackage(context.packageName)
            .putExtra(ScheduleReminderReceiver.EXTRA_REQUEST_CODE, requestCode)
        if (reminder != null) {
            intent.putExtra(ScheduleReminderReceiver.EXTRA_TASK_ID, reminder.taskId)
            intent.putExtra(ScheduleReminderReceiver.EXTRA_DATE, reminder.date)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutablePendingIntentFlag(),
        )
    }

    private fun readPersisted(context: Context): List<Pair<Int, ScheduleReminderSpec>> {
        val raw = prefs(context).getString(KEY_REMINDERS, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    val item = array.optJSONObject(index) ?: continue
                    val requestCode = item.optInt("request_code", -1)
                    val taskId = item.optString("task_id", "").trim()
                    val date = item.optString("date", "").trim()
                    val triggerAtMillis = item.optLong("trigger_at_millis", 0L)
                    if (
                        requestCode < 0 ||
                        taskId.isBlank() ||
                        !date.matches(DATE_PATTERN) ||
                        triggerAtMillis <= 0L
                    ) {
                        continue
                    }
                    add(
                        requestCode to ScheduleReminderSpec(
                            taskId = taskId,
                            date = date,
                            triggerAtMillis = triggerAtMillis,
                        )
                    )
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    private fun prefs(context: Context) = context.applicationContext.getSharedPreferences(
        PREFS_NAME,
        Context.MODE_PRIVATE,
    )

    private val DATE_PATTERN = Regex("^\\d{4}-\\d{2}-\\d{2}$")
}

private fun immutablePendingIntentFlag(): Int {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        PendingIntent.FLAG_IMMUTABLE
    } else {
        0
    }
}

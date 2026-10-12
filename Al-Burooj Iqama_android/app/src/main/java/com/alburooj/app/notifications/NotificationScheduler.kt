package com.alburooj.app.notifications

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.content.ContextCompat
import com.alburooj.app.constants.AppConstants
import com.alburooj.app.data.AppPrefs
import com.alburooj.app.data.models.AdhanSoundOption
import com.alburooj.app.data.models.AdhanSoundPreference
import com.alburooj.app.data.models.AnnualTime
import com.alburooj.app.services.AdhanTimesService
import com.alburooj.app.services.IqamaTimesService
import kotlinx.serialization.json.Json
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Mapped from NotificationScheduler.swift. iOS used repeating calendar triggers; Android has none, so each
 * alarm is one-shot for the next occurrence and [NotificationReceiver] calls [sync] again after firing.
 */
class NotificationScheduler(private val context: Context) {

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val prayers = listOf(AppConstants.Fajr, AppConstants.Dhuhar, AppConstants.Asar, AppConstants.Maghrib, AppConstants.Isha)
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }

    /** Rebuilds alarms based on current settings. */
    suspend fun syncNotifications() {
        if (!AppPrefs.getBoolean(AppConstants.NOTIFICATION_ENABLED) || !hasNotificationPermission()) {
            cancelAll(); return
        }
        if (AppPrefs.getBoolean(AppConstants.NOTIFY_ADHAN)) scheduleAdhan() else cancel("adhan")
        if (AppPrefs.getBoolean(AppConstants.NOTIFY_IQAMA)) scheduleIqama() else cancel("iqama")
    }

    private fun hasNotificationPermission() =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    // region Adhan

    private fun scheduleAdhan() {
        cancel("adhan")
        val lat = AppPrefs.getDouble(AppConstants.LATT)
        val lon = AppPrefs.getDouble(AppConstants.LONG)
        if (lat == 0.0 || lon == 0.0) return

        val method = AppPrefs.getString(AppConstants.CALC_METH, "ISNA")
        val school = AppPrefs.getInt(AppConstants.JURISDICTION)
        val service = AdhanTimesService()
        val today = service.calcAdhanTimes(0, lat, lon, school, method)
        val tomorrow = service.calcAdhanTimes(1, lat, lon, school, method)
        val city = AppPrefs.getString(AppConstants.CITY)

        val sound = AdhanSoundOption.fromRaw(AppPrefs.getString(AdhanSoundPreference.STORAGE_KEY, AdhanSoundOption.SystemDefault.raw))
        val todayList = listOf(today.fajr, today.dhuhar, today.asar, today.maghrib, today.isha)
        val tomorrowList = listOf(tomorrow.fajr, tomorrow.dhuhar, tomorrow.asar, tomorrow.maghrib, tomorrow.isha)

        prayers.forEachIndexed { i, name ->
            val next = nextFuture(todayList[i], tomorrowList[i]) ?: return@forEachIndexed
            schedule("adhan", i, name, "Adhan", city, next, sound)
        }
    }

    // endregion

    // region Iqama

    private suspend fun scheduleIqama() {
        cancel("iqama")
        runCatching { IqamaTimesService().fetchIqamaTimes() } // refresh if stale; fall back to cache
        val records = AppPrefs.getString(AppConstants.ANNUAL_TIMES).takeIf { it.isNotEmpty() }
            ?.let { runCatching { json.decodeFromString<List<AnnualTime>>(it) }.getOrNull() } ?: return

        val todayCal = Calendar.getInstance()
        val tomorrowCal = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
        val today = iqamaTimes(records, todayCal)
        val tomorrow = iqamaTimes(records, tomorrowCal)

        // Maghrib Iqama is intentionally left out of notifications (index 3).
        prayers.forEachIndexed { i, name ->
            if (name == AppConstants.Maghrib) return@forEachIndexed
            val next = nextFuture(today?.get(i), tomorrow?.get(i)) ?: return@forEachIndexed
            schedule("iqama", i, name, "Iqama", null, next, null)
        }
    }

    /** [fajr, dhuhar, asar, maghrib(null), isha] for the day, or null if no row covers it. */
    private fun iqamaTimes(records: List<AnnualTime>, day: Calendar): List<Date?>? {
        val month = day.get(Calendar.MONTH) + 1
        val dom = day.get(Calendar.DAY_OF_MONTH)
        val row = records.firstOrNull { it.month == month && (it.fromDay ?: 0) <= dom && (it.toDay ?: 0) >= dom } ?: return null
        return listOf(parse(row.fajrTime, day), parse(row.dhuharTime, day), parse(row.asrTime, day), null, parse(row.ishaTime, day))
    }

    private fun parse(raw: String?, day: Calendar): Date? {
        if (raw.isNullOrBlank()) return null
        val t = listOf(AppConstants.FromFormatIqama, AppConstants.FromFormatAdhan).firstNotNullOfOrNull {
            runCatching { SimpleDateFormat(it, Locale.US).parse(raw.trim()) }.getOrNull()
        } ?: return null
        val tc = Calendar.getInstance().apply { time = t }
        return Calendar.getInstance().apply {
            time = day.time
            set(Calendar.HOUR_OF_DAY, tc.get(Calendar.HOUR_OF_DAY)); set(Calendar.MINUTE, tc.get(Calendar.MINUTE))
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.time
    }

    // endregion

    private fun nextFuture(today: Date?, tomorrow: Date?): Date? {
        val now = Date()
        return when {
            today != null && today.after(now) -> today
            tomorrow != null && tomorrow.after(now) -> tomorrow
            else -> null
        }
    }

    private fun requestCode(prefix: String, index: Int) = (if (prefix == "adhan") 100 else 200) + index

    private fun pendingIntent(prefix: String, index: Int, extras: Intent? = null, flags: Int = 0): PendingIntent? {
        val intent = (extras ?: Intent()).setClass(context, NotificationReceiver::class.java)
        return PendingIntent.getBroadcast(context, requestCode(prefix, index), intent, flags or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun schedule(prefix: String, index: Int, prayer: String, title: String, subtitle: String?, at: Date, sound: AdhanSoundOption?) {
        val extras = Intent().apply {
            putExtra(NotificationReceiver.EXTRA_ID, requestCode(prefix, index))
            putExtra(NotificationReceiver.EXTRA_TITLE, title)
            putExtra(NotificationReceiver.EXTRA_SUBTITLE, subtitle.orEmpty())
            putExtra(NotificationReceiver.EXTRA_BODY, "$title time for $prayer prayer.")
            putExtra(NotificationReceiver.EXTRA_CHANNEL, ensureChannel(sound))
        }
        val pi = pendingIntent(prefix, index, extras, PendingIntent.FLAG_UPDATE_CURRENT)!!
        if (Build.VERSION.SDK_INT < 31 || alarmManager.canScheduleExactAlarms()) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at.time, pi)
        } else {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at.time, pi)
        }
    }

    private fun cancel(prefix: String) {
        prayers.indices.forEach { i ->
            pendingIntent(prefix, i, null, PendingIntent.FLAG_NO_CREATE)?.let { alarmManager.cancel(it); it.cancel() }
        }
    }

    private fun cancelAll() { cancel("adhan"); cancel("iqama") }

    /** Android binds sounds to channels, so each adhan sound gets its own channel. Returns the channel id. */
    private fun ensureChannel(sound: AdhanSoundOption?): String {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val uri = sound?.uri(context)
        val id = if (sound == null) "iqama" else "adhan_${sound.resName ?: "default"}"
        if (nm.getNotificationChannel(id) == null) {
            val channel = NotificationChannel(id, if (sound == null) "Iqama" else "Adhan (${sound.displayName})", NotificationManager.IMPORTANCE_HIGH)
            if (uri != null) {
                channel.setSound(
                    Uri.parse(uri),
                    AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
                )
            }
            nm.createNotificationChannel(channel)
        }
        return id
    }
}

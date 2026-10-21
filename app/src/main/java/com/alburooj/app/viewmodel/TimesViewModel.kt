package com.alburooj.app.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.alburooj.app.constants.AppConstants
import com.alburooj.app.data.AppPrefs
import com.alburooj.app.data.models.AdhanTime
import com.alburooj.app.data.models.AnnualTime
import com.alburooj.app.data.models.IqamaTime
import com.alburooj.app.data.models.PrayerSetting
import com.alburooj.app.services.AdhanTimesService
import com.alburooj.app.services.IqamaTimesService
import com.alburooj.app.services.PrayerSettingsService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

data class CurrentPrayerInfo(val name: String, val adhan: Date, val iqama: Date)
data class CountdownInfo(val countdown: String, val label: String)

/** Mapped from TimesViewModel.swift. */
class TimesViewModel : ViewModel() {
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }

    private val _adhanTimes = MutableStateFlow(AdhanTime())
    val adhanTimes: StateFlow<AdhanTime> = _adhanTimes.asStateFlow()

    private val _iqamaTimesString = MutableStateFlow<AnnualTime?>(null)
    val iqamaTimesString: StateFlow<AnnualTime?> = _iqamaTimesString.asStateFlow()

    private val _iqamaTimes = MutableStateFlow<IqamaTime?>(null)
    val iqamaTimes: StateFlow<IqamaTime?> = _iqamaTimes.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _displayedDayOffset = MutableStateFlow(0)
    val displayedDayOffset: StateFlow<Int> = _displayedDayOffset.asStateFlow()

    private val _hasLoaded = MutableStateFlow(false)
    val hasLoaded: StateFlow<Boolean> = _hasLoaded.asStateFlow()

    private val _settings = MutableStateFlow<PrayerSetting?>(null)
    val settings: StateFlow<PrayerSetting?> = _settings.asStateFlow()

    private val maghribDelayMinutes: Int
        get() = AppPrefs.getString(AppConstants.PRAYER_SETTINGS).takeIf { it.isNotEmpty() }
            ?.let { runCatching { json.decodeFromString<PrayerSetting>(it) }.getOrNull() }
            ?.maghribDelay ?: 3

    private fun timeFormatter() = SimpleDateFormat("h:mm a", Locale.US)

    fun load(dayOffset: Int = 0) {
        viewModelScope.launch { loadSuspending(dayOffset) }
    }

    suspend fun loadSuspending(dayOffset: Int = 0) {
        _isLoading.value = true
        _displayedDayOffset.value = dayOffset

        fetchAdhanTimes(dayOffset)
        fetchAnnualTimesIfNeeded()
        extractIqamaTimes(dayOffset)
        fetchPrayerSettings()
        _isLoading.value = false
        _hasLoaded.value = true
    }

    fun fetchAdhanTimes(dayShift: Int = 0) {
        val latitude = AppPrefs.getDouble(AppConstants.LATT)
        val longitude = AppPrefs.getDouble(AppConstants.LONG)
        val school = AppPrefs.getInt(AppConstants.JURISDICTION)
        val method = AppPrefs.getString(AppConstants.CALC_METH, "ISNA")
        _adhanTimes.value = AdhanTimesService().calcAdhanTimes(dayShift, latitude, longitude, school, method)
    }

    suspend fun fetchPrayerSettings() {
        _settings.value = runCatching { PrayerSettingsService().fetchPrayerSettings() }.getOrNull()
    }

    suspend fun fetchAnnualTimesIfNeeded() {
        // IqamaTimesService caches per-day itself; failures fall back to whatever is cached.
        runCatching { IqamaTimesService().fetchIqamaTimes() }
    }

    fun extractIqamaTimes(dayOffset: Int = 0) {
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
            add(Calendar.DAY_OF_YEAR, dayOffset)
        }
        extractIqamaTimes(target)
    }

    private fun extractIqamaTimes(target: Calendar) {
        val cached = AppPrefs.getString(AppConstants.ANNUAL_TIMES)
        val annual = cached.takeIf { it.isNotEmpty() }
            ?.let { runCatching { json.decodeFromString<List<AnnualTime>>(it) }.getOrNull() }
        if (annual == null) {
            _iqamaTimes.value = IqamaTime()
            return
        }

        val month = target.get(Calendar.MONTH) + 1
        val day = target.get(Calendar.DAY_OF_MONTH)
        val row = annual.firstOrNull { it.month == month && (it.fromDay ?: 0) <= day && (it.toDay ?: 0) >= day }
        _iqamaTimesString.value = row

        val maghribAdhan = _adhanTimes.value.maghrib
        _iqamaTimes.value = IqamaTime(
            fajr = parseTime(row?.fajrTime, target),
            dhuhar = parseTime(row?.dhuharTime, target),
            asar = parseTime(row?.asrTime, target),
            maghrib = if (maghribAdhan != null) {
                Calendar.getInstance().apply { time = maghribAdhan; add(Calendar.MINUTE, maghribDelayMinutes) }.time
            } else parseTime(row?.maghribTime, target),
            isha = parseTime(row?.ishaTime, target)
        )
    }

    private fun parseTime(timeString: String?, on: Calendar): Date? {
        if (timeString.isNullOrEmpty()) return null
        val parsed = runCatching { SimpleDateFormat("HH:mm", Locale.US).parse(timeString) }.getOrNull() ?: return null
        val t = Calendar.getInstance().apply { time = parsed }
        return Calendar.getInstance().apply {
            time = on.time
            set(Calendar.HOUR_OF_DAY, t.get(Calendar.HOUR_OF_DAY))
            set(Calendar.MINUTE, t.get(Calendar.MINUTE))
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.time
    }

    private fun iqamaDate(prayerName: String): Date? {
        val t = _iqamaTimes.value ?: return null
        return when (prayerName) {
            "Fajr" -> t.fajr
            "Dhuhar", "Dhuhr" -> t.dhuhar
            "Asar", "Asr" -> t.asar
            "Maghrib" -> t.maghrib
            "Isha" -> t.isha
            else -> null
        }
    }

    fun iqamaTime(name: String): String = iqamaDate(name)?.let { timeFormatter().format(it) } ?: ""

    fun currentPrayerInfo(): CurrentPrayerInfo? {
        val now = Date()
        val a = _adhanTimes.value

        // Midnight is stored as a time-of-day on today's date; if it precedes Isha it belongs to tomorrow.
        var ishaEnd = a.midnight
        if (a.isha != null && ishaEnd != null && ishaEnd.before(a.isha)) {
            ishaEnd = Calendar.getInstance().apply { time = ishaEnd!!; add(Calendar.DAY_OF_YEAR, 1) }.time
        }

        val windows = listOf(
            Triple("Fajr", a.fajr, a.sunrise),
            Triple("Dhuhar", a.dhuhar, a.asar),
            Triple("Asar", a.asar, a.maghrib),
            Triple("Maghrib", a.maghrib, a.isha),
            Triple("Isha", a.isha, ishaEnd)
        )
        for ((name, start, end) in windows) {
            if (start == null || end == null) continue
            if (!now.before(start) && now.before(end)) {
                return CurrentPrayerInfo(name, start, iqamaDate(name) ?: start)
            }
        }
        return null
    }

    fun countdownInfo(now: Date, adhan: Date, iqama: Date, nextAdhan: Date?): CountdownInfo = when {
        now.before(adhan) -> CountdownInfo(formatInterval(adhan.time - now.time), "Until Adhan")
        now.before(iqama) -> CountdownInfo(formatInterval(iqama.time - now.time), "Until Iqama")
        nextAdhan != null && now.before(nextAdhan) -> CountdownInfo(formatInterval(nextAdhan.time - now.time), "Until Next Adhan")
        else -> CountdownInfo(formatInterval(now.time - iqama.time), "Since Iqama")
    }

    fun formatInterval(millis: Long): String {
        val total = (millis / 1000).toInt()
        val h = total / 3600
        val m = (total % 3600) / 60
        val s = total % 60
        return if (h > 0) String.format(Locale.US, "%d:%02d:%02d", h, m, s) else String.format(Locale.US, "%02d:%02d", m, s)
    }
}

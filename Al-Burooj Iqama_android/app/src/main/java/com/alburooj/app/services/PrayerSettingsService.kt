package com.alburooj.app.services

import com.alburooj.app.constants.AppConstants
import com.alburooj.app.data.AppPrefs
import com.alburooj.app.data.models.MasjidProApiPaths
import com.alburooj.app.data.models.PrayerSetting
import com.alburooj.app.data.network.UserFriendlyError
import com.alburooj.app.helper.getBaseUrl
import com.alburooj.app.helper.getDeviceCode
import com.alburooj.app.helper.todayKey
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Mapped from PrayerSettingsService.swift. */
class PrayerSettingsService {
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }

    suspend fun fetchPrayerSettings(): PrayerSetting {
        val cached = AppPrefs.getString(AppConstants.PRAYER_SETTINGS)
        if (cached.isNotEmpty() && AppPrefs.getString(AppConstants.PRAYER_SETTINGS_LAST_FETCH) == todayKey()) {
            runCatching { json.decodeFromString<PrayerSetting>(cached) }.getOrNull()?.let { return it }
        }

        val url = getBaseUrl() + MasjidProApiPaths.Resources.byDeviceCode("prayerSettings", getDeviceCode())
        val body = authorizedGet(url, "Prayer Settings") { fetchPrayerSettings() }

        val decoded = try {
            json.decodeFromString<PrayerSetting>(body)
        } catch (e: Exception) {
            throw UserFriendlyError.dataLoading("Prayer Settings") { fetchPrayerSettings() }
        }
        AppPrefs.putString(AppConstants.PRAYER_SETTINGS, json.encodeToString(decoded))
        AppPrefs.putString(AppConstants.PRAYER_SETTINGS_LAST_FETCH, todayKey())
        return decoded
    }
}

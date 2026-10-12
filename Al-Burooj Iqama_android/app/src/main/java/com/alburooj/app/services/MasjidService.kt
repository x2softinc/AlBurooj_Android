package com.alburooj.app.services

import com.alburooj.app.constants.AppConstants
import com.alburooj.app.data.AppPrefs
import com.alburooj.app.data.models.MasjidInfo
import com.alburooj.app.data.models.MasjidProApiPaths
import com.alburooj.app.data.network.UserFriendlyError
import com.alburooj.app.helper.getBaseUrl
import com.alburooj.app.helper.getDeviceCode
import com.alburooj.app.helper.todayKey
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Mapped from MasjidService.swift. */
class MasjidService {
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }

    suspend fun fetchMasjidInfo(): MasjidInfo {
        val cached = AppPrefs.getString(AppConstants.MASJID_INFO)
        if (cached.isNotEmpty() && AppPrefs.getString(AppConstants.MASJID_INFO_LAST_FETCH) == todayKey()) {
            runCatching { json.decodeFromString<MasjidInfo>(cached) }.getOrNull()?.let { return it }
        }

        val url = getBaseUrl() + MasjidProApiPaths.Resources.byDeviceCode("masjidInfo", getDeviceCode())
        val body = authorizedGet(url, "Masjid Information") { fetchMasjidInfo() }

        val decoded = try {
            json.decodeFromString<MasjidInfo>(body)
        } catch (e: Exception) {
            throw UserFriendlyError.dataLoading("Masjid Information") { fetchMasjidInfo() }
        }
        AppPrefs.putString(AppConstants.MASJID_INFO, json.encodeToString(decoded))
        AppPrefs.putString(AppConstants.MASJID_INFO_LAST_FETCH, todayKey())
        return decoded
    }
}

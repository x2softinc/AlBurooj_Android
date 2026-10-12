package com.alburooj.app.services

import com.alburooj.app.constants.AppConstants
import com.alburooj.app.data.AppPrefs
import com.alburooj.app.data.models.AnnualTime
import com.alburooj.app.data.models.MasjidProApiPaths
import com.alburooj.app.data.network.UserFriendlyError
import com.alburooj.app.helper.getBaseUrl
import com.alburooj.app.helper.getDeviceCode
import com.alburooj.app.helper.todayKey
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** Mapped from IqamaTimesService.swift. */
class IqamaTimesService {
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }

    suspend fun fetchIqamaTimes(): List<AnnualTime> {
        val cached = AppPrefs.getString(AppConstants.ANNUAL_TIMES)
        if (cached.isNotEmpty() && AppPrefs.getString(AppConstants.ANNUAL_TIMES_LAST_FETCH) == todayKey()) {
            runCatching { json.decodeFromString<List<AnnualTime>>(cached) }.getOrNull()?.let { return it }
        }

        val url = getBaseUrl() + MasjidProApiPaths.Resources.byDeviceCode("annualTimes", getDeviceCode()) + "?recordType=IQAMA"
        val body = authorizedGet(url, "Iqama Times") { fetchIqamaTimes() }

        val decoded = try {
            json.decodeFromString<List<AnnualTime>>(body)
        } catch (e: Exception) {
            throw UserFriendlyError.dataLoading("Iqama Times") { fetchIqamaTimes() }
        }
        AppPrefs.putString(AppConstants.ANNUAL_TIMES, json.encodeToString(decoded))
        AppPrefs.putString(AppConstants.ANNUAL_TIMES_LAST_FETCH, todayKey())
        return decoded
    }
}

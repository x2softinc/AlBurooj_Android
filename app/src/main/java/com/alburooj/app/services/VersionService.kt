package com.alburooj.app.services

import android.content.Context
import com.alburooj.app.BuildConfig
import com.alburooj.app.constants.AppConstants
import com.alburooj.app.data.AppPrefs
import com.alburooj.app.data.models.VersionInfo
import com.alburooj.app.data.network.ApiClient
import kotlinx.serialization.json.Json

/** Mapped from VersionService.swift. Returns true when a forced update is required. */
class VersionService(private val context: Context) {
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true }
    private val versionUrl = "https://nexus.x2softinc.com/api/v1/apps/by-code/ALBIOS1"

    suspend fun checkVersion(): Boolean {
        val res = ApiClient.get(
            versionUrl,
            mapOf("x-api-key" to BuildConfig.VERSION_API_KEY, "Content-Type" to "application/json")
        )
        if (res.code != 200) throw Exception("Unexpected status code: ${res.code}")

        val info = json.decodeFromString<VersionInfo>(res.body)
        val appVersion = context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: return false

        if (!info.baseURL.isNullOrEmpty() && info.overrideURL == true) {
            AppPrefs.putString(AppConstants.BASE_URL, info.baseURL)
        }

        val serverVersion = info.version?.trim().orEmpty()
        if (serverVersion.isEmpty()) return false
        return (info.forceVersion ?: false) && isNewerVersion(serverVersion, appVersion)
    }

    /** True when [candidate] is newer than [current]; numeric segments only. */
    private fun isNewerVersion(candidate: String, current: String): Boolean {
        fun segments(v: String) = v.substringBefore("-").substringBefore("+").split(".").map { it.toIntOrNull() ?: 0 }
        val c = segments(candidate)
        val cur = segments(current)
        for (i in 0 until maxOf(c.size, cur.size)) {
            val a = c.getOrElse(i) { 0 }
            val b = cur.getOrElse(i) { 0 }
            if (a != b) return a > b
        }
        return false
    }
}

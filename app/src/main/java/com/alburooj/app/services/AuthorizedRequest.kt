package com.alburooj.app.services

import com.alburooj.app.data.network.ApiClient
import com.alburooj.app.data.network.UserFriendlyError

/**
 * Shared GET-with-bearer flow used by Masjid/Iqama/PrayerSettings services:
 * fetch token, call, on 401 refresh the token and retry once, map failures to [UserFriendlyError].
 */
suspend fun authorizedGet(url: String, feature: String, retry: suspend () -> Unit): String {
    val auth = AuthService()
    val token = try {
        auth.getDeviceToken()
    } catch (e: Exception) {
        throw UserFriendlyError.authentication()
    }
    if (token.isEmpty()) throw UserFriendlyError.authentication()

    fun headers(t: String) = mapOf("Authorization" to "Bearer $t", "Accept" to "application/json")

    try {
        var res = ApiClient.get(url, headers(token))
        if (res.code == 401) {
            val newToken = auth.getDeviceToken()
            if (newToken.isEmpty()) throw UserFriendlyError.authentication()
            res = ApiClient.get(url, headers(newToken))
        }
        if (!res.isSuccessful) {
            if (res.code >= 500) throw UserFriendlyError.serverError()
            throw UserFriendlyError.dataLoading(feature, retry)
        }
        return res.body
    } catch (e: UserFriendlyError) {
        throw e
    } catch (e: Exception) {
        throw UserFriendlyError.generic(e, retry)
    }
}

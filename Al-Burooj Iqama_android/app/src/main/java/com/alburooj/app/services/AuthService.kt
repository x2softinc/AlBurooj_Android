package com.alburooj.app.services

import android.util.Base64
import com.alburooj.app.constants.AppConstants
import com.alburooj.app.data.AppPrefs
import com.alburooj.app.data.models.MasjidProApiPaths
import com.alburooj.app.data.network.ApiClient
import com.alburooj.app.data.network.HttpException
import com.alburooj.app.helper.getBaseUrl
import com.alburooj.app.helper.getDeviceCode
import org.json.JSONObject
import java.security.MessageDigest
import java.security.SecureRandom
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

/** Mapped from AuthService.swift (PKCE device-code flow). */
class AuthService {

    private val tokenExpirySkewMs = 30 * 1000.0
    private val defaultTokenLifetimeMs = 60 * 60 * 1000.0

    private var token: String
        get() = AppPrefs.getString(AppConstants.AUTH_TOKEN)
        set(value) = AppPrefs.putString(AppConstants.AUTH_TOKEN, value)

    private var tokenExpiryTime: String
        get() = AppPrefs.getString(AppConstants.TOKEN_EXPIRES_AT)
        set(value) = AppPrefs.putString(AppConstants.TOKEN_EXPIRES_AT, value)

    private fun randomBytes(n: Int) = ByteArray(n).also { SecureRandom().nextBytes(it) }

    private fun toBase64Url(data: ByteArray): String =
        Base64.encodeToString(data, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

    private fun createPkcePair(): Pair<String, String> {
        val verifier = toBase64Url(randomBytes(32))
        val challenge = toBase64Url(MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.UTF_8)))
        return verifier to challenge
    }

    fun isUnauthorizedError(error: Throwable?): Boolean {
        if (error == null) return false
        if (error is HttpException && error.code == 401) return true
        val m = error.message?.lowercase().orEmpty()
        return m.contains("unauthorized") || m.contains("401")
    }

    fun isConflictError(error: Throwable?): Boolean {
        if (error == null) return false
        if (error is HttpException && error.code == 409) return true
        val m = error.message?.lowercase().orEmpty()
        return m.contains("conflict") || m.contains("409")
    }

    fun isAuthTokenExpired(): Boolean {
        if (token.isEmpty()) return true
        val expiry = tokenExpiryTime.toDoubleOrNull() ?: return true
        if (expiry <= 0) return true
        return System.currentTimeMillis() >= expiry - tokenExpirySkewMs
    }

    private fun decodeJwtExpiry(jwt: String): Double? {
        val parts = jwt.split(".")
        if (parts.size < 2) return null
        return try {
            val payload = Base64.decode(parts[1], Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)
            val exp = JSONObject(String(payload)).optDouble("exp", -1.0)
            if (exp > 0) exp * 1000.0 else null
        } catch (e: Exception) {
            null
        }
    }

    private fun resolveTokenExpiry(jwt: String, response: JSONObject): Double {
        val expiresIn = response.optDouble("expiresIn", response.optDouble("expires_in", -1.0))
        if (expiresIn > 0) return System.currentTimeMillis() + expiresIn * 1000.0

        val rawExpiresAt = response.optString("expiresAt", response.optString("expires_at", ""))
        if (rawExpiresAt.isNotEmpty()) {
            for (pattern in listOf("yyyy-MM-dd'T'HH:mm:ssX", "yyyy-MM-dd'T'HH:mm:ss.SSSX")) {
                try {
                    val fmt = SimpleDateFormat(pattern, Locale.US).apply { timeZone = TimeZone.getTimeZone("UTC") }
                    fmt.parse(rawExpiresAt)?.let { return it.time.toDouble() }
                } catch (_: Exception) { }
            }
        }

        decodeJwtExpiry(jwt)?.let { return it }
        return System.currentTimeMillis() + defaultTokenLifetimeMs
    }

    /** Runs the PKCE device-code flow and returns a fresh access token. */
    suspend fun getDeviceToken(): String {
        val (verifier, challenge) = createPkcePair()
        val state = toBase64Url(randomBytes(16))

        val authorization = authorizePkceDeviceCode(
            mapOf(
                "clientId" to AppConstants.CLIENT_ID,
                "deviceCode" to getDeviceCode(),
                "redirectUri" to AppConstants.REDIRECT_URI,
                "responseType" to "code",
                "state" to state,
                "scope" to "openid profile",
                "codeChallenge" to challenge,
                "codeChallengeMethod" to "S256"
            )
        )

        val code = authorization.optString("code", "")
        if (code.isEmpty()) throw Exception("The authorization server did not return an authorization code.")

        val tokenResponse = oauthTokenAuthorizationCode(
            mapOf(
                "grant_type" to "authorization_code",
                "client_id" to AppConstants.CLIENT_ID,
                "code" to code,
                "redirect_uri" to AppConstants.REDIRECT_URI,
                "code_verifier" to verifier
            )
        )

        val access = tokenResponse.optString("accessToken", tokenResponse.optString("token", ""))
        if (access.isEmpty()) throw Exception("The authorization server did not return an access token.")

        token = access
        tokenExpiryTime = resolveTokenExpiry(access, tokenResponse).toString()
        return access
    }

    private suspend fun authorizePkceDeviceCode(payload: Map<String, String>): JSONObject {
        val res = ApiClient.postJson(getBaseUrl() + MasjidProApiPaths.OAuth.authorizePkceDeviceCode, JSONObject(payload).toString())
        if (!res.isSuccessful) throw HttpException(res.code, "Authorization request failed.")
        return JSONObject(res.body)
    }

    private suspend fun oauthTokenAuthorizationCode(payload: Map<String, String>): JSONObject {
        val res = ApiClient.postForm(getBaseUrl() + MasjidProApiPaths.OAuth.token, payload)
        if (!res.isSuccessful) throw HttpException(res.code, "Token request failed.")
        return JSONObject(res.body)
    }
}

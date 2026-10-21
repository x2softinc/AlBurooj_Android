package com.alburooj.app.data.models

import java.net.URLEncoder

/** Mapped from SwiftUI MasjidProApiPaths. */
object MasjidProApiPaths {
    private fun enc(s: String) = URLEncoder.encode(s, "UTF-8").replace("+", "%20")

    object Auth {
        const val login = "/api/auth/login"
        const val me = "/api/auth/me"
        const val forgotPassword = "/api/auth/forgot-password"
        const val resetPassword = "/api/auth/reset-password"
    }

    object OAuth {
        const val authorizePkce = "/api/oauth/authorize-pkce"
        const val authorizePkceDeviceCode = "/api/oauth/authorize-pkce-deviceCode"
        const val token = "/api/oauth/token"
        const val clients = "/api/oauth/clients"
    }

    object Device {
        const val register = "/api/device/register"
        const val all = "/api/device/all"
        fun byUser(userEmail: String) = "/api/device/by-user/${enc(userEmail)}"
        fun byDeviceCode(deviceCode: String) = "/api/device/${enc(deviceCode)}"
        fun validate(deviceCode: String) = "/api/device/${enc(deviceCode)}/validate"
        fun deactivate(deviceCode: String) = "/api/device/${enc(deviceCode)}/deactivate"
    }

    object Resources {
        fun list(resource: String) = "/api/$resource"
        fun byDeviceCode(resource: String, deviceCode: String) = "/api/$resource/masjid/${enc(deviceCode)}"
        fun byId(resource: String, id: String) = "/api/$resource/${enc(id)}"
    }
}

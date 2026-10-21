package com.alburooj.app.data.models

import kotlinx.serialization.Serializable

@Serializable
data class LoginPayload(
    val username: String,
    val password: String,
    val clientId: String
)

@Serializable
data class ForgotPasswordPayload(
    val email: String
)

@Serializable
data class ResetPasswordPayload(
    val email: String,
    val token: String,
    val newPassword: String
)

@Serializable
data class RegisterDevicePayload(
    val userEmail: String,
    val deviceName: String
)

@Serializable
data class AuthPayload(
    val clientId: String,
    val deviceCode: String,
    val redirectUri: String,
    val responseType: String,
    val state: String,
    val scope: String,
    val codeChallenge: String,
    val codeChallengeMethod: String
)

package com.alburooj.app.data.network

import java.net.SocketTimeoutException
import java.net.UnknownHostException

/** Mapped from UserFriendlyError.swift. [icon] holds a Material icon name resolved by the UI. */
sealed class RecoveryAction {
    class Retry(val action: suspend () -> Unit) : RecoveryAction()
    object OpenSettings : RecoveryAction()
    object Contact : RecoveryAction()
    object None : RecoveryAction()

    val buttonTitle: String
        get() = when (this) {
            is Retry -> "Try Again"
            OpenSettings -> "Open Settings"
            Contact -> "Contact Support"
            None -> "OK"
        }
}

class UserFriendlyError(
    val title: String,
    override val message: String,
    val icon: String,
    val recoveryAction: RecoveryAction? = null
) : Exception(message) {

    companion object {
        fun network(retry: (suspend () -> Unit)? = null) = UserFriendlyError(
            "Connection Problem",
            "We're having trouble connecting to the server. Please check your internet connection and try again.",
            "wifi_off", retry?.let { RecoveryAction.Retry(it) }
        )

        fun authentication() = UserFriendlyError(
            "Authentication Required",
            "Your device needs to reconnect to access this feature. Please reconnect in Settings.",
            "lock", RecoveryAction.OpenSettings
        )

        fun locationPermission() = UserFriendlyError(
            "Location Access Needed",
            "Al-Burooj Iqama needs access to your location to calculate accurate prayer times. Please enable location access in Settings.",
            "location_off", RecoveryAction.OpenSettings
        )

        fun notificationPermission() = UserFriendlyError(
            "Notification Access Needed",
            "To receive prayer time reminders, please enable notifications in Settings.",
            "notifications_off", RecoveryAction.OpenSettings
        )

        fun dataLoading(feature: String, retry: (suspend () -> Unit)? = null) = UserFriendlyError(
            "Unable to Load $feature",
            "We couldn't load $feature right now. This might be a temporary issue. Please try again.",
            "warning", retry?.let { RecoveryAction.Retry(it) }
        )

        fun serverError() = UserFriendlyError(
            "Server Issue",
            "Our server is having trouble right now. Please try again in a few moments.",
            "dns", RecoveryAction.Contact
        )

        fun timeout(retry: (suspend () -> Unit)? = null) = UserFriendlyError(
            "Request Timed Out",
            "The request took too long to complete. Please check your internet connection and try again.",
            "timer_off", retry?.let { RecoveryAction.Retry(it) }
        )

        fun generic(error: Throwable, retry: (suspend () -> Unit)? = null): UserFriendlyError = when {
            error is UserFriendlyError -> error
            error is SocketTimeoutException -> timeout(retry)
            error is UnknownHostException || error is java.io.IOException -> network(retry)
            error is HttpException && error.code == 401 -> authentication()
            error is HttpException && error.code >= 500 -> serverError()
            else -> UserFriendlyError(
                "Something Went Wrong",
                "We encountered an unexpected problem. Please try again.",
                "warning", retry?.let { RecoveryAction.Retry(it) }
            )
        }
    }
}

/** Non-2xx HTTP result. */
class HttpException(val code: Int, message: String) : Exception(message)

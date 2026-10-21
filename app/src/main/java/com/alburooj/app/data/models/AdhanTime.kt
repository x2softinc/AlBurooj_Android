package com.alburooj.app.data.models

import java.util.Date

/**
 * Daily prayer time model.
 * Replicated from SwiftUI AdhanTime struct.
 */
data class AdhanTime(
    var fajr: Date? = null,
    var imsak: Date? = null,
    var sunrise: Date? = null,
    var dhuhar: Date? = null,
    var asar: Date? = null,
    var asarHanafi: Date? = null,
    var maghrib: Date? = null,
    var sunset: Date? = null,
    var isha: Date? = null,
    var midnight: Date? = null,
    var zawal: Date? = null
)

package com.alburooj.app.data.models

import java.util.Date

/**
 * Iqama time model.
 * Replicated from SwiftUI IqamaTime struct.
 */
data class IqamaTime(
    var fajr: Date? = null,
    var dhuhar: Date? = null,
    var asar: Date? = null,
    var maghrib: Date? = null,
    var isha: Date? = null
)

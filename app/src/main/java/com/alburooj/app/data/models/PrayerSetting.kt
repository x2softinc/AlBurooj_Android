package com.alburooj.app.data.models

import kotlinx.serialization.Serializable

/**
 * User prayer settings.
 * Replicated from SwiftUI PrayerSetting struct.
 */
@Serializable
data class PrayerSetting(
    var id: Int? = null,
    var deviceCode: String? = null,
    var calcMethod: String = "MWL",
    var maintMethod: Int = 0,
    var jumma: String? = null,
    var jumma2: String? = null,
    var hijriAdjustment: Int = 0,
    var asrMethod: Int = 0,
    var maghribDelay: Int = 3,
    var roundMinutes: Int = 0
)

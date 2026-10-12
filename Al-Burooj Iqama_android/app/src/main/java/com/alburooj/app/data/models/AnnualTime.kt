package com.alburooj.app.data.models

import kotlinx.serialization.Serializable

/**
 * Annual iqama times.
 * Replicated from SwiftUI AnnualTime struct.
 */
@Serializable
data class AnnualTime(
    var id: Int? = null,
    var recordType: String? = null,
    var masjidCode: String? = null,
    var month: Int? = null,
    var fromDay: Int? = null,
    var toDay: Int? = null,
    var fajrTime: String? = null,
    var dhuharTime: String? = null,
    var asrTime: String? = null,
    var maghribTime: String? = null,
    var ishaTime: String? = null
)

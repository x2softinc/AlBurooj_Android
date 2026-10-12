package com.alburooj.app.data.models

import kotlinx.serialization.Serializable

/**
 * Masjid information.
 * Replicated from SwiftUI MasjidInfo struct.
 */
@Serializable
data class MasjidInfo(
    var id: Int? = null,
    var masjidCode: String? = null,
    var masjidName: String? = null,
    var address: String? = null,
    var address1: String? = null,
    var city: String? = null,
    var state: String? = null,
    var postalCode: String? = null,
    var country: String? = null,
    var email: String? = null,
    var latitude: Double = 0.0,
    var longitude: Double = 0.0,
    var phone: String? = null,
    var url: String? = null
)

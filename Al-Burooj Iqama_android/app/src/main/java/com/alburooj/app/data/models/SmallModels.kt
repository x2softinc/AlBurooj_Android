package com.alburooj.app.data.models

import kotlinx.serialization.Serializable

/** Announcement/TimeDelay/FixedTime mapped from Announcement.swift, TimeDelay.swift, FixedIqamaTime.swift. Dates arrive as ISO strings. */
@Serializable
data class Announcement(
    val id: Int = 0,
    val masjidCode: String? = null,
    val fromDate: String? = null,
    val toDate: String? = null,
    val infoText: String? = null
)

@Serializable
data class TimeDelay(
    val id: Int? = null,
    val masjidCode: String? = null,
    val fajr: Int = 0,
    val dhuhar: Int = 0,
    val asr: Int = 0,
    val isha: Int = 0
)

@Serializable
data class FixedTime(
    val id: Int? = null,
    val masjidCode: String? = null,
    val fajr: String? = null,
    val dhuhar: String? = null,
    val asr: String? = null,
    val isha: String? = null
)

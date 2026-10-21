package com.alburooj.app.data.models

import kotlinx.serialization.Serializable

@Serializable
data class VersionInfo(
    val id: Int? = null,
    val appCode: String? = null,
    val description: String? = null,
    val version: String? = null,
    val forceVersion: Boolean? = null,
    val platform: String? = null,
    val status: String? = null,
    val owner: String? = null,
    val isActive: Boolean? = null,
    val baseURL: String? = null,
    val overrideURL: Boolean? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null
)

package com.alburooj.app.data.network

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.FormBody
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

/** Thin OkHttp wrapper standing in for URLSession. */
object ApiClient {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    class Response(val code: Int, val body: String) {
        val isSuccessful get() = code in 200..299
    }

    private suspend fun execute(request: Request): Response = withContext(Dispatchers.IO) {
        client.newCall(request).execute().use { Response(it.code, it.body?.string().orEmpty()) }
    }

    suspend fun get(url: String, headers: Map<String, String> = emptyMap()): Response =
        execute(Request.Builder().url(url).get().apply { headers.forEach { (k, v) -> header(k, v) } }.build())

    suspend fun postJson(url: String, json: String, headers: Map<String, String> = emptyMap()): Response =
        execute(
            Request.Builder().url(url)
                .post(json.toRequestBody("application/json".toMediaType()))
                .header("Accept", "application/json")
                .apply { headers.forEach { (k, v) -> header(k, v) } }
                .build()
        )

    suspend fun postForm(url: String, fields: Map<String, String>): Response =
        execute(
            Request.Builder().url(url)
                .post(FormBody.Builder().apply { fields.forEach { (k, v) -> add(k, v) } }.build())
                .header("Accept", "application/json")
                .build()
        )
}

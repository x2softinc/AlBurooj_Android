package com.alburooj.app.data

import android.content.Context
import android.content.SharedPreferences

/**
 * Process-wide replacement for SwiftUI's @AppStorage / UserDefaults.
 * Initialised once from [com.alburooj.app.AlBuroojApp].
 */
object AppPrefs {
    private lateinit var prefs: SharedPreferences

    fun init(context: Context) {
        prefs = context.applicationContext.getSharedPreferences("al_burooj_prefs", Context.MODE_PRIVATE)
    }

    fun getString(key: String, default: String = ""): String = prefs.getString(key, default) ?: default
    fun putString(key: String, value: String) = prefs.edit().putString(key, value).apply()

    fun getBoolean(key: String, default: Boolean = false): Boolean = prefs.getBoolean(key, default)
    fun putBoolean(key: String, value: Boolean) = prefs.edit().putBoolean(key, value).apply()

    fun getInt(key: String, default: Int = 0): Int = prefs.getInt(key, default)
    fun putInt(key: String, value: Int) = prefs.edit().putInt(key, value).apply()

    /** Doubles are stored as raw long bits so 0.0 / precision round-trip exactly. */
    fun getDouble(key: String, default: Double = 0.0): Double =
        if (prefs.contains(key)) Double.fromBits(prefs.getLong(key, 0L)) else default
    fun putDouble(key: String, value: Double) = prefs.edit().putLong(key, value.toRawBits()).apply()

    fun remove(key: String) = prefs.edit().remove(key).apply()
}

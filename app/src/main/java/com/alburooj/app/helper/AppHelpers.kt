package com.alburooj.app.helper

import com.alburooj.app.constants.AppConstants
import com.alburooj.app.data.AppPrefs
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Mapped from deviceCodeHelper.swift (the Swift source force-overrides the code). */
fun getDeviceCode(): String {
    val code = "18549825"
    AppPrefs.putString(AppConstants.DEVICE_CODE, code)
    return code
}

/** Mapped from UrlHelper.swift. */
fun getBaseUrl(): String {
    var baseUrl = AppPrefs.getString(AppConstants.BASE_URL)
    if (baseUrl.isEmpty()) {
        baseUrl = "https://masjidpro.x2softinc.com"
        AppPrefs.putString(AppConstants.BASE_URL, baseUrl)
    }
    return baseUrl
}

/** Today's date as yyyy-MM-dd; evaluated per call (the Swift global was fixed at launch). */
fun todayKey(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

package com.alburooj.app

import android.app.Application
import com.alburooj.app.data.AppPrefs

class AlBuroojApp : Application() {
    override fun onCreate() {
        super.onCreate()
        AppPrefs.init(this)
    }
}

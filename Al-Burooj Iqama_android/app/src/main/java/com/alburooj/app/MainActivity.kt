package com.alburooj.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.remember
import com.alburooj.app.constants.AppConstants
import com.alburooj.app.managers.LocationManager
import com.alburooj.app.ui.MainScreen
import com.alburooj.app.ui.components.AppVersionGate
import com.alburooj.app.ui.theme.AlBuroojTheme

/** Mapped from Al_Burooj_IqamaApp.swift: version gate wrapping the main content. */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AlBuroojTheme {
                // Owned here so location is shared app-wide (ContentView owned it on iOS).
                val locationManager = remember { LocationManager(applicationContext) }
                AppVersionGate(AppConstants.APP_URL) { MainScreen(locationManager) }
            }
        }
    }
}

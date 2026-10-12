package com.alburooj.app.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import android.hardware.GeomagneticField
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.content.Context
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.alburooj.app.R
import com.alburooj.app.managers.LocationManager
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

private const val KAABA_LAT = 21.4225
private const val KAABA_LON = 39.8262

/** Mapped from QiblaView.swift. */
@Composable
fun QiblaScreen(locationManager: LocationManager) {
    val context = LocalContext.current
    val isTablet = LocalConfiguration.current.screenWidthDp >= 600
    val compassSize = if (isTablet) 440.dp else 300.dp
    val ringWidth = if (isTablet) 12.dp else 8.dp

    var hasPermission by remember {
        mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED)
    }
    var permissionAsked by remember { mutableStateOf(false) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        hasPermission = it; permissionAsked = true
    }
    LaunchedEffect(Unit) { if (!hasPermission) launcher.launch(Manifest.permission.ACCESS_FINE_LOCATION) }

    // Location updates are started app-wide by MainScreen.

    val location by locationManager.location.collectAsState()
    val magneticHeading by locationManager.heading.collectAsState()
    var useTrueNorth by remember { mutableStateOf(true) }
    var isLocked by remember { mutableStateOf(false) }

    // Magnetic → true north via declination at the user's position.
    val declination = remember(location) {
        location?.let { GeomagneticField(it.latitude.toFloat(), it.longitude.toFloat(), it.altitude.toFloat(), System.currentTimeMillis()).declination } ?: 0f
    }
    val headingDegrees = magneticHeading?.let { if (useTrueNorth) (it + declination + 360f) % 360f else it }?.toDouble() ?: 0.0

    val bearing: Double? = location?.let { bearingTo(it.latitude, it.longitude) }
    val pointerRotation = bearing?.let { (it - headingDegrees).toFloat() } ?: 0f
    val alignmentError = bearing?.let {
        val diff = (it - headingDegrees) % 360
        abs(if (diff < -180) diff + 360 else if (diff > 180) diff - 360 else diff)
    } ?: 180.0
    val progress = (alignmentError / 45.0).coerceIn(0.0, 1.0).toFloat()
    val distanceKm = location?.let { haversine(it.latitude, it.longitude, KAABA_LAT, KAABA_LON) / 1000.0 }

    // Lock state + success haptic on entering lock.
    LaunchedEffect(alignmentError) {
        val was = isLocked
        isLocked = alignmentError <= 3.0
        if (isLocked && !was) vibrateSuccess(context)
    }

    val statusText = when {
        !hasPermission && !permissionAsked -> "Requesting location permission…"
        !hasPermission -> "Location permission needed to show Qibla."
        location == null -> "Getting your location…"
        magneticHeading == null -> "Getting your heading…"
        else -> "Point the arrow toward the Qibla."
    }

    val animatedRotation by animateFloatAsState(pointerRotation, label = "rotation")
    val animatedProgress by animateFloatAsState(1f - progress, label = "progress")
    val lockGlow = Color(0xFF2E7D32)

    Column(
        Modifier.fillMaxSize().padding(horizontal = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(contentAlignment = Alignment.Center) {
            val ring = compassSize + 16.dp
            Canvas(Modifier.size(ring)) {
                val stroke = ringWidth.toPx()
                val inset = stroke / 2
                val arcSize = Size(size.width - stroke, size.height - stroke)
                drawArc(Color.Gray.copy(alpha = 0.2f), 0f, 360f, false, topLeft = androidx.compose.ui.geometry.Offset(inset, inset), size = arcSize, style = Stroke(stroke))
                drawArc(lockGlow, -90f, 360f * animatedProgress, false, topLeft = androidx.compose.ui.geometry.Offset(inset, inset), size = arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
            }
            // The image has a Kaaba marker at 0°; rotating it by the pointer rotation aims the marker at the Qibla.
            Image(painterResource(R.drawable.compass), contentDescription = "Qibla compass", modifier = Modifier.size(compassSize).rotate(animatedRotation))
            if (isLocked) {
                Box(Modifier.size(46.dp), contentAlignment = Alignment.Center) {
                    Icon(Icons.Filled.Lock, contentDescription = "Aligned", tint = lockGlow)
                }
            }
        }

        Spacer(Modifier.size(24.dp))
        Text(statusText, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
        Spacer(Modifier.size(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(32.dp)) {
            Stat(bearing?.let { String.format("%.0f°", it) } ?: "--°", "Bearing")
            Stat(distanceKm?.let { String.format("%.1f km", it) } ?: "-- km", "Distance")
        }
        Spacer(Modifier.size(16.dp))
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text("Use True North", Modifier.weight(1f))
            Switch(useTrueNorth, { useTrueNorth = it })
        }
    }
}

@Composable
private fun Stat(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, fontWeight = FontWeight.Bold, fontSize = 20.sp)
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** Initial great-circle bearing from the user to the Kaaba (0° = true north, clockwise). */
private fun bearingTo(lat: Double, lon: Double): Double {
    val lat1 = Math.toRadians(lat)
    val lat2 = Math.toRadians(KAABA_LAT)
    val dLon = Math.toRadians(KAABA_LON - lon)
    val y = sin(dLon) * cos(lat2)
    val x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    val deg = Math.toDegrees(atan2(y, x))
    return if (deg < 0) deg + 360 else deg
}

private fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    val r = 6_371_000.0
    val dLat = Math.toRadians(lat2 - lat1)
    val dLon = Math.toRadians(lon2 - lon1)
    val a = sin(dLat / 2) * sin(dLat / 2) + cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2)
    return r * 2 * atan2(sqrt(a), sqrt(1 - a))
}

private var lastHapticAt = 0L

private fun vibrateSuccess(context: Context) {
    val now = System.currentTimeMillis()
    if (now - lastHapticAt < 800) return // throttle to 1 per 0.8s
    lastHapticAt = now
    val vibrator = if (Build.VERSION.SDK_INT >= 31)
        (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
    else @Suppress("DEPRECATION") context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    vibrator.vibrate(VibrationEffect.createOneShot(40, VibrationEffect.DEFAULT_AMPLITUDE))
}

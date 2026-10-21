package com.alburooj.app.managers

import android.annotation.SuppressLint
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Geocoder
import android.location.Location
import android.os.Looper
import com.alburooj.app.constants.AppConstants
import com.alburooj.app.data.AppPrefs
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Mapped from LocationManager.swift: location + compass heading, with lat/long/city
 * persisted under LATT / LONG / CITY (read by TimesViewModel).
 * Runtime permission must be granted before [start] (the UI layer requests it).
 */
class LocationManager(private val context: Context) {

    private val fusedClient = LocationServices.getFusedLocationProviderClient(context)
    private val geocoder = Geocoder(context)
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _location = MutableStateFlow<Location?>(null)
    val location: StateFlow<Location?> = _location.asStateFlow()

    /** Degrees clockwise from magnetic north, 0..360. */
    private val _heading = MutableStateFlow<Float?>(null)
    val heading: StateFlow<Float?> = _heading.asStateFlow()

    private val _latitude = MutableStateFlow(AppPrefs.getDouble(AppConstants.LATT))
    val latitude: StateFlow<Double> = _latitude.asStateFlow()

    private val _longitude = MutableStateFlow(AppPrefs.getDouble(AppConstants.LONG))
    val longitude: StateFlow<Double> = _longitude.asStateFlow()

    private val _city = MutableStateFlow(AppPrefs.getString(AppConstants.CITY))
    val city: StateFlow<String> = _city.asStateFlow()

    private var lastGeocoded: Location? = null
    private var started = false

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            result.lastLocation?.let { updateLocation(it) }
        }
    }

    private val rotationMatrix = FloatArray(9)
    private val orientation = FloatArray(3)
    private val headingListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
            SensorManager.getOrientation(rotationMatrix, orientation)
            val deg = Math.toDegrees(orientation[0].toDouble()).toFloat()
            _heading.value = (deg + 360f) % 360f
        }
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    /** Starts location and heading updates. Safe to call multiple times. */
    @SuppressLint("MissingPermission")
    fun start() {
        if (started) return
        started = true
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5_000L).build()
        fusedClient.requestLocationUpdates(request, locationCallback, Looper.getMainLooper())

        sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)?.let {
            sensorManager.registerListener(headingListener, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    fun stop() {
        if (!started) return
        started = false
        fusedClient.removeLocationUpdates(locationCallback)
        sensorManager.unregisterListener(headingListener)
    }

    private fun updateLocation(location: Location) {
        _location.value = location
        _latitude.value = location.latitude
        _longitude.value = location.longitude
        AppPrefs.putDouble(AppConstants.LATT, location.latitude)
        AppPrefs.putDouble(AppConstants.LONG, location.longitude)

        if (_city.value.isEmpty() || shouldReverseGeocode(location)) {
            scope.launch {
                val name = reverseGeocode(location)
                if (name != null) {
                    _city.value = name
                    AppPrefs.putString(AppConstants.CITY, name)
                    lastGeocoded = location
                }
            }
        }
    }

    /** Re-geocode if moved more than 1000 meters. */
    private fun shouldReverseGeocode(location: Location): Boolean =
        lastGeocoded?.let { location.distanceTo(it) > 1000 } ?: true

    @Suppress("DEPRECATION")
    private suspend fun reverseGeocode(location: Location): String? = withContext(Dispatchers.IO) {
        if (!Geocoder.isPresent()) return@withContext null
        try {
            val a = geocoder.getFromLocation(location.latitude, location.longitude, 1)?.firstOrNull()
            a?.locality ?: a?.adminArea
        } catch (e: Exception) {
            null
        }
    }
}

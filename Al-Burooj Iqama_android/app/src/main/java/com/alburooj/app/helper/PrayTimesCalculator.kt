package com.alburooj.app.helper

import java.util.*
import kotlin.math.*

/**
 * Kotlin port of PrayTimes.js v2.3
 */
class PrayTimesCalculator(method: String) {

    companion object {
        private val methods = mapOf(
            "MWL" to mapOf("fajr" to "18", "isha" to "17"),
            "ISNA" to mapOf("fajr" to "15", "isha" to "15"),
            "EGAS" to mapOf("fajr" to "19.5", "isha" to "17.5"),
            "UQUM" to mapOf("fajr" to "18.5", "isha" to "90 min"),
            "UISK" to mapOf("fajr" to "18", "isha" to "18"),
            "MUIS" to mapOf("fajr" to "20", "isha" to "18"),
            "TEH" to mapOf("fajr" to "17.7", "isha" to "14", "maghrib" to "4.5", "midnight" to "Jafari"),
            "JAF" to mapOf("fajr" to "16", "isha" to "14", "maghrib" to "4", "midnight" to "Jafari")
        )

        private val defaultParams = mapOf(
            "maghrib" to "0 min",
            "midnight" to "Standard"
        )

        private val timeNames = arrayOf(
            "imsak", "fajr", "sunrise", "dhuhar", "asar", "asarHanafi",
            "sunset", "maghrib", "isha", "midnight"
        )
    }

    private var calcMethod: String = "MWL"
    private var setting = mutableMapOf(
        "imsak" to "10 min",
        "dhuhar" to "0 min",
        "asar" to "Standard",
        "highLats" to "NightMiddle"
    )
    private var timeFormat: String = "24h"
    private val invalidTime = "-----"
    private val numIterations = 1
    private val offset = mutableMapOf<String, Double>()

    private var lat = 0.0
    private var lng = 0.0
    private var elv = 0.0
    private var timeZone: Double = 0.0
    private var jDate = 0.0

    init {
        val methodKey = if (methods.containsKey(method)) method else "MWL"
        calcMethod = methodKey

        val params = (methods[methodKey] ?: emptyMap()).toMutableMap()
        defaultParams.forEach { (key, value) ->
            if (!params.containsKey(key)) {
                params[key] = value
            }
        }

        params.forEach { (key, value) ->
            setting[key] = value
        }

        timeNames.forEach { name ->
            offset[name] = 0.0
        }
    }

    fun getTimes(
        date: Date,
        coordinates: DoubleArray,
        timeZone: Double? = null,
        dst: Boolean? = null,
        format: String = "24h"
    ): Map<String, String> {
        lat = coordinates[0]
        lng = coordinates[1]
        elv = if (coordinates.size > 2) coordinates[2] else 0.0
        this.timeFormat = format

        val calendar = Calendar.getInstance()
        calendar.time = date
        val year = calendar.get(Calendar.YEAR)
        val month = calendar.get(Calendar.MONTH) + 1
        val day = calendar.get(Calendar.DAY_OF_MONTH)

        val resolvedTimeZone = timeZone ?: standardTimeZone(date)
        val isDST = dst ?: (gmtOffset(date) != standardTimeZone(date))
        this.timeZone = resolvedTimeZone + (if (isDST) 1.0 else 0.0)

        jDate = julian(year, month, day) - lng / (15.0 * 24.0)

        val computed = computeTimes()
        return modifyFormats(computed)
    }

    private fun gmtOffset(date: Date): Double {
        val calendar = Calendar.getInstance()
        calendar.time = date
        calendar.set(Calendar.HOUR_OF_DAY, 12)
        calendar.set(Calendar.MINUTE, 0)
        val noon = calendar.time
        return TimeZone.getDefault().getOffset(noon.time) / 3_600_000.0
    }

    private fun standardTimeZone(date: Date): Double {
        val calendar = Calendar.getInstance()
        calendar.time = date
        val year = calendar.get(Calendar.YEAR)
        
        val january = Calendar.getInstance().apply {
            set(year, Calendar.JANUARY, 1)
        }.time
        val july = Calendar.getInstance().apply {
            set(year, Calendar.JULY, 1)
        }.time
        
        return min(gmtOffset(january), gmtOffset(july))
    }

    private fun computeTimes(): MutableMap<String, Double> {
        var times = mutableMapOf(
            "imsak" to 5.0, "fajr" to 5.0, "sunrise" to 6.0, "dhuhar" to 12.0,
            "asar" to 13.0, "sunset" to 18.0, "maghrib" to 18.0, "isha" to 18.0
        )

        repeat(numIterations) {
            times = computePrayerTimes(times)
        }

        var adjusted = adjustTimes(times)

        val sunset = adjusted["sunset"] ?: 18.0
        val sunrise = adjusted["sunrise"] ?: 6.0
        val fajr = adjusted["fajr"] ?: 5.0

        adjusted["midnight"] = if (setting["midnight"] == "Jafari") {
            sunset + timeDiff(sunset, fajr) / 2.0
        } else {
            sunset + timeDiff(sunset, sunrise) / 2.0
        }

        return tuneTimes(adjusted)
    }

    private fun computePrayerTimes(times: Map<String, Double>): MutableMap<String, Double> {
        val portions = dayPortion(times)
        val params = setting

        val imsak = sunAngleTime(eval(params["imsak"] ?: "10 min"), portions["imsak"] ?: 5.0, "ccw")
        val fajr = sunAngleTime(eval(params["fajr"] ?: "15"), portions["fajr"] ?: 5.0, "ccw")
        val sunrise = sunAngleTime(riseSetAngle(), portions["sunrise"] ?: 6.0, "ccw")
        val dhuhar = midDay(portions["dhuhar"] ?: 12.0)
        val asar = asrTime(asarFactor(params["asar"] ?: "Standard"), portions["asar"] ?: 13.0)
        val asarHanafi = asrTime(asarFactor("Hanafi"), portions["asar"] ?: 13.0)
        val sunset = sunAngleTime(riseSetAngle(), portions["sunset"] ?: 18.0)
        val maghrib = sunAngleTime(eval(params["maghrib"] ?: "0 min"), portions["maghrib"] ?: 18.0)
        val isha = sunAngleTime(eval(params["isha"] ?: "15"), portions["isha"] ?: 18.0)

        return mutableMapOf(
            "imsak" to imsak,
            "fajr" to fajr,
            "sunrise" to sunrise,
            "dhuhar" to dhuhar,
            "asar" to asar,
            "asarHanafi" to asarHanafi,
            "sunset" to sunset,
            "maghrib" to maghrib,
            "isha" to isha
        )
    }

    private fun midDay(time: Double): Double {
        return DMath.dfixHour(12.0 - sunPosition(jDate + time).equation)
    }

    private fun sunAngleTime(angle: Double, time: Double, direction: String = "cw"): Double {
        val pos = sunPosition(jDate + time)
        val decl = pos.declination
        val noon = midDay(time)
        val t = 1.0 / 15.0 * DMath.darccos(
            (-DMath.dsin(angle) - DMath.dsin(decl) * DMath.dsin(lat)) /
            (DMath.dcos(decl) * DMath.dcos(lat))
        )
        return if (direction == "ccw") noon - t else noon + t
    }

    private fun asrTime(factor: Double, time: Double): Double {
        val decl = sunPosition(jDate + time).declination
        val angle = -DMath.darccot(factor + DMath.dtan(abs(lat - decl)))
        return sunAngleTime(angle, time)
    }

    private fun sunPosition(jd: Double): SunPosition {
        val D = jd - 2451545.0
        val g = DMath.dfixAngle(357.529 + 0.98560028 * D)
        val q = DMath.dfixAngle(280.459 + 0.98564736 * D)
        val L = DMath.dfixAngle(q + 1.915 * DMath.dsin(g) + 0.020 * DMath.dsin(2 * g))
        val e = 23.439 - 0.00000036 * D

        val RA = DMath.darctan2(DMath.dcos(e) * DMath.dsin(L), DMath.dcos(L)) / 15.0
        val equation = q / 15.0 - DMath.dfixHour(RA)
        val declination = DMath.darcsin(DMath.dsin(e) * DMath.dsin(L))

        return SunPosition(declination, equation)
    }

    data class SunPosition(val declination: Double, val equation: Double)

    private fun adjustTimes(times: Map<String, Double>): MutableMap<String, Double> {
        var result = times.toMutableMap()
        val params = setting

        result.keys.forEach { key ->
            result[key] = (result[key] ?: 0.0) + timeZone - lng / 15.0
        }

        if (params["highLats"] != "None") {
            result = adjustHighLats(result)
        }

        if (isMin(params["imsak"] ?: "")) {
            result["imsak"] = (result["fajr"] ?: 0.0) - eval(params["imsak"] ?: "10 min") / 60.0
        }
        if (isMin(params["maghrib"] ?: "")) {
            result["maghrib"] = (result["sunset"] ?: 0.0) + eval(params["maghrib"] ?: "0 min") / 60.0
        }
        if (isMin(params["isha"] ?: "")) {
            result["isha"] = (result["maghrib"] ?: 0.0) + eval(params["isha"] ?: "15") / 60.0
        }
        result["dhuhar"] = (result["dhuhar"] ?: 0.0) + eval(params["dhuhar"] ?: "0 min") / 60.0

        return result
    }

    private fun adjustHighLats(times: Map<String, Double>): MutableMap<String, Double> {
        val result = times.toMutableMap()
        val params = setting
        val nightTime = timeDiff(result["sunset"] ?: 18.0, result["sunrise"] ?: 6.0)

        result["imsak"] = adjustHLTime(
            result["imsak"] ?: 5.0,
            base = result["sunrise"] ?: 6.0,
            angle = eval(params["imsak"] ?: "10 min"),
            night = nightTime,
            direction = "ccw"
        )
        result["fajr"] = adjustHLTime(
            result["fajr"] ?: 5.0,
            base = result["sunrise"] ?: 6.0,
            angle = eval(params["fajr"] ?: "15"),
            night = nightTime,
            direction = "ccw"
        )
        result["isha"] = adjustHLTime(
            result["isha"] ?: 18.0,
            base = result["sunset"] ?: 18.0,
            angle = eval(params["isha"] ?: "15"),
            night = nightTime
        )
        result["maghrib"] = adjustHLTime(
            result["maghrib"] ?: 18.0,
            base = result["sunset"] ?: 18.0,
            angle = eval(params["maghrib"] ?: "0 min"),
            night = nightTime
        )

        return result
    }

    private fun adjustHLTime(time: Double, base: Double, angle: Double, night: Double, direction: String = "cw"): Double {
        val portion = nightPortion(angle, night)
        val diff = if (direction == "ccw") timeDiff(time, base) else timeDiff(base, time)
        if (time.isNaN() || diff > portion) {
            return base + (if (direction == "ccw") -portion else portion)
        }
        return time
    }

    private fun nightPortion(angle: Double, night: Double): Double {
        var portion = 1.0 / 2.0
        when (setting["highLats"]) {
            "AngleBased" -> portion = 1.0 / 60.0 * angle
            "OneSeventh" -> portion = 1.0 / 7.0
            else -> {}
        }
        return portion * night
    }

    private fun dayPortion(times: Map<String, Double>): Map<String, Double> {
        val result = mutableMapOf<String, Double>()
        times.forEach { (k, v) -> result[k] = v / 24.0 }
        return result
    }

    private fun tuneTimes(times: Map<String, Double>): MutableMap<String, Double> {
        val result = times.toMutableMap()
        offset.forEach { (key, value) ->
            result[key] = (result[key] ?: 0.0) + value / 60.0
        }
        return result
    }

    private fun modifyFormats(times: Map<String, Double>): Map<String, String> {
        val result = mutableMapOf<String, String>()
        times.forEach { (key, value) ->
            result[key] = getFormattedTime(value, timeFormat)
        }
        return result
    }

    fun getFormattedTime(time: Double, format: String = "24h"): String {
        if (time.isNaN()) return invalidTime
        if (format == "Float") return time.toString()

        val rounded = DMath.dfixHour(time + 0.5 / 60.0)
        val hours = floor(rounded).toInt()
        val minutes = floor((rounded - hours.toDouble()) * 60.0).toInt()

        val suffix = if (format == "12h") {
            if (hours < 12) "AM" else "PM"
        } else ""
        
        val hour: Int
        if (format == "24h") {
            hour = hours
        } else {
            hour = (hours + 12 - 1) % 12 + 1
        }

        val hourString = if (format == "24h") twoDigitsFormat(hour) else hour.toString()
        val minuteString = twoDigitsFormat(minutes)
        
        return if (suffix.isEmpty()) {
            "$hourString:$minuteString"
        } else {
            "$hourString:$minuteString $suffix"
        }
    }

    private fun twoDigitsFormat(num: Int): String {
        return String.format("%02d", num)
    }

    private fun asarFactor(param: String): Double {
        return when (param) {
            "Standard" -> 1.0
            "Hanafi" -> 2.0
            else -> eval(param)
        }
    }

    private fun riseSetAngle(): Double {
        val angle = 0.0347 * sqrt(elv)
        return 0.833 + angle
    }

    private fun eval(str: String): Double {
        val allowed = "0123456789.+-".toSet()
        var prefix = ""
        for (char in str) {
            if (char !in allowed) break
            prefix += char
        }
        return prefix.toDoubleOrNull() ?: 0.0
    }

    private fun isMin(arg: String): Boolean = arg.contains("min")

    private fun timeDiff(time1: Double, time2: Double): Double {
        return DMath.dfixHour(time2 - time1)
    }

    private fun julian(year: Int, month: Int, day: Int): Double {
        var y = year
        var m = month
        if (m <= 2) {
            y -= 1
            m += 12
        }
        val a = floor(y.toDouble() / 100.0)
        val b = 2.0 - a + floor(a / 4.0)
        return floor(365.25 * (y + 4716).toDouble()) +
               floor(30.6001 * (m + 1).toDouble()) +
               day.toDouble() + b - 1524.5
    }

    private object DMath {
        private fun dtr(d: Double) = d * Math.PI / 180.0
        private fun rtd(r: Double) = r * 180.0 / Math.PI

        fun dsin(d: Double) = sin(dtr(d))
        fun dcos(d: Double) = cos(dtr(d))
        fun dtan(d: Double) = tan(dtr(d))

        fun darcsin(d: Double) = rtd(asin(d))
        fun darccos(d: Double) = rtd(acos(d))
        fun darctan(d: Double) = rtd(atan(d))

        fun darccot(x: Double) = rtd(atan(1.0 / x))
        fun darctan2(y: Double, x: Double) = rtd(atan2(y, x))

        fun dfixAngle(a: Double) = dfix(a, 360.0)
        fun dfixHour(a: Double) = dfix(a, 24.0)

        fun dfix(a: Double, b: Double): Double {
            var result = a - b * floor(a / b)
            if (result < 0) result += b
            return result
        }
    }
}

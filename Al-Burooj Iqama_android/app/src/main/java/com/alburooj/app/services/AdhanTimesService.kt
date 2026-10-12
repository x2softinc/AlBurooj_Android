package com.alburooj.app.services

import com.alburooj.app.data.models.AdhanTime
import com.alburooj.app.helper.PrayTimesCalculator
import java.text.SimpleDateFormat
import java.util.*

class AdhanTimesService {

    /**
     * Calculates adhan times for a given day shift.
     * Replicated from SwiftUI AdhanTimesService.
     */
    fun calcAdhanTimes(
        dayShift: Int,
        latitude: Double,
        longitude: Double,
        school: Int, // Currently unused in Swift source
        method: String
    ): AdhanTime {
        val adhanRecord = AdhanTime()

        if (latitude == 0.0 || longitude == 0.0) {
            return adhanRecord
        }

        val date = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, dayShift)
        }.time
        
        val calculator = PrayTimesCalculator(method)
        val adhanTimes = calculator.getTimes(date, doubleArrayOf(latitude, longitude))

        // Attach the computed clock times to the requested day, not always to "today".
        val gDate = Calendar.getInstance().apply {
            time = date
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time

        adhanRecord.imsak = getFullDate(gDate, adhanTimes["imsak"] ?: "")
        adhanRecord.fajr = getFullDate(gDate, adhanTimes["fajr"] ?: "")
        adhanRecord.sunrise = getFullDate(gDate, adhanTimes["sunrise"] ?: "")
        adhanRecord.dhuhar = getFullDate(gDate, adhanTimes["dhuhar"] ?: "")
        
        // Swift: adhanRecord.zawal = adhanRecord.dhuhar?.addingTimeInterval(-600)
        adhanRecord.zawal = adhanRecord.dhuhar?.let {
            val cal = Calendar.getInstance()
            cal.time = it
            cal.add(Calendar.SECOND, -600)
            cal.time
        }

        adhanRecord.asar = getFullDate(gDate, adhanTimes["asar"] ?: "")
        adhanRecord.asarHanafi = getFullDate(gDate, adhanTimes["asarHanafi"] ?: "")
        adhanRecord.sunset = getFullDate(gDate, adhanTimes["sunset"] ?: "")
        adhanRecord.maghrib = getFullDate(gDate, adhanTimes["maghrib"] ?: "")
        adhanRecord.isha = getFullDate(gDate, adhanTimes["isha"] ?: "")
        adhanRecord.midnight = getFullDate(gDate, adhanTimes["midnight"] ?: "")

        return adhanRecord
    }

    private fun getFullDate(refDate: Date, timeString: String): Date? {
        if (timeString.isEmpty()) return null
        
        val sdf = SimpleDateFormat("HH:mm", Locale.US)
        val timeDate = sdf.parse(timeString) ?: return null

        val cal = Calendar.getInstance()
        cal.time = timeDate
        val hour = cal.get(Calendar.HOUR_OF_DAY)
        val minute = cal.get(Calendar.MINUTE)

        val resultCal = Calendar.getInstance()
        resultCal.time = refDate
        resultCal.set(Calendar.HOUR_OF_DAY, hour)
        resultCal.set(Calendar.MINUTE, minute)
        resultCal.set(Calendar.SECOND, 0)
        resultCal.set(Calendar.MILLISECOND, 0)
        
        return resultCal.time
    }
}

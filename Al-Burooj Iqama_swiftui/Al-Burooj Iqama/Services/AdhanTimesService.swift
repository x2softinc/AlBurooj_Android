//
//  AdhanService.swift
//  Al-Burooj Iqama Times
//
//  Created by Shiha on 12/2/18.
//  Copyright © 2018 Trendsoft Inc. All rights reserved.
//

import Foundation

private let locale = "en_US_POSIX"

fileprivate func getShortDate(inDate: Date) -> Date {
    return Calendar.current.startOfDay(for: inDate)
}

fileprivate func getFullDate(refDate: Date, timeString: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: locale)
    formatter.dateFormat = "HH:mm"
    guard let timeDate = formatter.date(from: timeString) else { return nil }

    let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: timeDate)
    return Calendar.current.date(bySettingHour: timeComponents.hour ?? 0,
                                 minute: timeComponents.minute ?? 0,
                                 second: 0,
                                 of: refDate)
}

class AdhanTimesService {

    func calcAdhanTimes(
        _ dayShift: Int,
        latitude: Double,
        longitude: Double,
        school: Int,
        method: String,
        completion: @escaping (AdhanTime) -> Void
    ) {
        var adhanRecord = AdhanTime()
        _ = school

        guard latitude != 0.0, longitude != 0.0 else {
            completion(adhanRecord)
            return
        }

        let date = Calendar.current.date(byAdding: .day, value: dayShift, to: Date()) ?? Date()
        let calculator = PrayTimesCalculator(method: method)
        let adhanTimes = calculator.getTimes(date: date, coordinates: [latitude, longitude])

        // Attach the computed clock times to the requested day, not always to "today".
        let gDate = getShortDate(inDate: date)

        adhanRecord.imsak = getFullDate(refDate: gDate, timeString: adhanTimes["imsak"] ?? "")
        adhanRecord.fajr = getFullDate(refDate: gDate, timeString: adhanTimes["fajr"] ?? "")
        adhanRecord.sunrise = getFullDate(refDate: gDate, timeString: adhanTimes["sunrise"] ?? "")
        adhanRecord.dhuhar = getFullDate(refDate: gDate, timeString: adhanTimes["dhuhar"] ?? "")
        adhanRecord.zawal = adhanRecord.dhuhar?.addingTimeInterval(-600)
        adhanRecord.asar = getFullDate(refDate: gDate, timeString: adhanTimes["asar"] ?? "")
        adhanRecord.asarHanafi = getFullDate(refDate: gDate, timeString: adhanTimes["asarHanafi"] ?? "")
        adhanRecord.sunset = getFullDate(refDate: gDate, timeString: adhanTimes["sunset"] ?? "")
        adhanRecord.maghrib = getFullDate(refDate: gDate, timeString: adhanTimes["maghrib"] ?? "")
        adhanRecord.isha = getFullDate(refDate: gDate, timeString: adhanTimes["isha"] ?? "")
        adhanRecord.midnight = getFullDate(refDate: gDate, timeString: adhanTimes["midnight"] ?? "")

        completion(adhanRecord)
    }
}

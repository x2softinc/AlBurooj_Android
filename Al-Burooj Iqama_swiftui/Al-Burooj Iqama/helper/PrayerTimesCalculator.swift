//
//  PrayerTimesCalculator.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/30/26.
//

import Foundation

/// Swift port of PrayTimes.js v2.3
final class PrayTimesCalculator {

    // MARK: - Calculation methods

    private static let methods: [String: [String: String]] = [
        "MWL": ["fajr": "18", "isha": "17"],
        "ISNA": ["fajr": "15", "isha": "15"],
        "EGAS": ["fajr": "19.5", "isha": "17.5"],
        "UQUM": ["fajr": "18.5", "isha": "90 min"],
        "UISK": ["fajr": "18", "isha": "18"],
        "MUIS": ["fajr": "20", "isha": "18"],
        "TEH": ["fajr": "17.7", "isha": "14", "maghrib": "4.5", "midnight": "Jafari"],
        "JAF": ["fajr": "16", "isha": "14", "maghrib": "4", "midnight": "Jafari"]
    ]

    private static let defaultParams: [String: String] = [
        "maghrib": "0 min",
        "midnight": "Standard"
    ]

    private static let timeNames = [
        "imsak", "fajr", "sunrise", "dhuhar", "asar", "asarHanafi",
        "sunset", "maghrib", "isha", "midnight"
    ]

    // MARK: - State

    private var calcMethod: String
    private var setting: [String: String] = [
        "imsak": "10 min",
        "dhuhar": "0 min",
        "asar": "Standard",
        "highLats": "NightMiddle"
    ]
    private var timeFormat = "24h"
    private let invalidTime = "-----"
    private let numIterations = 1
    private var offset: [String: Double] = [:]

    private var lat = 0.0
    private var lng = 0.0
    private var elv = 0.0
    private var timeZone = 0.0
    private var jDate = 0.0

    init(method: String) {
        let methodKey = Self.methods[method] != nil ? method : "MWL"
        calcMethod = methodKey

        var params = Self.methods[methodKey] ?? [:]
        for (key, value) in Self.defaultParams {
            if params[key] == nil {
                params[key] = value
            }
        }

        for (key, value) in params {
            setting[key] = value
        }

        for name in Self.timeNames {
            offset[name] = 0
        }
    }

    // MARK: - Public

    func getTimes(
        date: Date,
        coordinates: [Double],
        timeZone: Double? = nil,
        dst: Bool? = nil,
        format: String = "24h"
    ) -> [String: String] {
        lat = coordinates[0]
        lng = coordinates[1]
        elv = coordinates.count > 2 ? coordinates[2] : 0
        self.timeFormat = format

        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return [:]
        }

        let resolvedTimeZone = timeZone ?? Self.standardTimeZone(for: date)
        let resolvedDST = dst ?? (Self.gmtOffset(for: date) != Self.standardTimeZone(for: date))
        self.timeZone = resolvedTimeZone + (resolvedDST ? 1 : 0)

        jDate = Self.julian(year: year, month: month, day: day) - lng / (15.0 * 24.0)

        let computed = computeTimes()
        return modifyFormats(computed)
    }

    // MARK: - Time zone helpers

    private static func gmtOffset(for date: Date) -> Double {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = 12
        let noon = calendar.date(from: comps) ?? date
        return Double(TimeZone.current.secondsFromGMT(for: noon)) / 3600.0
    }

    private static func standardTimeZone(for date: Date) -> Double {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let january = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? date
        let july = calendar.date(from: DateComponents(year: year, month: 7, day: 1)) ?? date
        return min(gmtOffset(for: january), gmtOffset(for: july))
    }

    // MARK: - Core calculations

    private func computeTimes() -> [String: Double] {
        var times: [String: Double] = [
            "imsak": 5, "fajr": 5, "sunrise": 6, "dhuhar": 12,
            "asar": 13, "sunset": 18, "maghrib": 18, "isha": 18
        ]

        for _ in 1...numIterations {
            times = computePrayerTimes(times)
        }

        var adjusted = adjustTimes(times)

        let sunset = adjusted["sunset"] ?? 18
        let sunrise = adjusted["sunrise"] ?? 6
        let fajr = adjusted["fajr"] ?? 5

        adjusted["midnight"] = setting["midnight"] == "Jafari"
            ? sunset + timeDiff(sunset, fajr) / 2
            : sunset + timeDiff(sunset, sunrise) / 2

        return tuneTimes(adjusted)
    }

    private func computePrayerTimes(_ times: [String: Double]) -> [String: Double] {
        let portions = dayPortion(times)
        let params = setting

        let imsak = sunAngleTime(eval(params["imsak"] ?? "10 min"), time: portions["imsak"] ?? 5, direction: "ccw")
        let fajr = sunAngleTime(eval(params["fajr"] ?? "15"), time: portions["fajr"] ?? 5, direction: "ccw")
        let sunrise = sunAngleTime(riseSetAngle(), time: portions["sunrise"] ?? 6, direction: "ccw")
        let dhuhar = midDay(portions["dhuhar"] ?? 12)
        let asar = asrTime(asarFactor(params["asar"] ?? "Standard"), time: portions["asar"] ?? 13)
        let asarHanafi = asrTime(asarFactor("Hanafi"), time: portions["asar"] ?? 13)
        let sunset = sunAngleTime(riseSetAngle(), time: portions["sunset"] ?? 18)
        let maghrib = sunAngleTime(eval(params["maghrib"] ?? "0 min"), time: portions["maghrib"] ?? 18)
        let isha = sunAngleTime(eval(params["isha"] ?? "15"), time: portions["isha"] ?? 18)

        return [
            "imsak": imsak,
            "fajr": fajr,
            "sunrise": sunrise,
            "dhuhar": dhuhar,
            "asar": asar,
            "asarHanafi": asarHanafi,
            "sunset": sunset,
            "maghrib": maghrib,
            "isha": isha
        ]
    }

    private func midDay(_ time: Double) -> Double {
        DMath.dfixHour(12 - sunPosition(jDate + time).equation)
    }

    private func sunAngleTime(_ angle: Double, time: Double, direction: String = "cw") -> Double {
        let decl = sunPosition(jDate + time).declination
        let noon = midDay(time)
        let t = 1.0 / 15.0 * DMath.darccos(
            (-DMath.dsin(angle) - DMath.dsin(decl) * DMath.dsin(lat)) /
            (DMath.dcos(decl) * DMath.dcos(lat))
        )
        return direction == "ccw" ? noon - t : noon + t
    }

    private func asrTime(_ factor: Double, time: Double) -> Double {
        let decl = sunPosition(jDate + time).declination
        let angle = -DMath.darccot(factor + DMath.dtan(abs(lat - decl)))
        return sunAngleTime(angle, time: time)
    }

    private func sunPosition(_ jd: Double) -> (declination: Double, equation: Double) {
        let D = jd - 2451545.0
        let g = DMath.dfixAngle(357.529 + 0.98560028 * D)
        let q = DMath.dfixAngle(280.459 + 0.98564736 * D)
        let L = DMath.dfixAngle(q + 1.915 * DMath.dsin(g) + 0.020 * DMath.dsin(2 * g))
        let e = 23.439 - 0.00000036 * D

        let RA = DMath.darctan2(DMath.dcos(e) * DMath.dsin(L), DMath.dcos(L)) / 15.0
        let equation = q / 15.0 - DMath.dfixHour(RA)
        let declination = DMath.darcsin(DMath.dsin(e) * DMath.dsin(L))

        return (declination, equation)
    }

    // MARK: - Adjustments

    private func adjustTimes(_ times: [String: Double]) -> [String: Double] {
        var result = times
        let params = setting

        for key in result.keys {
            result[key]? += timeZone - lng / 15.0
        }

        if params["highLats"] != "None" {
            result = adjustHighLats(result)
        }

        if isMin(params["imsak"] ?? "") {
            result["imsak"] = (result["fajr"] ?? 0) - eval(params["imsak"] ?? "10 min") / 60.0
        }
        if isMin(params["maghrib"] ?? "") {
            result["maghrib"] = (result["sunset"] ?? 0) + eval(params["maghrib"] ?? "0 min") / 60.0
        }
        if isMin(params["isha"] ?? "") {
            result["isha"] = (result["maghrib"] ?? 0) + eval(params["isha"] ?? "15") / 60.0
        }
        result["dhuhar"] = (result["dhuhar"] ?? 0) + eval(params["dhuhar"] ?? "0 min") / 60.0

        return result
    }

    private func adjustHighLats(_ times: [String: Double]) -> [String: Double] {
        var result = times
        let params = setting
        let nightTime = timeDiff(result["sunset"] ?? 18, result["sunrise"] ?? 6)

        result["imsak"] = adjustHLTime(
            result["imsak"] ?? 5,
            base: result["sunrise"] ?? 6,
            angle: eval(params["imsak"] ?? "10 min"),
            night: nightTime,
            direction: "ccw"
        )
        result["fajr"] = adjustHLTime(
            result["fajr"] ?? 5,
            base: result["sunrise"] ?? 6,
            angle: eval(params["fajr"] ?? "15"),
            night: nightTime,
            direction: "ccw"
        )
        result["isha"] = adjustHLTime(
            result["isha"] ?? 18,
            base: result["sunset"] ?? 18,
            angle: eval(params["isha"] ?? "15"),
            night: nightTime
        )
        result["maghrib"] = adjustHLTime(
            result["maghrib"] ?? 18,
            base: result["sunset"] ?? 18,
            angle: eval(params["maghrib"] ?? "0 min"),
            night: nightTime
        )

        return result
    }

    private func adjustHLTime(_ time: Double, base: Double, angle: Double, night: Double, direction: String = "cw") -> Double {
        let portion = nightPortion(angle, night: night)
        let diff = direction == "ccw" ? timeDiff(time, base) : timeDiff(base, time)
        if time.isNaN || diff > portion {
            return base + (direction == "ccw" ? -portion : portion)
        }
        return time
    }

    private func nightPortion(_ angle: Double, night: Double) -> Double {
        var portion = 1.0 / 2.0
        switch setting["highLats"] {
        case "AngleBased":
            portion = 1.0 / 60.0 * angle
        case "OneSeventh":
            portion = 1.0 / 7.0
        default:
            break
        }
        return portion * night
    }

    // MARK: - Formatting

    private func dayPortion(_ times: [String: Double]) -> [String: Double] {
        var result = times
        for key in result.keys {
            result[key]? /= 24.0
        }
        return result
    }

    private func tuneTimes(_ times: [String: Double]) -> [String: Double] {
        var result = times
        for (key, value) in offset {
            if result[key] != nil {
                result[key]? += value / 60.0
            }
        }
        return result
    }

    private func modifyFormats(_ times: [String: Double]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in times {
            result[key] = getFormattedTime(value, format: timeFormat)
        }
        return result
    }

    func getFormattedTime(_ time: Double, format: String = "24h") -> String {
        if time.isNaN {
            return invalidTime
        }
        if format == "Float" {
            return String(time)
        }

        let rounded = DMath.dfixHour(time + 0.5 / 60.0)
        let hours = Int(floor(rounded))
        let minutes = Int(floor((rounded - Double(hours)) * 60.0))

        let suffix = format == "12h" ? (hours < 12 ? "AM" : "PM") : ""
        let hour: Int
        if format == "24h" {
            hour = hours
        } else {
            hour = (hours + 12 - 1) % 12 + 1
        }

        let hourString = format == "24h" ? twoDigitsFormat(hour) : String(hour)
        let minuteString = twoDigitsFormat(minutes)
        return suffix.isEmpty ? "\(hourString):\(minuteString)" : "\(hourString):\(minuteString) \(suffix)"
    }

    private func twoDigitsFormat(_ num: Int) -> String {
        String(format: "%02d", num)
    }

    // MARK: - Utility

    private func asarFactor(_ param: String) -> Double {
        switch param {
        case "Standard": return 1
        case "Hanafi": return 2
        default: return eval(param)
        }
    }

    private func riseSetAngle() -> Double {
        let angle = 0.0347 * sqrt(elv)
        return 0.833 + angle
    }

    private func eval(_ str: String) -> Double {
        let allowed = CharacterSet(charactersIn: "0123456789.+-")
        var prefix = ""
        for scalar in str.unicodeScalars {
            guard allowed.contains(scalar) else { break }
            prefix.unicodeScalars.append(scalar)
        }
        return Double(prefix) ?? 0
    }

    private func isMin(_ arg: String) -> Bool {
        arg.contains("min")
    }

    private func timeDiff(_ time1: Double, _ time2: Double) -> Double {
        DMath.dfixHour(time2 - time1)
    }

    private static func julian(year: Int, month: Int, day: Int) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let A = floor(Double(y) / 100.0)
        let B = 2.0 - A + floor(A / 4.0)
        return floor(365.25 * (Double(y) + 4716)) +
               floor(30.6001 * (Double(m) + 1)) +
               Double(day) + B - 1524.5
    }
}

// MARK: - Degree math

private enum DMath {
    static func dtr(_ d: Double) -> Double { d * .pi / 180.0 }
    static func rtd(_ r: Double) -> Double { r * 180.0 / .pi }

    static func dsin(_ d: Double) -> Double { sin(dtr(d)) }
    static func dcos(_ d: Double) -> Double { cos(dtr(d)) }
    static func dtan(_ d: Double) -> Double { tan(dtr(d)) }

    static func darcsin(_ d: Double) -> Double { rtd(asin(d)) }
    static func darccos(_ d: Double) -> Double { rtd(acos(d)) }
    static func darctan(_ d: Double) -> Double { rtd(atan(d)) }

    static func darccot(_ x: Double) -> Double { rtd(atan(1.0 / x)) }
    static func darctan2(_ y: Double, _ x: Double) -> Double { rtd(atan2(y, x)) }

    static func dfixAngle(_ a: Double) -> Double { dfix(a, 360) }
    static func dfixHour(_ a: Double) -> Double { dfix(a, 24) }

    static func dfix(_ a: Double, _ b: Double) -> Double {
        var result = a - b * floor(a / b)
        if result < 0 { result += b }
        return result
    }
}

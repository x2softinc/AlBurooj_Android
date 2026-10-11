import Foundation

/// Daily prayer time model.
/// Converted from the Kotlin `DailyAdhanTimeStrings` data class.
/// Uses `Date?` because the rest of the app stores prayer times as `Date`.
/// `Codable` so it can still be encoded/decoded with JSONEncoder/JSONDecoder.
struct AdhanTime: Codable {
    var fajr: Date? = nil
    var imsak: Date? = nil
    var sunrise: Date? = nil
    var dhuhar: Date? = nil
    var asar: Date? = nil
    var asarHanafi: Date? = nil
    var maghrib: Date? = nil
    var sunset: Date? = nil
    var isha: Date? = nil
    var midnight: Date? = nil
    var zawal: Date? = nil
}

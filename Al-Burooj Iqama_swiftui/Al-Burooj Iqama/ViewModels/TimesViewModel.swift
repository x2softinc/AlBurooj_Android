import Foundation
import SwiftUI
import Combine

class TimesViewModel: ObservableObject {
    @AppStorage(ANNUAL_TIMES) private var annualTimesData = Data()
    @AppStorage(ANNUAL_TIMES_LAST_FETCH) private var lastAnnualTimesRefresh: String = ""
    @AppStorage(PRAYER_SETTINGS) private var prayerSettingsData = Data()

    @Published var adhanTimes: AdhanTime = AdhanTime()
    @Published var iqamaTimesString: AnnualTime?
    @Published var iqamaTimes: IqamaTime?
    @Published var isLoading = false
    @Published private(set) var displayedDayOffset = 0
    @Published private(set) var hasLoaded = false
    @Published private(set) var settings: PrayerSetting?

    private let calendar = Calendar.current

    private var maghribDelayMinutes: Int {
        guard !prayerSettingsData.isEmpty,
              let settings = try? JSONDecoder().decode(PrayerSetting.self, from: prayerSettingsData)
        else { return 3 } // fallback default
        return settings.maghribDelay
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }

    @MainActor
    func load(dayOffset: Int = 0) async {
        isLoading = true
        displayedDayOffset = dayOffset

        await fetchAdhanTimes(dayOffset)
        await fetchAnnualTimesIfNeeded()
        extractIqamaTimes(dayOffset: dayOffset)
        await fetchPrayerSettings()
        isLoading = false
        hasLoaded = true
    }

    @MainActor
    func fetchAdhanTimes(_ dayShift: Int = 0) async {
        let latitude = UserDefaults.standard.double(forKey: LATT)
        let longitude = UserDefaults.standard.double(forKey: LONG)
        let school = UserDefaults.standard.integer(forKey: JURISDICTION)
        let method = UserDefaults.standard.string(forKey: CALC_METH) ?? "ISNA"

        await withCheckedContinuation { continuation in
            AdhanTimesService().calcAdhanTimes(dayShift, latitude: latitude, longitude: longitude, school: school, method: method) { times in
                DispatchQueue.main.async {
                    self.adhanTimes = times
                    continuation.resume()
                }
            }
        }
    }
    
    @MainActor
    func fetchPrayerSettings() async {
        let service = PrayerSettingsService()
          settings = try? await service.fetchPrayerSettings()
    }

    @MainActor
    func fetchAnnualTimesIfNeeded() async {
        let today = calendar.startOfDay(for: Date())
        let todayString = ISO8601DateFormatter().string(from: today)
        if annualTimesData.isEmpty {
            await refreshAnnualTimes()
        } else if lastAnnualTimesRefresh != todayString {
            await refreshAnnualTimes()
        }
        // Else: already refreshed today, use cached.
    }

    @MainActor
    private func refreshAnnualTimes() async {
        do {
            let service = IqamaTimesService()
            let times = try await service.fetchIqamaTimes()
            annualTimesData = try JSONEncoder().encode(times)
            let today = calendar.startOfDay(for: Date())
            lastAnnualTimesRefresh = ISO8601DateFormatter().string(from: today)
        } catch {
            // Handle error (already published as @AppStorage, so fallback to cache)
        }
    }

    func extractIqamaTimes(dayOffset: Int = 0) {
        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: today) ?? today
        extractIqamaTimes(for: targetDay)
    }

    func extractTodaysIqamaTimes() {
        extractIqamaTimes(dayOffset: 0)
    }

    private func extractIqamaTimes(for date: Date) {
        iqamaTimes = IqamaTime()
        guard let annualArray = try? JSONDecoder().decode([AnnualTime].self, from: annualTimesData) else {
            iqamaTimes = IqamaTime()
            return
        }

        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        iqamaTimesString = annualArray.first(where: { ($0.month == month) && ($0.fromDay ?? 0 <= day) && ($0.toDay ?? 0 >= day) })

        iqamaTimes?.fajr = parseTime(iqamaTimesString?.fajrTime, on: date)
        iqamaTimes?.dhuhar = parseTime(iqamaTimesString?.dhuharTime, on: date)
        iqamaTimes?.asar = parseTime(iqamaTimesString?.asrTime, on: date)

        if let maghribAdhan = adhanTimes.maghrib {
            iqamaTimes?.maghrib = calendar.date(
                byAdding: .minute,
                value: maghribDelayMinutes,
                to: maghribAdhan
            )
        } else {
            iqamaTimes?.maghrib = parseTime(iqamaTimesString?.maghribTime, on: date)
        }

        iqamaTimes?.isha = parseTime(iqamaTimesString?.ishaTime, on: date)
    }

    private func parseTime(_ timeString: String?, on date: Date) -> Date? {
        guard let timeString = timeString else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        formatter.defaultDate = calendar.startOfDay(for: date)
        return formatter.date(from: timeString)
    }

    // MARK: - Iqama helpers

    private func iqamaDate(for prayerName: String) -> Date? {
        guard let iqamaTimes = self.iqamaTimes else { return nil }

        switch prayerName {
        case "Fajr":
            return iqamaTimes.fajr
        case "Dhuhar", "Dhuhr":
            return iqamaTimes.dhuhar
        case "Asar", "Asr":
            return iqamaTimes.asar
        case "Maghrib":
            return iqamaTimes.maghrib
        case "Isha":
            return iqamaTimes.isha
        default:
            return nil
        }
    }

    public func iqamaTime(for name: String) -> String {
        guard let time = iqamaDate(for: name) else { return "" }
        return timeFormatter.string(from: time)
    }

    public func currentPrayerInfo() -> (name: String, adhan: Date, iqama: Date)? {
        let now = Date()

        let fajr = adhanTimes.fajr
        let dhuhar = adhanTimes.dhuhar
        let asar = adhanTimes.asar
        let maghrib = adhanTimes.maghrib
        let isha = adhanTimes.isha
        let sunrise = adhanTimes.sunrise

        // The midnight time is stored as a time-of-day on today's Date.
        // If it occurs after sunset and before Fajr, it belongs to the next day,
        // so use tomorrow's midnight as the end of the Isha window.
        var ishaEnd = adhanTimes.midnight
        if let isha, let midnight = ishaEnd, midnight < isha {
            ishaEnd = calendar.date(byAdding: .day, value: 1, to: midnight)
        }

        let windows: [(name: String, start: Date?, end: Date?)] = [
            ("Fajr", fajr, sunrise),
            ("Dhuhar", dhuhar, asar),
            ("Asar", asar, maghrib),
            ("Maghrib", maghrib, isha),
            ("Isha", isha, ishaEnd)
        ]

        for window in windows {
            guard let start = window.start,
                  let end = window.end,
                  now >= start,
                  now < end
            else { continue }

            return (window.name, start, iqamaDate(for: window.name) ?? start)
        }

        return nil
    }

    public func countdownInfo(now: Date, adhan: Date, iqama: Date, nextAdhan: Date?) -> (countdown: String, countdownLabel: String) {
        if now < adhan {
            let interval = adhan.timeIntervalSince(now)
            return (formatInterval(interval), "Until Adhan")
        } else if now >= adhan && now < iqama {
            let interval = iqama.timeIntervalSince(now)
            return (formatInterval(interval), "Until Iqama")
        } else if let nextAdhan = nextAdhan, now >= iqama && now < nextAdhan {
            let interval = nextAdhan.timeIntervalSince(now)
            return (formatInterval(interval), "Until Next Adhan")
        } else if now >= iqama {
            let interval = now.timeIntervalSince(iqama)
            return (formatInterval(interval), "Since Iqama")
        } else {
            return ("", "")
        }
    }

    public func formatInterval(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = (totalSeconds % 60)
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

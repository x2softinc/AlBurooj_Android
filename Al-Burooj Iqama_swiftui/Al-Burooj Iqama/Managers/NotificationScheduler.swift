import Foundation
import UserNotifications
import SwiftUI


final class NotificationScheduler {

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard

    private var adhanIdentifiers: [String] {
        [Fajr, Dhuhar, Asar, Maghrib, Isha].map { "adhan-\($0)" }
    }

    private var iqamaIdentifiers: [String] {
        [Fajr, Dhuhar, Asar, Maghrib, Isha].map { "iqama-\($0)" }
    }

    private var allIdentifiers: [String] {
        adhanIdentifiers + iqamaIdentifiers
    }

    /// Rebuilds notifications based on current settings.
    func syncNotifications() async {
        guard defaults.bool(forKey: NOTIFICATION_ENABLED) else {
            center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
            return
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else {
            center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
            return
        }

        if defaults.bool(forKey: NOTIFY_ADHAN) {
            await scheduleAdhanNotifications()
        } else {
            center.removePendingNotificationRequests(withIdentifiers: adhanIdentifiers)
        }

        if defaults.bool(forKey: NOTIFY_IQAMA) {
            await scheduleIqamaNotifications()
        } else {
            center.removePendingNotificationRequests(withIdentifiers: iqamaIdentifiers)
        }
    }

    /// Kept for compatibility with the earlier Adhan-only call sites.
    func syncAdhanNotifications() async {
        await syncNotifications()
    }

    // MARK: - Adhan

    private func scheduleAdhanNotifications() async {
        center.removePendingNotificationRequests(withIdentifiers: adhanIdentifiers)
        
        @AppStorage(CITY)   var city = ""

        let latitude = defaults.double(forKey: LATT)
        let longitude = defaults.double(forKey: LONG)
        guard latitude != 0, longitude != 0 else { return }

        let method = defaults.string(forKey: CALC_METH) ?? "ISNA"
        let jurisdiction = defaults.integer(forKey: JURISDICTION)

        let times: AdhanTime = await withCheckedContinuation { continuation in
            AdhanTimesService().calcAdhanTimes(
                0,
                latitude: latitude,
                longitude: longitude,
                school: jurisdiction,
                method: method
            ) { adhanTimes in
                continuation.resume(returning: adhanTimes)
            }
        }

        let prayers: [(name: String, time: Date?)] = [
            (Fajr, times.fajr),
            (Dhuhar, times.dhuhar),
            (Asar, times.asar),
            (Maghrib, times.maghrib),
            (Isha, times.isha)
        ]

        await scheduleRepeatingNotifications(
            prayers: prayers,
            identifierPrefix: "adhan",
            title: "Adhan",
            subTitle: city
            
        )
    }

    // MARK: - Iqama

    private func scheduleIqamaNotifications() async {
        center.removePendingNotificationRequests(withIdentifiers: iqamaIdentifiers)

        guard let iqamaTimes = await todaysIqamaTimes() else { return }

        let prayers: [(name: String, time: Date?)] = [
            (Fajr, iqamaTimes.fajr),
            (Dhuhar, iqamaTimes.dhuhar),
            (Asar, iqamaTimes.asar),
            // Maghrib Iqama is intentionally left out of notifications.
            (Isha, iqamaTimes.isha)
        ]

        await scheduleRepeatingNotifications(
            prayers: prayers,
            identifierPrefix: "iqama",
            title: "Iqama"
        )
    }

    private func todaysIqamaTimes() async -> IqamaTime? {
        let today = Calendar.current.startOfDay(for: Date())

        if let times = decodeIqamaTimes(on: today) {
            return times
        }

        // Try refreshing from the server only if today’s schedule is not cached.
        do {
            _ = try await IqamaTimesService().fetchIqamaTimes()
        } catch {
            // Fall back to whatever annual times are already stored.
        }

        return decodeIqamaTimes(on: today)
    }

    private func decodeIqamaTimes(on date: Date) -> IqamaTime? {
        guard let data = defaults.data(forKey: ANNUAL_TIMES),
              !data.isEmpty,
              let records = try? JSONDecoder().decode([AnnualTime].self, from: data) else {
            return nil
        }

        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        guard let record = records.first(where: {
            $0.month == month &&
            ($0.fromDay ?? 0) <= day &&
            ($0.toDay ?? 0) >= day
        }) else {
            return nil
        }

        var times = IqamaTime()
        times.fajr = parseIqamaTime(record.fajrTime, on: date)
        times.dhuhar = parseIqamaTime(record.dhuharTime, on: date)
        times.asar = parseIqamaTime(record.asrTime, on: date)
        // Maghrib is intentionally not used for Iqama notifications.
        times.isha = parseIqamaTime(record.ishaTime, on: date)

        return times
    }

    private func parseIqamaTime(_ raw: String?, on date: Date) -> Date? {
        guard let raw = raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.defaultDate = date
        formatter.dateFormat = FromFormatIqama

        if let time = formatter.date(from: raw) {
            return time
        }

        // Some annual time strings may be "HH:mm" instead of "HH:mm:ss".
        formatter.dateFormat = FromFormatAdhan
        return formatter.date(from: raw)
    }

    // MARK: - Shared scheduling

    private func scheduleRepeatingNotifications(
        prayers: [(name: String, time: Date?)],
        identifierPrefix: String,
        title: String, subTitle: String? = nil
    ) async {
        for prayer in prayers {
            guard let date = prayer.time else { continue }

            let content = UNMutableNotificationContent()
            content.title = title
            content.subtitle = subTitle ?? ""
            content.body = "\(title) time for \(prayer.name) prayer."
            
            // Use custom adhan sound for adhan notifications, default for iqama
            if identifierPrefix == "adhan" {
                let selectedSound = defaults.string(forKey: AdhanSoundPreference.storageKey) ?? AdhanSoundOption.systemDefault.rawValue
                if let soundOption = AdhanSoundOption(rawValue: selectedSound) {
                    content.sound = soundOption.notificationSound
                } else {
                    content.sound = .default
                }
            } else {
                content.sound = .default
            }

            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)-\(prayer.name)",
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                print("Failed to schedule \(title) for \(prayer.name): \(error)")
            }
        }
    }
}

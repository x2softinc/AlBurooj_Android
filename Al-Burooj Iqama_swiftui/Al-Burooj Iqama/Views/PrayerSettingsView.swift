import SwiftUI

struct PrayerSettingsView: View {
    @AppStorage(PRAYER_SETTINGS) private var prayerSettingsData = Data()

    @State private var isLoading = false
    @State private var currentError: UserFriendlyError?

    private let accentColor = Color(red: 0.0, green: 0.6, blue: 0.8)

    private var prayerSettings: PrayerSetting? {
        guard !prayerSettingsData.isEmpty else { return nil }
        return try? JSONDecoder().decode(PrayerSetting.self, from: prayerSettingsData)
    }

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Loading prayer settings…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                settingsCard
            }
        }
        .padding()
        .navigationTitle("Prayer Settings")
        .userFriendlyAlert(error: $currentError)
        .task {
            await loadSettings()
        }
    }

    private var settingsCard: some View {
        let settings = prayerSettings

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.2.fill")
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(accentColor.opacity(0.15))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prayer Settings")
                        .font(.title3.weight(.semibold))
                    Text("Synced from server")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            settingRow("Calculation Method", value: settings?.calcMethod ?? "MWL")
            settingRow("Maintenance Method", value: String(settings?.maintMethod ?? 0))
            settingRow("Jumma Time", value: displayTime(settings?.jumma ?? ""))
            settingRow("Jumma 2 Time", value: displayTime(settings?.jumma2 ?? ""))
            settingRow("Asr Method", value: String(settings?.asrMethod ?? 0))
            settingRow("Hijri Adjustment", value: String(settings?.hijriAdjustment ?? 0))
            settingRow("Round Minutes", value: String(settings?.roundMinutes ?? 0))

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Maghrib Delays (minutes)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                settingRow("Maghrib Delay (min)", value: String(settings?.maghribDelay ?? 3))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    private func settingRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private func displayTime(_ raw: String) -> String {
        guard !raw.isEmpty else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        if let date = formatter.date(from: raw) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "en_US_POSIX")
            display.dateFormat = "hh:mm a"
            return display.string(from: date)
        }
        return raw
    }

    private func loadSettings() async {
        isLoading = true
        currentError = nil
        do {
            _ = try await PrayerSettingsService().fetchPrayerSettings()
        } catch let error as UserFriendlyError {
            currentError = error
        } catch {
            currentError = .dataLoading(feature: "Prayer Settings") {
                await self.loadSettings()
            }
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        PrayerSettingsView()
    }
}

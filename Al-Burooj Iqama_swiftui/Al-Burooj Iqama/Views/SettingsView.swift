import SwiftUI
import UIKit
import UserNotifications
import AVFoundation

private struct SettingsValueRow: View {
    let title: String
    let value: String
    var valueColor: Color = .secondary
    var monospacedValue = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
            Spacer()
            Text(value)
                .font(monospacedValue ? .system(.body, design: .monospaced) : .body)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SettingsView: View {
    // Prayer-time calculation preferences stored locally on this device
    @AppStorage(CALC_METH) private var calculationMethod = "ISNA"
    @AppStorage(JURISDICTION) private var jurisdiction = 0

    // Current location preferences
    @AppStorage(LATT) private var latitude = 0.0
    @AppStorage(LONG) private var longitude = 0.0
    @AppStorage(CITY) private var city = ""

    // App access / authentication state
    @AppStorage(AUTH_TOKEN) private var authToken = ""

    // Notification preferences
    @AppStorage(NOTIFICATION_ENABLED) private var notificationsEnabled = false
    @AppStorage(NOTIFY_ADHAN) private var notifyAdhan = false
    @AppStorage(NOTIFY_IQAMA) private var notifyIqama = false
    @AppStorage(AdhanSoundPreference.storageKey)
    private var selectedAdhanSound = AdhanSoundOption.systemDefault.rawValue

    @State private var isReconnecting = false
    @State private var activeAlert: SettingsAlert?

    private let calculationMethods = [
        "ISNA": "Islamic Society of North America",
        "MWL": "Muslim World League",
        "EGAS": "Egiptian General Authority of Survey",
        "UQUM": "Ummul Qura - Makkah",
        "UISK": "United Islamic Science, Karachi",
        "MUIS": "Majilis Ugama Islam Singapura",
        "TEH": "Institute of Geophysics, University of Tehran",
        "JAF": "Jafari"
    ]

    private let authService = AuthService()

    var body: some View {
        List {
            versionInfoSection
            adhanSettingsSection
            notificationsSection
            appAccessSection
            supportSection
            legalSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color("themeColor"))
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .notificationsDenied:
                return Alert(
                    title: Text("Notifications Not Authorized"),
                    message: Text("Allow notifications in System Settings to receive prayer reminders."),
                    primaryButton: .default(Text("Open Settings")) {
                        openSystemSettings()
                    },
                    secondaryButton: .cancel()
                )
            case .reconnectFailed(let message):
                return Alert(
                    title: Text("Unable to Reconnect"),
                    message: Text(message)
                )
            }
        }
        .task {
            await NotificationScheduler().syncNotifications()
        }
    }

    // MARK: - Version Info

    private var versionInfoSection: some View {
        Section {
            SettingsValueRow(title: "App", value: appName)
            SettingsValueRow(title: "Version / Build", value: appVersion + " / " + buildNumber)

            Button {
                openAppStore()
            } label: {
                Label("Check for Updates", systemImage: "arrow.down.circle")
            }
        } header: {
            Label("Version Info", systemImage: "info.circle.fill")
        }
    }

    // MARK: - Adhan Settings

    private var adhanSettingsSection: some View {
        Section {
            Picker("Calculation Method", selection: $calculationMethod) {
                ForEach(calculationMethods.sorted { $0.value < $1.value }, id: \.key) { method in
                    Text(method.value).tag(method.key)
                }
            }

            Picker("Asr Jurisdiction", selection: $jurisdiction) {
                Text("Standard").tag(0)
                Text("Hanafi").tag(1)
            }

            SettingsValueRow(title: "Location", value: formattedLocation)
        } header: {
            Label("Adhan Settings", systemImage: "clock.badge.fill")
        } footer: {
            Text("These adhan calculation preferences are stored locally on this device.")
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $notificationsEnabled) {
                Label("Enable Notifications", systemImage: "bell.badge.fill")
            }
            .onChange(of: notificationsEnabled) { _, newValue in
                if newValue {
                    requestNotificationAuthorizationIfNeeded()
                }

                Task {
                    await NotificationScheduler().syncNotifications()
                }
            }

            Toggle("Notify Adhan", isOn: $notifyAdhan)
                .disabled(!notificationsEnabled)
                .onChange(of: notifyAdhan) { _, _ in
                    Task {
                        await NotificationScheduler().syncNotifications()
                    }
                }

            Toggle("Notify Iqama", isOn: $notifyIqama)
                .disabled(!notificationsEnabled)
                .onChange(of: notifyIqama) { _, _ in
                    Task {
                        await NotificationScheduler().syncNotifications()
                    }
                }

            NavigationLink {
                AdhanSoundSelectionView()
            } label: {
                HStack {
                    Label("Adhan Sound", systemImage: "speaker.wave.2.fill")

                    Spacer()

                    Text(selectedAdhanSoundDisplayName)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!notificationsEnabled || !notifyAdhan)

//            Button {
//                testAdhanNotification()
//            } label: {
//                Label("Test Adhan Notification", systemImage: "bell.badge.fill")
//            }
//            .disabled(!notificationsEnabled || !notifyAdhan)
        } header: {
            Label("Notifications", systemImage: "bell.and.waves.left.and.right.fill")
        } footer: {
            Text("The selected sound is used only for Adhan notifications. Iqama notifications keep the default system sound.")
        }
    }

    private var selectedAdhanSoundDisplayName: String {
        AdhanSoundOption(rawValue: selectedAdhanSound)?.displayName
            ?? AdhanSoundOption.systemDefault.displayName
    }

    // MARK: - App Access

    private var appAccessSection: some View {
        Section {
            SettingsValueRow(
                title: "Connection",
                value: isConnected ? "Connected" : "Reconnect Needed",
                valueColor: isConnected ? .green : .orange
            )

            if !isConnected {
                Button {
                    reconnectAccess()
                } label: {
                    if isReconnecting {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else {
                        Label("Reconnect Now", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isReconnecting)
            }
        } header: {
            Label("App Access", systemImage: "lock.shield.fill")
        } footer: {
            Text("Use this device code to connect the app to your Masjid Pro account.")
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        Section {
            Button {
                copySupportInformation()
            } label: {
                Label("Copy Support Information", systemImage: "doc.on.doc")
            }

            Button {
                openAppStore()
            } label: {
                Label("Rate on App Store", systemImage: "star.fill")
            }
        } header: {
            Label("Support", systemImage: "questionmark.circle.fill")
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        Section {
            // Terms of Use is presented as a native in-app view for now; when a
            // hosted page becomes available, route it through LegalDocumentView
            // by giving LegalDocument.termsOfUse a hostedURLString.
            NavigationLink {
                EULAView()
            } label: {
                Label(LegalDocument.termsOfUse.title, systemImage: LegalDocument.termsOfUse.systemImage)
            }

            NavigationLink {
                LegalDocumentView(document: .privacyPolicy)
            } label: {
                Label(LegalDocument.privacyPolicy.title, systemImage: LegalDocument.privacyPolicy.systemImage)
            }
        } header: {
            Label("Legal", systemImage: "shield.checkered")
        } footer: {
            Text("The Privacy Policy is hosted online and may be updated from time to time.")
        }
    }

    // MARK: - Derived Values

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Al-Burooj Iqama"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private var deviceCode: String {
        getDeviceCode()
    }

    private var formattedLocation: String {
        if !city.isEmpty {
            return city
        }

        if latitude != 0 || longitude != 0 {
            return String(format: "%.4f, %.4f", latitude, longitude)
        }

        return "Not Set"
    }

    private var isConnected: Bool {
        !authToken.isEmpty && !authService.isAuthTokenExpired()
    }

    // MARK: - Actions

    private func requestNotificationAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if !granted {
                    notificationsEnabled = false
                    activeAlert = .notificationsDenied
                } else {
                    Task {
                        await NotificationScheduler().syncNotifications()
                    }
                }
            }
        }
    }

    private func reconnectAccess() {
        isReconnecting = true

        Task {
            do {
                _ = try await AuthService().getDeviceToken()
            } catch {
                activeAlert = .reconnectFailed(error.localizedDescription)
            }

            isReconnecting = false
        }
    }

    private func copySupportInformation() {
        let info = """
        \(appName)
        Version: \(appVersion) (\(buildNumber))
        Device Code: \(deviceCode)
        """

        UIPasteboard.general.string = info
    }

    private func openAppStore() {
        guard let url = URL(string: APP_URL) else { return }
        UIApplication.shared.open(url)
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func testAdhanNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Adhan"
        content.subtitle = city.isEmpty ? "Test Notification" : city
        content.body = "Adhan time for test prayer."
        
        // Use the selected adhan sound (same logic as real notifications)
        let selectedSound = UserDefaults.standard.string(forKey: AdhanSoundPreference.storageKey) ?? AdhanSoundOption.systemDefault.rawValue
        if let soundOption = AdhanSoundOption(rawValue: selectedSound) {
            content.sound = soundOption.notificationSound
            
            // Diagnostic logging for production debugging
            if let resourceName = soundOption.resourceName {
                let cafExists = AudioResource.caf(named: resourceName) != nil
                let mp3Exists = AudioResource.mp3(named: resourceName) != nil
                
                print("🔍 Sound File Check:")
                print("   Selected: \(soundOption.displayName)")
                print("   CAF exists: \(cafExists ? "✅" : "❌")")
                print("   MP3 exists: \(mp3Exists ? "✅" : "❌")")
                print("   Bundle path: \(Bundle.main.bundlePath)")
                
                // Check CAF file details
                if let cafURL = AudioResource.caf(named: resourceName) {
                    print("   CAF URL: \(cafURL.path)")
                    
                    // Check file size
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: cafURL.path),
                       let fileSize = attrs[.size] as? Int {
                        print("   CAF size: \(fileSize) bytes (\(Double(fileSize) / 1024.0 / 1024.0) MB)")
                        if fileSize < 1000 {
                            print("   ⚠️ WARNING: File is very small, may be corrupted")
                        }
                    }
                    
                    // Check audio duration and format
                    let asset = AVURLAsset(url: cafURL)
                    let duration = asset.duration.seconds
                    print("   🎵 Duration: \(String(format: "%.1f", duration)) seconds")
                    
                    if duration > 30 {
                        print("   ❌ ERROR: Audio is longer than 30 seconds!")
                        print("   iOS notification sounds MUST be 30 seconds or less")
                    }
                    
                    // Check audio format
                    if let track = asset.tracks(withMediaType: .audio).first {
                        if let formatDescriptions = track.formatDescriptions as? [CMFormatDescription] {
                            for description in formatDescriptions {
                                let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description)
                                if let desc = basicDescription?.pointee {
                                    print("   🎼 Format:")
                                    print("      Sample Rate: \(desc.mSampleRate) Hz")
                                    print("      Channels: \(desc.mChannelsPerFrame)")
                                    print("      Bits per channel: \(desc.mBitsPerChannel)")
                                    
                                    // Check if format is compatible
                                    let sampleRateOK = desc.mSampleRate >= 8000 && desc.mSampleRate <= 48000
                                    print("      Sample rate OK: \(sampleRateOK ? "✅" : "❌")")
                                    
                                    if !sampleRateOK {
                                        print("      ❌ Sample rate must be 8-48 kHz")
                                    }
                                }
                            }
                        }
                    }
                    
                    // List all CAF files in bundle to see what's actually included
                    if let files = try? FileManager.default.contentsOfDirectory(atPath: Bundle.main.bundlePath) {
                        let cafFiles = files.filter { $0.hasSuffix(".caf") }
                        print("   📁 CAF files in bundle: \(cafFiles.count)")
                        cafFiles.prefix(5).forEach { print("      - \($0)") }
                    }
                } else {
                    print("   ❌ CAF file NOT found in bundle!")
                }
            }
        } else {
            content.sound = .default
            print("🔔 Using default system sound")
        }
        
        // Trigger in 3 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "test-adhan-notification",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule test notification: \(error)")
            } else {
                print("✅ Test notification scheduled successfully")
            }
        }
    }
}

private enum SettingsAlert: Identifiable {
    case notificationsDenied
    case reconnectFailed(String)

    var id: String {
        switch self {
        case .notificationsDenied:
            return "notificationsDenied"
        case .reconnectFailed:
            return "reconnectFailed"
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

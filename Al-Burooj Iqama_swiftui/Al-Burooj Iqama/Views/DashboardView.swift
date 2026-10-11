import SwiftUI
import SwiftData

// MARK: - Supporting Types

private struct ProgressMetrics {
    let fraction: CGFloat
    let gradient: LinearGradient
}

var themeColor = UIColor(Color("themeColor"))

// MARK: - Dashboard View

struct DashboardView: View {
    // MARK: - Properties
    
    @AppStorage(LATT) private var latitude: Double = 0
    @AppStorage(LONG) private var longitude: Double = 0
    @AppStorage(CITY) private var city = ""
    @AppStorage(JURISDICTION) private var school: Int = 0
    @AppStorage(CALC_METH) private var calcMethod = "ISNA"

    @StateObject private var timesVM = TimesViewModel()
    @State private var masjidInfo: MasjidInfo?
    @State private var selectedDayOffset = 0
    @State private var currentError: UserFriendlyError?

    private let maxDayOffset = 15 // 0 is today; 15 is fifteen days from today
    
    // MARK: - Computed Properties

    private var displayCity: String {
        if !city.isEmpty { return city }
        return masjidInfo?.city ?? ""
    }

    private var displayMasjidName: String {
        if let name = masjidInfo?.masjidName, !name.isEmpty {
            return name
        }
        return ""
    }
    
    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedDayOffset) {
            ForEach(0...maxDayOffset, id: \.self) { offset in
                DayPrayerPage(
                    dayOffset: offset,
                    pageDate: date(for: offset),
                    timesVM: timesVM
                )
                .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationTitle(displayMasjidName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !displayCity.isEmpty {
                    Text(displayCity)
                        .padding(2)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .userFriendlyAlert(error: $currentError)
        .task {
            await loadMasjidInfo()
        }
        .task(id: selectedDayOffset) {
            await timesVM.load(dayOffset: selectedDayOffset)
        }
    }    
    // MARK: - Helper Methods

    private func date(for offset: Int) -> Date {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
    }

    @MainActor
    private func loadMasjidInfo() async {
        do {
            let info = try await MasjidService().fetchMasjidInfo()
            masjidInfo = info
        } catch let error as UserFriendlyError {
            currentError = error
        } catch {
            currentError = .dataLoading(feature: "Masjid Information") {
                await self.loadMasjidInfo()
            }
        }
    }
}

// MARK: - Day Prayer Page

// MARK: - Day Prayer Page

private struct DayPrayerPage: View {
    // MARK: - Properties
    
    let dayOffset: Int
    let pageDate: Date
    
    @ObservedObject var timesVM: TimesViewModel
    @AppStorage(PRAYER_SETTINGS) private var prayerSettingsData = Data()
    @AppStorage(JURISDICTION) private var jurisdiction = 0

    // MARK: - Prayer Names
    
    private enum PrayerName {
        static let fajr = "Fajr"
        static let sunrise = "Sunrise"
        static let dhuhar = "Dhuhar"
        static let asar = "Asar"
        static let maghrib = "Maghrib"
        static let isha = "Isha"
    }
    
    // MARK: - Computed Properties

    private var prayerSettings: PrayerSetting? {
        guard !prayerSettingsData.isEmpty else { return nil }
        return try? JSONDecoder().decode(PrayerSetting.self, from: prayerSettingsData)
    }
    
    // MARK: - Body

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            dateHeader

            if timesVM.isLoading || !timesVM.hasLoaded || timesVM.displayedDayOffset != dayOffset {
                Spacer()
                ProgressView("Loading prayer times…")
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView(){
                    VStack(spacing: 8) {
                        prayerRows
                        jummaSection
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background(maroonColor)
                }
            }
        }
        .cornerRadius(0.5)
        .padding(2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - View Components    
    // MARK: - View Components

    private var dateHeader: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(gregorianDateFormatter.string(from: pageDate))
                .font(.headline)

            Text(hijriDateFormatter.string(from: pageDate))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("themeColor"))
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Date Formatters

    private var gregorianDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }

    private var hijriDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }
    
    // MARK: - Helper Methods

    private func displayTime(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        
        if let date = formatter.date(from: trimmed) {
            let display = DateFormatter()
            display.locale = Locale(identifier: "en_US_POSIX")
            display.dateFormat = "hh:mm a"
            return display.string(from: date)
        }
        
        return trimmed
    }
    
    // MARK: - Prayer Rows    
    // MARK: - Prayer Rows

    @ViewBuilder
    private var prayerRows: some View {
        let current: (name: String, adhan: Date, iqama: Date)? =
            dayOffset == 0 ? timesVM.currentPrayerInfo() : nil
        
        PrayerCardView(
            title: PrayerName.fajr,
            adhanTime: timesVM.adhanTimes.fajr,
            iqamaTime: timesVM.iqamaTimes?.fajr,
            isCurrentPrayer: isCurrent(PrayerName.fajr, matching: current),
            boundaryTime: timesVM.adhanTimes.sunrise,
            timesVM: timesVM
        )
        
        PrayerCardView(
            title: PrayerName.sunrise,
            adhanTime: timesVM.adhanTimes.sunrise,
            iqamaTime: nil,
            isCurrentPrayer: isCurrent(PrayerName.sunrise, matching: current),
            boundaryTime: nil,
            timesVM: timesVM
        )
        
        PrayerCardView(
            title: PrayerName.dhuhar,
            adhanTime: timesVM.adhanTimes.dhuhar,
            iqamaTime: timesVM.iqamaTimes?.dhuhar,
            isCurrentPrayer: isCurrent(PrayerName.dhuhar, matching: current),
            boundaryTime: timesVM.adhanTimes.asar,
            timesVM: timesVM
        )
        
        PrayerCardView(
            title: PrayerName.asar,
            adhanTime: (jurisdiction != 0) ? timesVM.adhanTimes.asarHanafi : timesVM.adhanTimes.asar,
            iqamaTime: timesVM.iqamaTimes?.asar,
            isCurrentPrayer: isCurrent(PrayerName.asar, matching: current),
            boundaryTime: timesVM.adhanTimes.maghrib,
            timesVM: timesVM
        )
        
        PrayerCardView(
            title: PrayerName.maghrib,
            adhanTime: timesVM.adhanTimes.maghrib,
            iqamaTime: timesVM.iqamaTimes?.maghrib,
            isCurrentPrayer: isCurrent(PrayerName.maghrib, matching: current),
            boundaryTime: timesVM.adhanTimes.isha,
            timesVM: timesVM
        )
        
        PrayerCardView(
            title: PrayerName.isha,
            adhanTime: timesVM.adhanTimes.isha,
            iqamaTime: timesVM.iqamaTimes?.isha,
            isCurrentPrayer: isCurrent(PrayerName.isha, matching: current),
            boundaryTime: ishaEndBoundary(),
            timesVM: timesVM
        )
    }
    
    // MARK: - Jumma Section    
    // MARK: - Jumma Section

    @ViewBuilder
    private var jummaSection: some View {
        let raw1 = timesVM.settings?.jumma ?? ""
        let raw2 = timesVM.settings?.jumma2 ?? ""
        let has1 = !raw1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let has2 = !raw2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
         
        if has1 || has2 {
            VStack(spacing: 6) {
                if has1 {
                    jummaRow(title: "Jumma", time: raw1)
                }
                if has2 {
                    jummaRow(title: "Jumma 2", time: raw2, hideIcon: true)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
            .background(jummaBackground)
            .overlay(jummaBorder)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
            .padding(.top, 6)
        } else {
            EmptyView()
        }
    }
    
    private func jummaRow(title: String, time: String, hideIcon: Bool = false) -> some View {
        HStack {
            Image(systemName: "person.3.fill")
                .foregroundStyle(hideIcon ? Color.clear : Color.accentColor)
                .font(.system(size: 16, weight: .semibold))
            
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Text(displayTime(time))
                .font(.headline.monospacedDigit())
        }
    }    
    // MARK: - Jumma Styling

    private var jummaBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
            
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.80),
                            Color.white.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var jummaBorder: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.85),
                        Color.white.opacity(0.25)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
    
    // MARK: - Prayer Matching Logic    
    // MARK: - Prayer Matching Logic

    private func isCurrent(
        _ displayName: String,
        matching currentPrayer: (name: String, adhan: Date, iqama: Date)?
    ) -> Bool {
        guard let currentPrayer else { return false }

        switch displayName {
        case PrayerName.dhuhar:
            return currentPrayer.name == "Dhuhar" || currentPrayer.name == "Dhuhr"
        case PrayerName.asar:
            return currentPrayer.name == "Asar" || currentPrayer.name == "Asr"
        default:
            return currentPrayer.name == displayName
        }
    }

    private func ishaEndBoundary() -> Date? {
        guard let isha = timesVM.adhanTimes.isha,
              let midnight = timesVM.adhanTimes.midnight else {
            return nil
        }

        // Midnight is stored on the same day, but if it's after Isha
        // (after 12:00 AM), it belongs to the next calendar day
        if midnight < isha {
            return Calendar.current.date(byAdding: .day, value: 1, to: midnight)
        }
        return midnight
    }
}

// MARK: - Prayer Card View

// MARK: - Prayer Card View

private struct PrayerCardView: View {
    // MARK: - Properties
    
    let title: String
    let adhanTime: Date?
    let iqamaTime: Date?
    let isCurrentPrayer: Bool
    let boundaryTime: Date?
    
    @ObservedObject var timesVM: TimesViewModel

    private let cornerRadius: CGFloat = 20
    
    // MARK: - Computed Properties

    private var textColor: Color {
        isCurrentPrayer ? .white : maroonColor
    }
    
    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isCurrentPrayer, let adhanTime, let iqamaTime {
                progressSection(adhan: adhanTime, iqama: iqamaTime)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(
            color: .black.opacity(isCurrentPrayer ? 0.25 : 0.10),
            radius: isCurrentPrayer ? 14 : 6,
            x: 0,
            y: isCurrentPrayer ? 6 : 3
        )
        .scaleEffect(isCurrentPrayer ? 1.012 : 1)
        .offset(y: isCurrentPrayer ? -2 : 0)
        .rotation3DEffect(
            .degrees(isCurrentPrayer ? 1.2 : 0),
            axis: (x: 1, y: 0, z: 0),
            anchor: .center,
            perspective: 0.4
        )
        .animation(
            .spring(response: 0.45, dampingFraction: 0.85),
            value: isCurrentPrayer
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }
    
    // MARK: - View Components    
    // MARK: - View Components

    private var header: some View {
        HStack(spacing: 12) {
            icon

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(textColor)
                Text(adhanText)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(textColor)
            }

            Spacer(minLength: 12)

            iqamaColumn
        }
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(isCurrentPrayer ? 0.18 : 0.06))
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                )

            Image(systemName: isCurrentPrayer ? "bell.fill" : "clock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isCurrentPrayer ? Color.accentColor : Color.secondary)
        }
    }

    @ViewBuilder
    private var iqamaColumn: some View {
        if let iqamaTime {
            if isCurrentPrayer, let adhanTime {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let countdown = timesVM.countdownInfo(
                        now: context.date,
                        adhan: adhanTime,
                        iqama: iqamaTime,
                        nextAdhan: nil
                    )

                    VStack(alignment: .trailing, spacing: 4) {
 

                        Text(timeFormatter.string(from: iqamaTime))
                            .font(.title.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(textColor)

                        Text(countdown.countdown.isEmpty ? "--:--" : countdown.countdown)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(countdownColor(for: countdown.countdownLabel))
                    }
                }
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeFormatter.string(from: iqamaTime))
                        .font(.title .weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(maroonColor)
                }
            }
        }
    }
    
    // MARK: - Progress Section    
    // MARK: - Progress Section

    @ViewBuilder
    private func progressSection(adhan: Date, iqama: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let metrics = progressMetrics(
                now: context.date,
                adhan: adhan,
                iqama: iqama
            )

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))

                    Capsule()
                        .fill(metrics.gradient)
                        .frame(width: geometry.size.width * metrics.fraction)
                        .animation(.easeInOut(duration: 0.6), value: metrics.fraction)
                }
            }
            .frame(height: 6)
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Card Styling    
    // MARK: - Card Styling

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            if isCurrentPrayer {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.10),
                                Color.brown.opacity(0.70)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white)
//                    .fill(
//                        LinearGradient(
//                            colors: [
//                                Color.white.opacity(0.80),
//                                Color.white.opacity(0.20)
//                            ],
//                            startPoint: .topLeading,
//                            endPoint: .bottomTrailing
//                        )
//                    )
            }
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: isCurrentPrayer
                        ? [
                            Color.white.opacity(0.95),
                            Color.accentColor.opacity(0.9)
                        ]
                        : [
                            Color.white.opacity(0.85),
                            Color.white.opacity(0.25)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isCurrentPrayer ? 1.8 : 1
            )
    }
    
    // MARK: - Formatters & Accessors    
    // MARK: - Formatters & Accessors

    private var adhanText: String {
        guard let adhanTime else { return "--:--" }
        return timeFormatter.string(from: adhanTime)
    }

    private var accessibilityText: String {
        guard let adhanTime else { return "\(title), not available" }
        return "\(title), \(timeFormatter.string(from: adhanTime))"
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }
    
    // MARK: - Helper Methods

    private func countdownColor(for label: String) -> Color {
        if label.localizedCaseInsensitiveContains("Since") {
            return .red
        }
        if label.localizedCaseInsensitiveContains("Iqama") {
            return .green
        }
        if label.localizedCaseInsensitiveContains("Adhan") {
            return .orange
        }
        return .secondary
    }

    private func progressMetrics(now: Date, adhan: Date, iqama: Date) -> ProgressMetrics {
        let prayerInterval = max(iqama.timeIntervalSince(adhan), 1)

        // Pre-Adhan: no progress yet
        if now < adhan {
            return ProgressMetrics(
                fraction: 0,
                gradient: LinearGradient(
                    colors: [Color.green.opacity(0.45), .green],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }

        // Between Adhan and Iqama: green progress bar
        if now < iqama {
            let progress = min(max(now.timeIntervalSince(adhan) / prayerInterval, 0), 1)
            return ProgressMetrics(
                fraction: CGFloat(progress),
                gradient: LinearGradient(
                    colors: [Color.green.opacity(0.45), .green],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }

        // After Iqama: yellow to red countdown to next prayer
        let nextAdhan: Date
        if let boundaryTime, boundaryTime > iqama {
            nextAdhan = boundaryTime
        } else {
            nextAdhan = iqama.addingTimeInterval(prayerInterval)
        }

        let totalCountdown = max(nextAdhan.timeIntervalSince(iqama), 1)
        let remaining = max(nextAdhan.timeIntervalSince(now), 0)
        let countdownFraction = min(max(remaining / totalCountdown, 0), 1)

        return ProgressMetrics(
            fraction: CGFloat(countdownFraction),
            gradient: LinearGradient(
                colors: [.yellow, .red],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
}

// MARK: - Drawer View

//private struct DrawerView: View {
//    @Binding var isOpen: Bool
//    
//    var body: some View {
//        ZStack(alignment: .leading) {
//            // Dimmed background
//            if isOpen {
//                Color.black.opacity(0.3)
//                    .ignoresSafeArea()
//                    .onTapGesture {
//                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
//                            isOpen = false
//                        }
//                    }
//                    .transition(.opacity)
//            }
//            
//            // Drawer content
//            if isOpen {
//                VStack(alignment: .leading, spacing: 0) {
//                    // Header
//                    VStack(alignment: .leading, spacing: 8) {
//                        HStack {
//                            Image(systemName: "moon.stars.fill")
//                                .font(.system(size: 28))
//                                .foregroundStyle(Color("themeColor"))
//                            
//                            Spacer()
//                            
//                            Button {
//                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
//                                    isOpen = false
//                                }
//                            } label: {
//                                Image(systemName: "xmark.circle.fill")
//                                    .font(.system(size: 24))
//                                    .foregroundStyle(.secondary)
//                            }
//                        }
//                        .padding(.bottom, 4)
//                        
//                        Text("Prayer Times")
//                            .font(.title2.weight(.bold))
//                        
//                        Text("Islamic App")
//                            .font(.subheadline)
//                            .foregroundStyle(.secondary)
//                    }
//                    .padding(20)
//                    .background(Color("themeColor").opacity(0.1))
//                    
//                    Divider()
//                    
//                    // Menu items
//                    ScrollView {
//                        VStack(spacing: 0) {
//                            DrawerMenuItem(
//                                icon: "clock.badge",
//                                title: "Dashboard",
//                                action: { isOpen = false }
//                            )
//                            
//                            DrawerMenuItem(
//                                icon: "calendar",
//                                title: "Calendar",
//                                action: { isOpen = false }
//                            )
//                            
//                            DrawerMenuItem(
//                                icon: "location.north.line",
//                                title: "Qibla",
//                                action: { isOpen = false }
//                            )
//                            
//                            DrawerMenuItem(
//                                icon: "building.2",
//                                title: "Masjid",
//                                action: { isOpen = false }
//                            )
//                            
//                            Divider()
//                                .padding(.vertical, 8)
//                            
//                            DrawerMenuItem(
//                                icon: "gearshape",
//                                title: "Settings",
//                                action: { isOpen = false }
//                            )
//                            
//                            DrawerMenuItem(
//                                icon: "info.circle",
//                                title: "About",
//                                action: { isOpen = false }
//                            )
//                        }
//                        .padding(.vertical, 8)
//                    }
//                    
//                    Spacer()
//                    
//                    // Footer
//                    VStack(spacing: 4) {
//                        Text("Version 1.0")
//                            .font(.caption2)
//                            .foregroundStyle(.secondary)
//                    }
//                    .frame(maxWidth: .infinity)
//                    .padding(.bottom, 20)
//                }
//                .frame(width: 280)
//                .background(.ultraThinMaterial)
//                .shadow(color: .black.opacity(0.2), radius: 10, x: 2, y: 0)
//                .transition(.move(edge: .leading))
//            }
//        }
//        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isOpen)
//    }
//}

//private struct DrawerMenuItem: View {
//    let icon: String
//    let title: String
//    let action: () -> Void
//    
//    var body: some View {
//        Button(action: action) {
//            HStack(spacing: 16) {
//                Image(systemName: icon)
//                    .font(.system(size: 20))
//                    .foregroundStyle(Color("themeColor"))
//                    .frame(width: 24)
//                
//                Text(title)
//                    .font(.body.weight(.medium))
//                    .foregroundStyle(.primary)
//                
//                Spacer()
//            }
//            .padding(.horizontal, 20)
//            .padding(.vertical, 12)
//            .contentShape(Rectangle())
//        }
//        .buttonStyle(.plain)
//    }
//}


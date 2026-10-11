import SwiftUI

struct QiblaView: View {
    @Environment(LocationManager.self) private var locationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    @State private var useTrueNorth = true
    @State private var isLocked = false
    @State private var lastLockHapticAt: Date? = nil

    // Kaaba coordinates
    private let kaabaLatitude = 21.4225
    private let kaabaLongitude = 39.8262
    
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var compassSize: CGFloat {
        isIPad ? 440 : 340
    }

    private var lockGlowColor: Color {
        colorScheme == .dark ? Color(red: 0.83, green: 0.69, blue: 0.22) : .green
    }

    var body: some View {
        VStack(spacing: isIPad ? 32 : 24) {
            Spacer()
            
            ZStack {
                // Circular progress indicator around compass
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: isIPad ? 12 : 8)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: compassSize + (isIPad ? 24 : 16), height: compassSize + (isIPad ? 24 : 16))
                
                Circle()
                    .trim(from: 0, to: 1 - alignmentProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: isIPad ? 12 : 8, lineCap: .round)
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: compassSize + (isIPad ? 24 : 16), height: compassSize + (isIPad ? 24 : 16))
                    .rotationEffect(.degrees(-90)) // Start from top
                    .animation(.easeOut(duration: 0.2), value: alignmentProgress)
                
                // Compass image already contains the dial and a Kaaba marker at its
                // top (0°), so rotating it by the Qibla pointer rotation makes that
                // marker point at the real-world Qibla direction.
                Image("Compass")
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .frame(width: compassSize, height: compassSize)
                    .shadow(color: isLocked ? lockGlowColor.opacity(0.6) : .clear, radius: isIPad ? 20 : 15)
                    .shadow(color: isLocked ? lockGlowColor.opacity(0.4) : .clear, radius: isIPad ? 30 : 20)
                    .shadow(color: isLocked ? lockGlowColor.opacity(0.2) : .clear, radius: isIPad ? 40 : 30)
                    .rotationEffect(.degrees(qiblaPointerRotation))

                // Lock icon when aligned
                if isLocked {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: isIPad ? 70 : 46, height: isIPad ? 70 : 46)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: isIPad ? 24 : 18))
                            .foregroundStyle(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .animation(.easeInOut(duration: 0.2), value: qiblaPointerRotation)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLocked)

            VStack(spacing: isIPad ? 12 : 8) {
                Text(statusText)
                    .font(isIPad ? .title3 : .headline)
                    .multilineTextAlignment(.center)
                
                // Always show the container for bearing and distance
                HStack(spacing: isIPad ? 20 : 16) {
                    // Bearing information
                    VStack(spacing: 4) {
                        if let bearing = qiblaBearing {
                            Text(String(format: "%.0f°", bearing))
                                .font(isIPad ? .title2.bold() : .title3.bold())
                                .foregroundStyle(.primary)
                        } else {
                            Text("--°")
                                .font(isIPad ? .title2.bold() : .title3.bold())
                                .foregroundStyle(.secondary)
                        }
                        Text("Bearing")
                            .font(isIPad ? .caption : .caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Distance information
                    VStack(spacing: 4) {
                        if let distanceKm = distanceToKaabaKilometers {
                            Text(String(format: "%.1f km", distanceKm))
                                .font(isIPad ? .title2.bold() : .title3.bold())
                                .foregroundStyle(.primary)
                        } else {
                            Text("-- km")
                                .font(isIPad ? .title2.bold() : .title3.bold())
                                .foregroundStyle(.secondary)
                        }
                        Text("Distance")
                            .font(isIPad ? .caption : .caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            VStack(spacing: isIPad ? 16 : 12) {
                Toggle(isOn: $useTrueNorth) {
                    Text("Use True North")
                        .font(isIPad ? .body : .subheadline)
                }
                .toggleStyle(SwitchToggleStyle(tint: .red))
                .accessibilityLabel("Use True North for heading")
            }
            .padding(.horizontal, isIPad ? 32 : 16)
            .frame(maxWidth: isIPad ? 500 : .infinity)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onChange(of: locationManager.heading?.trueHeading) {
            handleAlignmentFeedback()
        }
        .onChange(of: locationManager.heading?.magneticHeading) {
            handleAlignmentFeedback()
        }
        .onAppear {
            locationManager.start()
        }
    }

    private var statusText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "Requesting location permission…"
        case .denied, .restricted:
            return "Location permission needed to show Qibla."
        default:
            if locationManager.location == nil {
                return "Getting your location…"
            }
            if locationManager.heading == nil {
                return "Getting your heading…"
            }
            return "Point the arrow toward the Qibla."
        }
    }

    // Bearing from user to Kaaba in degrees (0° = true North, clockwise)
    private var qiblaBearing: Double? {
        guard let loc = locationManager.location else { return nil }
        let lat1 = loc.coordinate.latitude.radians
        let lon1 = loc.coordinate.longitude.radians
        let lat2 = kaabaLatitude.radians
        let lon2 = kaabaLongitude.radians
        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearingRad = atan2(y, x)
        var bearingDeg = bearingRad.degrees
        if bearingDeg < 0 { bearingDeg += 360 }
        return bearingDeg
    }

    private var headingDegrees: Double {
        if useTrueNorth {
            return locationManager.heading?.trueHeading ?? locationManager.heading?.magneticHeading ?? 0
        } else {
            return locationManager.heading?.magneticHeading ?? locationManager.heading?.trueHeading ?? 0
        }
    }

    private var qiblaPointerRotation: Double {
        guard let bearing = qiblaBearing else { return 0 }
        // Needle should point to Qibla bearing, compensating for compass rotation
        // Compass rotates by -headingDegrees, so needle needs bearing - headingDegrees
        return bearing - headingDegrees
    }

    private var distanceToKaabaMeters: Double? {
        guard let loc = locationManager.location else { return nil }
        return haversineDistance(lat1: loc.coordinate.latitude, lon1: loc.coordinate.longitude,
                                 lat2: kaabaLatitude, lon2: kaabaLongitude)
    }
    
    private var distanceToKaabaKilometers: Double? {
        guard let meters = distanceToKaabaMeters else { return nil }
        return meters / 1000.0
    }

    private var distanceToKaabaText: String? {
        guard let meters = distanceToKaabaMeters else { return nil }
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        } else {
            return String(format: "%.0f m", meters)
        }
    }

    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6_371_000.0 // meters
        let dLat = (lat2 - lat1).radians
        let dLon = (lon2 - lon1).radians
        let a = sin(dLat/2) * sin(dLat/2) + cos(lat1.radians) * cos(lat2.radians) * sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

    private var alignmentError: Double {
        guard let bearing = qiblaBearing else { return 180 }
        let diff = (bearing - headingDegrees).truncatingRemainder(dividingBy: 360)
        let normalized = diff < -180 ? diff + 360 : (diff > 180 ? diff - 360 : diff)
        return abs(normalized)
    }

    private var alignmentProgress: CGFloat {
        // Map 0..45 degrees to 0..1, clamp
        let maxErr: Double = 45
        let p = min(max(alignmentError / maxErr, 0), 1)
        return CGFloat(p)
    }

    private func handleAlignmentFeedback() {
        let tolerance: Double = 3 // degrees
        let wasLocked = isLocked
        isLocked = alignmentError <= tolerance

        // Generate light haptic when entering lock state, throttle to 1 per 0.8s
        if isLocked && !wasLocked {
            let now = Date()
            if let last = lastLockHapticAt, now.timeIntervalSince(last) < 0.8 {
                return
            }
            lastLockHapticAt = now
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

private struct AlignmentBar: View {
    let progress: CGFloat // 0..1 where 0 is perfect alignment
    var isIPad: Bool = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let minWidth: CGFloat = max(width * 0.05, isIPad ? 12 : 8) // never fully zero to keep visible
            let barWidth = max(minWidth, width * (1 - progress))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: barWidth)
                    .animation(.easeOut(duration: 0.2), value: barWidth)
            }
        }
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}
#Preview {
    NavigationStack {
        QiblaView()  .environment(LocationManager())
    }
}

import SwiftUI
import SwiftData
import StoreKit

struct ContentView: View {
    // Owned here so location starts at app launch and is shared app-wide.
    @State private var locationManager = LocationManager()
    @State private var isDrawerOpen = false

    var body: some View {
        ZStack {
            TabView {
                themedTab("Dashboard", systemImage: "clock.badge") {
                    DashboardView()
                }

                themedTab("Calendar", systemImage: "calendar") {
                    CalendarView()
                        .navigationTitle("Calendar")
                }

                themedTab("Qibla", systemImage: "location.north.line") {
                    QiblaView()
                        .navigationTitle("Qibla")
                }

                themedTab("Masjid", systemImage: "building.2") {
                    MasjidView()
                }

                themedTab("Settings", systemImage: "gearshape") {
                    SettingsView()
                }
            }
            .environment(locationManager)
            
            // Drawer overlay
            DrawerView(isOpen: $isDrawerOpen)
        }
    }

    /// One styled navigation bar per tab, with a consistent maroon toolbar.
    private func themedTab<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color("themeColor"), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isDrawerOpen.toggle()
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
        }
        .tabItem {
            Label(title, systemImage: systemImage)
        }
    }
}

// MARK: - Drawer View

private struct DrawerView: View {
    @Binding var isOpen: Bool
    @State private var showTermsOfUse = false
    @State private var showPrivacyPolicy = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Dimmed background
            if isOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isOpen = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // Drawer content
            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Color("themeColor"))
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isOpen = false
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.bottom, 4)
                        
                        Text("Prayer Times")
                            .font(.title2.weight(.bold))
                        
                        Text("Islamic App")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(Color("themeColor").opacity(0.1))
                    
                    Divider()
                    
                    // Menu items
                    ScrollView {
                        VStack(spacing: 0) {
                            DrawerMenuItem(
                                icon: "star.fill",
                                title: "Rate the App",
                                action: {
                                    isOpen = false
                                    rateApp()
                                }
                            )
                            
                            DrawerMenuItem(
                                icon: "square.and.arrow.up",
                                title: "Share App",
                                action: {
                                    isOpen = false
                                    shareApp()
                                }
                            )
                            
                            DrawerMenuItem(
                                icon: "questionmark.circle",
                                title: "Help & Support",
                                action: {
                                    isOpen = false
                                    openHelpSupport()
                                }
                            )
                            
                            Divider()
                                .padding(.vertical, 8)
                            
                            DrawerMenuItem(
                                icon: "doc.text",
                                title: "Terms of Use",
                                action: {
                                    isOpen = false
                                    showTermsOfUse = true
                                }
                            )
                            
                            DrawerMenuItem(
                                icon: "hand.raised",
                                title: "Privacy Policy",
                                action: {
                                    isOpen = false
                                    showPrivacyPolicy = true
                                }
                            )
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Spacer()
                    
                    // Footer
                    VStack(spacing: 4) {
                        Text("Version \(appVersion)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                }
                .frame(width: 280)
                .background(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 2, y: 0)
                .transition(.move(edge: .leading))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isOpen)
        .sheet(isPresented: $showTermsOfUse) {
            NavigationStack {
                EULAView()
                    .navigationTitle("Terms of Use")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showTermsOfUse = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationStack {
                LegalDocumentView(document: .privacyPolicy)
                    .navigationTitle("Privacy Policy")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showPrivacyPolicy = false
                            }
                        }
                    }
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
    
    // MARK: - Helper Functions
    
    private func rateApp() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    private func shareApp() {
        guard let url = URL(string: APP_URL) else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [
                "Check out this amazing Prayer Times app!",
                url
            ],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: 100, y: 100, width: 200, height: 200)
            
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func openHelpSupport() {
        if let url = URL(string: "https://x2softinc.com") {
            UIApplication.shared.open(url)
        }
    }
}

private struct DrawerMenuItem: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color("themeColor"))
                    .frame(width: 24)
                
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
}

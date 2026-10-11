import SwiftUI
import Foundation
import UIKit

struct AppVersionGate<Content: View>: View {
    let appStoreURL: URL
    let versionService: VersionService
    @State private var requiresUpdate = false
    @ViewBuilder let content: () -> Content

    init(appStoreURL: URL, versionService: VersionService = VersionService(), @ViewBuilder content: @escaping () -> Content) {
        self.appStoreURL = appStoreURL
        self.versionService = versionService
        self.content = content
    }

    var body: some View {
        ZStack {
            content()

            if requiresUpdate {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)

                    Text("Update Required")
                        .font(.title2).bold()
                        .foregroundStyle(.primary)

                    Text("A new version of the app is available and is required to continue.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Button(action: openAppStore) {
                        Text("Update Now")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .padding(.horizontal)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(radius: 10)
                )
                .padding(24)
            }
        }
        .task {
            await checkVersion()
        }
    }

    private func checkVersion() async {
        do {
            let mustUpdate = try await self.versionService.checkVersion()
            self.requiresUpdate = mustUpdate
        } catch {
            // On any error (network/decoding/etc.), block the app and require update.
           // self.requiresUpdate = true
            self.requiresUpdate = false
        }
    }

    private func openAppStore() {
        UIApplication.shared.open(appStoreURL)
    }
}

#Preview {
    final class AlwaysUpdateService: VersionService {
        override func checkVersion() async throws -> Bool { true }
    }

    return AppVersionGate(appStoreURL: URL(string: "https://apps.apple.com/app/id0000000000")!, versionService: AlwaysUpdateService()) {
        Text("Hello from gated content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.green.opacity(0.2))
    }
}

//
//  COMPLETE_IMPROVEMENTS_TO_ADD.swift
//  Al-Burooj Iqama
//
//  All improvements in ONE file for easy copying
//

/*
 
 ========================================
 PART 1: USER-FRIENDLY ERROR SYSTEM
 ========================================
 
 Create a new Swift file called "UserFriendlyError.swift"
 and paste this code:
 
*/

import Foundation
import SwiftUI

/// User-friendly error wrapper that converts technical errors into readable messages
struct UserFriendlyError: LocalizedError, Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let recoveryAction: RecoveryAction?
    
    var errorDescription: String? { message }
    
    enum RecoveryAction {
        case retry(() async -> Void)
        case openSettings
        case contact
        case none
        
        var buttonTitle: String {
            switch self {
            case .retry: return "Try Again"
            case .openSettings: return "Open Settings"
            case .contact: return "Contact Support"
            case .none: return "OK"
            }
        }
    }
    
    // MARK: - Common Errors
    
    static func network(retryAction: (() async -> Void)? = nil) -> UserFriendlyError {
        UserFriendlyError(
            title: "Connection Problem",
            message: "We're having trouble connecting to the server. Please check your internet connection and try again.",
            icon: "wifi.exclamationmark",
            recoveryAction: retryAction.map { .retry($0) }
        )
    }
    
    static func authentication(retryAction: (() async -> Void)? = nil) -> UserFriendlyError {
        UserFriendlyError(
            title: "Authentication Required",
            message: "Your device needs to reconnect to access this feature. Please reconnect in Settings.",
            icon: "lock.shield",
            recoveryAction: .openSettings
        )
    }
    
    static func locationPermission() -> UserFriendlyError {
        UserFriendlyError(
            title: "Location Access Needed",
            message: "Al-Burooj Iqama needs access to your location to calculate accurate prayer times. Please enable location access in Settings.",
            icon: "location.slash",
            recoveryAction: .openSettings
        )
    }
    
    static func notificationPermission() -> UserFriendlyError {
        UserFriendlyError(
            title: "Notification Access Needed",
            message: "To receive prayer time reminders, please enable notifications in Settings.",
            icon: "bell.slash",
            recoveryAction: .openSettings
        )
    }
    
    static func dataLoading(feature: String, retryAction: (() async -> Void)? = nil) -> UserFriendlyError {
        UserFriendlyError(
            title: "Unable to Load \(feature)",
            message: "We couldn't load \(feature) right now. This might be a temporary issue. Please try again.",
            icon: "exclamationmark.triangle",
            recoveryAction: retryAction.map { .retry($0) }
        )
    }
    
    static func serverError() -> UserFriendlyError {
        UserFriendlyError(
            title: "Server Issue",
            message: "Our server is having trouble right now. Please try again in a few moments.",
            icon: "server.rack",
            recoveryAction: .contact
        )
    }
    
    static func timeout(retryAction: (() async -> Void)? = nil) -> UserFriendlyError {
        UserFriendlyError(
            title: "Request Timed Out",
            message: "The request took too long to complete. Please check your internet connection and try again.",
            icon: "clock.badge.exclamationmark",
            recoveryAction: retryAction.map { .retry($0) }
        )
    }
    
    static func generic(_ error: Error, retryAction: (() async -> Void)? = nil) -> UserFriendlyError {
        let nsError = error as NSError
        
        // Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return network(retryAction: retryAction)
            case NSURLErrorTimedOut:
                return timeout(retryAction: retryAction)
            default:
                return network(retryAction: retryAction)
            }
        }
        
        // HTTP errors
        if nsError.code == 401 {
            return authentication(retryAction: retryAction)
        }
        if nsError.code >= 500 {
            return serverError()
        }
        
        return UserFriendlyError(
            title: "Something Went Wrong",
            message: "We encountered an unexpected problem. Please try again.",
            icon: "exclamationmark.triangle",
            recoveryAction: retryAction.map { .retry($0) }
        )
    }
}

// MARK: - View Extensions

extension View {
    /// Display a user-friendly error alert
    func userFriendlyAlert(error: Binding<UserFriendlyError?>) -> some View {
        self.alert(
            error.wrappedValue?.title ?? "Error",
            isPresented: .init(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            )
        ) {
            if let currentError = error.wrappedValue,
               let action = currentError.recoveryAction {
                Button(action.buttonTitle) {
                    switch action {
                    case .retry(let retryAction):
                        Task {
                            await retryAction()
                            error.wrappedValue = nil
                        }
                    case .openSettings:
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                        error.wrappedValue = nil
                    case .contact:
                        if let url = URL(string: "mailto:support@alburoojiqama.com") {
                            UIApplication.shared.open(url)
                        }
                        error.wrappedValue = nil
                    case .none:
                        error.wrappedValue = nil
                    }
                }
                
                Button("Dismiss", role: .cancel) {
                    error.wrappedValue = nil
                }
            }
        } message: {
            if let currentError = error.wrappedValue {
                Text(currentError.message)
            }
        }
    }
}

/*
 
 ========================================
 PART 2: SECURE CONFIGURATION
 ========================================
 
 Create a new Swift file called "SecureConfiguration.swift"
 and paste this code:
 
*/

import Foundation
import Security

enum SecureConfiguration {
    
    /// Get API key from configuration
    static var versionAPIKey: String {
        // Retrieve from Info.plist instead of hardcoding
        if let key = Bundle.main.object(forInfoDictionaryKey: "VERSION_API_KEY") as? String {
            return key
        }
        return ""
    }
    
    /// Get version check URL (HTTPS only)
    static var versionCheckURL: String {
        return "https://nexus.x2softinc.com/api/v1/apps/by-code/ALBIOS1"
    }
}

/*
 
 ========================================
 PART 3: HOW TO USE IN YOUR CODE
 ========================================
 
 EXAMPLE 1: In DashboardView
 
*/

/* Add this to your DashboardView:

struct DashboardView: View {
    @State private var currentError: UserFriendlyError?
    
    var body: some View {
        // Your existing code...
        .userFriendlyAlert(error: $currentError)  // ← Add this
    }
    
    private func loadMasjidInfo() async {
        do {
            let info = try await MasjidService().fetchMasjidInfo()
            masjidInfo = info
        } catch let error as UserFriendlyError {
            currentError = error  // ← Show friendly error
        } catch {
            currentError = .dataLoading(feature: "Masjid Information") {
                await self.loadMasjidInfo()
            }
        }
    }
}

*/

/*
 
 EXAMPLE 2: In MasjidService
 
*/

/* Update your MasjidService fetchMasjidInfo method:

func fetchMasjidInfo() async throws -> MasjidInfo {
    // ... your existing code ...
    
    guard !token.isEmpty else {
        throw UserFriendlyError.authentication()  // ← Instead of NSError
    }
    
    // ... rest of your code ...
    
    guard let http = response as? HTTPURLResponse else {
        throw UserFriendlyError.network {  // ← Instead of NSError
            _ = try? await self.fetchMasjidInfo()
        }
    }
    
    if http.statusCode >= 500 {
        throw UserFriendlyError.serverError()  // ← Instead of NSError
    }
}

*/

/*
 
 EXAMPLE 3: In VersionService
 
*/

/* Update your VersionService to use secure configuration:

class VersionService {
    private var apiKey: String {
        SecureConfiguration.versionAPIKey  // ← Instead of hardcoded
    }
    
    private var versionURLString: String {
        SecureConfiguration.versionCheckURL  // ← HTTPS instead of HTTP
    }
}

*/

/*
 
 ========================================
 STEP-BY-STEP INTEGRATION GUIDE
 ========================================
 
 STEP 1: Create UserFriendlyError.swift
 --------------------------------------
 1. In Xcode: File → New → File → Swift File
 2. Name it: UserFriendlyError.swift
 3. Copy PART 1 from above
 4. Paste into the new file
 5. Save
 
 STEP 2: Create SecureConfiguration.swift
 ----------------------------------------
 1. In Xcode: File → New → File → Swift File
 2. Name it: SecureConfiguration.swift
 3. Copy PART 2 from above
 4. Paste into the new file
 5. Save
 
 STEP 3: Update Your Existing Files
 ----------------------------------
 See the examples in PART 3 above and update:
 - DashboardView.swift
 - MasjidService.swift
 - PrayerSettingsView.swift
 - VersionService.swift
 
 I've already shown you what to change in these files earlier.
 
 STEP 4: Add API Key to Info.plist
 ---------------------------------
 1. Open Info.plist
 2. Right-click → Add Row
 3. Key: VERSION_API_KEY
 4. Type: String
 5. Value: VVnCd+hXENxGCGSGV1ujTeHhwu5Tq4SMxgBe49/Wdsc=
 
 STEP 5: Test Everything
 -----------------------
 1. Build and run
 2. Turn on Airplane Mode
 3. Navigate in the app
 4. You should see friendly error messages!
 
*/

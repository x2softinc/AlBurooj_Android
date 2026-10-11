//
//  PrayerSettingsService.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 9/1/26.
//

import Foundation
import SwiftUI

class PrayerSettingsService {
   
    @AppStorage(PRAYER_SETTINGS) private var prayerSettingsData = Data()
    @AppStorage(PRAYER_SETTINGS_LAST_FETCH) private var prayerSettings_lastUpdate = ""

    func fetchPrayerSettings() async throws -> PrayerSetting {
        
        if !prayerSettingsData.isEmpty, prayerSettings_lastUpdate == todayKey {
            if let info = try? JSONDecoder().decode(PrayerSetting.self, from: prayerSettingsData) {
                return info
            }
        }
        
        let service = AuthService()

        // Refresh the auth token if it has already expired.
      
         let token  = try await service.getDeviceToken()
         let deviceCode = getDeviceCode()
      

        guard !token.isEmpty else {
            throw NSError(
                domain: "PrayerSettingsService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Auth token missing."]
            )
        }

        let urlString = getBaseUrl() + MasjidProApiPaths.resources.byDeviceCode("prayerSettings", deviceCode: deviceCode)
         
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "PrayerSettingsService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "PrayerSettingsService",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]
                )
            }

            if http.statusCode == 401 {
                // Token was rejected. Refresh it and retry once.
                _ = try await service.getDeviceToken()

                guard !token.isEmpty else {
                    throw NSError(
                        domain: "PrayerSettingsService",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Token refresh did not provide a new token."]
                    )
                }

                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let (retryData, retryResponse) = try await URLSession.shared.data(for: request)

                guard let retryHTTP = retryResponse as? HTTPURLResponse,
                      (200...299).contains(retryHTTP.statusCode) else {
                    throw NSError(
                        domain: "PrayerSettingsService",
                        code: (retryResponse as? HTTPURLResponse)?.statusCode ?? 0,
                        userInfo: [NSLocalizedDescriptionKey: "Request failed after token refresh."]
                    )
                }

                return try decodeAndSave(retryData)
            }

            guard (200...299).contains(http.statusCode) else {
                throw NSError(
                    domain: "PrayerSettingsService",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
                )
            }

            return try decodeAndSave(data)
        } catch let error as NSError {
            throw error
        } catch {
            throw NSError(
                domain: "PrayerSettingsService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
        }
    }

    private func decodeAndSave(_ data: Data) throws -> PrayerSetting {
        let settings = try JSONDecoder().decode(PrayerSetting.self, from: data)
        saveToAppStorage(settings)
        return settings
    }

    private func saveToAppStorage(_ settings: PrayerSetting) {
        if let encoded = try? JSONEncoder().encode(settings) {
            prayerSettingsData = encoded
             
        }
    }
}

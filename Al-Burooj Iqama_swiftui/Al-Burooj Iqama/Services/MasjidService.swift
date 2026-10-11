//
//  MasjidService.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/31/26.
//

import Foundation
import SwiftUI

let todayKey: String = {
    let df = DateFormatter()
    df.locale = Locale(identifier: "en_US_POSIX")
    df.calendar = Calendar(identifier: .gregorian)
    df.dateFormat = "yyyy-MM-dd"
    return df.string(from: Date())
}()

class MasjidService {
    
    @AppStorage(MASJID_INFO) private var cachedMasjidInfo = Data()
    @AppStorage(MASJID_INFO_LAST_FETCH) private var lastFetchedDay: String = ""
    
    
    private let deviceCode = getDeviceCode()
    
    func fetchMasjidInfo() async throws -> MasjidInfo {

        // Return cached value if present and it's still the same day
        if !cachedMasjidInfo.isEmpty, lastFetchedDay == todayKey {
            if let info = try? JSONDecoder().decode(MasjidInfo.self, from: cachedMasjidInfo) {
                return info
            }
        }
        
        let service = AuthService()

        // Refresh the auth token if it has already expired.
        let token: String
        do {
            token = try await service.getDeviceToken()
        } catch {
            throw UserFriendlyError.authentication {
                _ = try? await self.fetchMasjidInfo()
            }
        }
        
        guard !token.isEmpty else {
            throw UserFriendlyError.authentication()
        }

        
        let urlString = getBaseUrl() + MasjidProApiPaths.resources.byDeviceCode("masjidInfo", deviceCode: deviceCode)
         
        guard let url = URL(string: urlString) else {
            throw UserFriendlyError.dataLoading(feature: "Masjid Information")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw UserFriendlyError.network {
                    _ = try? await self.fetchMasjidInfo()
                }
            }

            if http.statusCode == 401 {
                // Token was rejected. Refresh it and retry once.
                let newToken = try await service.getDeviceToken()
                
                guard !newToken.isEmpty else {
                    throw UserFriendlyError.authentication()
                }

                request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")

                let (retryData, retryResponse) = try await URLSession.shared.data(for: request)

                guard let retryHTTP = retryResponse as? HTTPURLResponse,
                      (200...299).contains(retryHTTP.statusCode) else {
                    if (retryResponse as? HTTPURLResponse)?.statusCode ?? 0 >= 500 {
                        throw UserFriendlyError.serverError()
                    }
                    throw UserFriendlyError.dataLoading(feature: "Masjid Information") {
                        _ = try? await self.fetchMasjidInfo()
                    }
                }

                let decoded = try JSONDecoder().decode(MasjidInfo.self, from: retryData)
                if let encoded = try? JSONEncoder().encode(decoded) {
                    cachedMasjidInfo = encoded
                    lastFetchedDay = todayKey
                }
                return decoded
            }

            guard (200...299).contains(http.statusCode) else {
                if http.statusCode >= 500 {
                    throw UserFriendlyError.serverError()
                }
                throw UserFriendlyError.dataLoading(feature: "Masjid Information") {
                    _ = try? await self.fetchMasjidInfo()
                }
            }

            let decoded = try JSONDecoder().decode(MasjidInfo.self, from: data)
            if let encoded = try? JSONEncoder().encode(decoded) {
                cachedMasjidInfo = encoded
                lastFetchedDay = todayKey
            }
            return decoded
        } catch let error as UserFriendlyError {
            throw error
        } catch {
            throw UserFriendlyError.generic(error) {
                _ = try? await self.fetchMasjidInfo()
            }
        }
    }
}

//
//  VersionService.swift
//  UPSC Helper
//
//  Created by Shiha on 3/31/20.
//  Copyright © 2020 Trendsoft Inc. All rights reserved.
//

import Foundation
import SwiftUI
import os.log

class VersionService {
    
    @AppStorage(BASE_URL) private var baseUrl: String?
    
    // SECURITY: API key retrieved from configuration, not hardcoded
    private var apiKey: String {
        SecureConfiguration.versionAPIKey
    }
    
    // SECURITY: HTTPS required by App Store (was HTTP)
    private var versionURLString: String {
        SecureConfiguration.versionCheckURL
    }

     
    
    func checkVersion() async throws -> Bool
    {

        guard let url = URL(string: versionURLString) else {
            throw NSError(
                domain: "VersionService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(versionURLString)"]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "VersionService",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]
                )
            }

            guard httpResponse.statusCode == 200 else {
                throw NSError(
                    domain: "VersionService",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Unexpected status code: \(httpResponse.statusCode)"]
                )
            }
            
//            #if DEBUG
//            print("[VersionService] Status: \(httpResponse.statusCode)")
//            if let bodyString = String(data: data, encoding: .utf8) {
//                print("[VersionService] Body: \(bodyString)")
//            } else {
//                print("[VersionService] Body: <non-UTF8 data, \(data.count) bytes>")
//            }
//            #endif
            
            var versionInfo: VersionInfo
            do {
                versionInfo = try JSONDecoder().decode(VersionInfo.self, from: data)
            } catch {
//                #if DEBUG
//                print("[VersionService] Decoding failed: \(error)")
//                #endif
                throw error
            }
             
            guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
//                #if DEBUG
//                print("[VersionService] Missing CFBundleShortVersionString")
//                #endif
                return false
            }

            if let url = versionInfo.baseURL, !url.isEmpty {
                if (versionInfo.overrideURL!){
                    baseUrl = url
                }
                
            }
            
            let currentVersion = (versionInfo.version ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let force = versionInfo.forceVersion ?? false

            guard !currentVersion.isEmpty else {
//                #if DEBUG
//                print("[VersionService] Empty version received from server")
//                #endif
                return false
            }

            if force && isNewerVersion(currentVersion, than: appVersion) {
                return true
            }

            return false
            
        } catch {
//            #if DEBUG
//            print("[VersionService] Network error: \(error)")
//            #endif
            throw NSError(domain: "VersionService", code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription])
        }

    }

    /// Returns true when `candidate` is a newer release than `current`.
    /// Compares numeric segments only, ignoring pre-release and build metadata.
    private func isNewerVersion(_ candidate: String, than current: String) -> Bool {
        func segments(_ v: String) -> [Int] {
            return v.split(separator: "-")[0] // drop pre-release suffix
                .split(separator: "+")[0]    // drop build metadata
                .split(separator: ".")
                .map { Int($0) ?? 0 }
        }
        let c = segments(candidate)
        let cur = segments(current)
        let maxCount = max(c.count, cur.count)
        for i in 0..<maxCount {
            let a = i < c.count ? c[i] : 0
            let b = i < cur.count ? cur[i] : 0
            if a != b { return a > b }
        }
        return false
    }

     
}

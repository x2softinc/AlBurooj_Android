//
//  IqamaService.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 9/1/26.
//

//
//  IqamaTimesService.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/31/26.
//

import Foundation
import SwiftUI

class IqamaTimesService {
    
  
    @AppStorage(ANNUAL_TIMES) private var annualTimes = Data()
    @AppStorage(ANNUAL_TIMES_LAST_FETCH) private var lastFetchedDay = ""
    
    
    func fetchIqamaTimes() async throws -> [AnnualTime] {
        
        
        if !annualTimes.isEmpty, lastFetchedDay == todayKey {
            if let info = try? JSONDecoder().decode([AnnualTime].self, from: annualTimes) {
                return info
            }
        }
  
       let service = AuthService()

        // Refresh the auth token if it has already expired.
       
           var token = try await service.getDeviceToken()
           let deviceCode = getDeviceCode()
         
 
        guard !token.isEmpty else {
            throw NSError(
                domain: "IqamaTimesService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Auth token missing."]
            )
        }

        
        let urlString = getBaseUrl() + MasjidProApiPaths.resources.byDeviceCode("annualTimes", deviceCode: deviceCode) + "?recordType=IQAMA"
        //print(urlString, deviceCode)
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "IqamaTimesService",
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
                    domain: "IqamaTimesService",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]
                )
            }

            if http.statusCode == 401 {
                // Token was rejected. Refresh it and retry once.
                token = try await service.getDeviceToken()

                 
                guard !token.isEmpty else {
                    throw NSError(
                        domain: "IqamaTimesService",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Token refresh did not provide a new token."]
                    )
                }

                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let (retryData, retryResponse) = try await URLSession.shared.data(for: request)

                guard let retryHTTP = retryResponse as? HTTPURLResponse,
                      (200...299).contains(retryHTTP.statusCode) else {
                    throw NSError(
                        domain: "IqamaTimesService",
                        code: (retryResponse as? HTTPURLResponse)?.statusCode ?? 0,
                        userInfo: [NSLocalizedDescriptionKey: "Request failed after token refresh."]
                    )
                }

                
                let decodedRetry = try JSONDecoder().decode([AnnualTime].self, from: retryData)
                annualTimes = try JSONEncoder().encode(decodedRetry)
                //print(decodedRetry)
                return decodedRetry
            }

            guard (200...299).contains(http.statusCode) else {
                throw NSError(
                    domain: "IqamaTimesService",
                    code: http.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
                )
            }

            let decoded = try JSONDecoder().decode([AnnualTime].self, from: data)
            annualTimes = try JSONEncoder().encode(decoded)
           // print(decoded)
            return decoded
            
        } catch let error as NSError {
            throw error
        } catch {
            throw NSError(
                domain: "IqamaTimesService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
        }
    }
}


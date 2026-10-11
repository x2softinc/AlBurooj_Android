//
//  ElectronSync.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/31/26.
//

import Foundation
import CryptoKit
import Security
import SwiftUI


class AuthService {
    
    // MARK: - Configuration & Constants

    private let TOKEN_EXPIRY_SKEW_MS: Double = 30 * 1000
    private let DEFAULT_TOKEN_LIFETIME_MS: Double = 60 * 60 * 1000
    private let baseURL = getBaseUrl()
   
    @AppStorage(AUTH_TOKEN) private var token = ""
    @AppStorage(TOKEN_EXPIRES_AT) private var tokenExpiryTime = ""

    private struct PKCEPair {
        let verifier: String
        let challenge: String
    }
    
    private func createPkcePair() -> PKCEPair {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifierData = Data(bytes)
        let verifier = toBase64Url(verifierData)
        
        let hash = SHA256.hash(data: verifier.data(using: .utf8)!)
        let challenge = toBase64Url(Data(hash))
        
        return PKCEPair(verifier: verifier, challenge: challenge)
    }
    
    private lazy var pkce = createPkcePair()

//=================

public func isUnauthorizedError(_ error: Error?) -> Bool {
    guard let err = error as NSError? else { return false }
    if err.code == 401 { return true }
    
    let message = err.localizedDescription.lowercased()
    return message.contains("unauthorized") || message.contains("401")
}
//=========================
public func isConflictError(_ error: Error?) -> Bool {
    guard let err = error as NSError? else { return false }
    if err.code == 409 { return true }
    
    let message = err.localizedDescription.lowercased()
    return message.contains("conflict") || message.contains("409")
}
    
 //--------------------------------
    public func isAuthTokenExpired() -> Bool {
        if token.isEmpty {
            return true
        }
        
        let rawExpiry = tokenExpiryTime
        guard !rawExpiry.isEmpty else {
            return true
        }
        
        let expiry: Double
        if let v = Double(rawExpiry) {
            expiry = v
        } else {
            return true
        }
        
        if expiry <= 0 { return true }
        
        let nowMs = Date().timeIntervalSince1970 * 1000
        return nowMs >= (expiry - TOKEN_EXPIRY_SKEW_MS)
    }
//---------------

private func decodeJwtExpiry(_ token: String) -> Double? {
    let parts = token.components(separatedBy: ".")
    guard parts.count > 1 else { return nil }
    
    var base64 = parts[1]
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    
    let remainder = base64.count % 4
    if remainder > 0 {
        base64.append(String(repeating: "=", count: 4 - remainder))
    }
    
    guard let data = Data(base64Encoded: base64),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let exp = (json["exp"] as? Double) ?? (json["exp"] as? NSNumber)?.doubleValue else {
        return nil
    }
    
    return exp > 0 ? exp * 1000 : nil
}
//---------------------------------------
private func resolveTokenExpiry(token: String, tokenResponse: [String: Any]?) -> Double {
    if let raw = tokenResponse?["expiresIn"] ?? tokenResponse?["expires_in"],
       let expiresIn = (raw as? NSNumber)?.doubleValue ?? (raw as? Double) ?? (raw as? String).flatMap(Double.init) {
        if expiresIn > 0 {
            return (Date().timeIntervalSince1970 * 1000) + (expiresIn * 1000)
        }
    }
    
    if let rawExpiresAt = tokenResponse?["expiresAt"] as? String ?? tokenResponse?["expires_at"] as? String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: rawExpiresAt) {
            return date.timeIntervalSince1970 * 1000
        }
    }
    
    if let jwtExpiry = decodeJwtExpiry(token) {
        return jwtExpiry
    }
    
    return (Date().timeIntervalSince1970 * 1000) + DEFAULT_TOKEN_LIFETIME_MS
}
    
//--------------------------


private func toBase64Url(_ data: Data) -> String {
    return data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

//=============================================

  func getDeviceToken() async throws -> String {
      
      // Refresh the auth token if it has already expired.
//      if !isAuthTokenExpired() {
//          return token
//      }
      
      let deviceCode = getDeviceCode()
      
    let pkce = createPkcePair()
    
    var stateBytes = [UInt8](repeating: 0, count: 16)
    _ = SecRandomCopyBytes(kSecRandomDefault, stateBytes.count, &stateBytes)
    let state = toBase64Url(Data(stateBytes))
    
    let authorization = try await authorizePkceDeviceCode([
        "clientId": CLIENT_ID,
        "deviceCode": deviceCode,
        "redirectUri": REDIRECT_URI,
        "responseType": "code",
        "state": state,
        "scope": "openid profile",
        "codeChallenge": pkce.challenge,
        "codeChallengeMethod": "S256"
    ])
    

    guard let code = authorization["code"] as? String else {
        throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "The authorization server did not return an authorization code."])
    }
    
      
    let tokenResponse = try await oauthTokenAuthorizationCode( [
        "grant_type": "authorization_code",
        "client_id": "masjid-mobile-app",
        "code": code,
        "redirect_uri": REDIRECT_URI,
        "code_verifier": pkce.verifier
    ])
      
      
    
    token = (tokenResponse["accessToken"] as? String ?? tokenResponse["token"] as? String) ?? ""
    if token.isEmpty {
        throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "The authorization server did not return an access token."])
    }
    
    tokenExpiryTime = String(resolveTokenExpiry(token: token, tokenResponse: tokenResponse))
     
    return token
}

 //===================
 
//    
//    // MARK: OAuth
//    public static func authorizePkce(_ payload: [String: Any]) async throws -> [String: Any] {
//        return try await webApi.requestJson("POST", MasjidProApiPaths.oauth.authorizePkce, body: payload)
//    }
//    
    private func authorizePkceDeviceCode(_ payload: [String: String]) async throws -> [String: Any] {
        // 1. Generate a fresh PKCE pair for this request.
        
        // 3. Construct the URL. Adjust the base URL if your API uses a different host.
        
        let urlString = baseURL + MasjidProApiPaths.oauth.authorizePkceDeviceCode
 
        
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "AuthService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Encode the payload as a JSON body.
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
//        #if DEBUG
//        print(urlString, payload)
//        #endif

        
 
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "AuthService",
                code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                userInfo: [NSLocalizedDescriptionKey: "Authorization request failed."]
            )
        }

        // 6. Parse and return the JSON response.
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(
                domain: "AuthService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response."]
            )
        }
        //print("PKCE Side \(json)")
        return json
    }
    //===================
    private  func oauthTokenAuthorizationCode(_ payload: [String: String]) async throws -> [String: Any] {
     
        let urlString = baseURL + MasjidProApiPaths.oauth.token
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "AuthService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"]
            )
        }
        // print(urlString, )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Encode the payload as a JSON body.
        // Encode the payload as a JSON body.
        var components = URLComponents()
        components.queryItems = payload.map { URLQueryItem(name: $0.key, value: $0.value) }
        
       
        // Encode parameters as x-www-form-urlencoded body
        request.httpBody = components.query?.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "AuthService",
                code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                userInfo: [NSLocalizedDescriptionKey: "Token request failed."]
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(
                domain: "AuthService",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response from token endpoint."]
            )
        }
        //print("Token side \(json)")
        return json
    }
    
  
   
  
}

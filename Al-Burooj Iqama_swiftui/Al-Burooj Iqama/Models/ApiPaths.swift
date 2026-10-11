//
//  Untitled.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/31/26.
//

import Foundation
import SwiftUI




public struct MasjidProApiPaths {
    public struct Auth {
        public let login = "/api/auth/login"
        public let me = "/api/auth/me"
        public let forgotPassword = "/api/auth/forgot-password"
        public let resetPassword = "/api/auth/reset-password"
    }
    
    public struct OAuth {
        public let authorizePkce = "/oauth/authorize-pkce"
        public let authorizePkceDeviceCode = "/oauth/authorize-pkce-deviceCode"
        public let token = "/oauth/token"
        public let clients = "/oauth/clients"
    }
    
    public struct Device {
        public let register = "/api/device/register"
        public let all = "/api/device/all"
        
        public func byUser(_ userEmail: String) -> String {
            let allowed = CharacterSet.urlPathAllowed
            guard let encoded = userEmail.addingPercentEncoding(withAllowedCharacters: allowed) else { return "" }
            return "/api/device/by-user/\(encoded)"
        }

        public func byDeviceCode(_ deviceCode: String) -> String {
            let allowed = CharacterSet.urlPathAllowed
            guard let encoded = deviceCode.addingPercentEncoding(withAllowedCharacters: allowed) else { return "" }
            return "/api/device/\(encoded)"
        }

        public func validate(_ deviceCode: String) -> String {
            let allowed = CharacterSet.urlPathAllowed
            guard let encoded = deviceCode.addingPercentEncoding(withAllowedCharacters: allowed) else { return "" }
            return "/api/device/\(encoded)/validate"
        }

        public func deactivate(_ deviceCode: String) -> String {
            let allowed = CharacterSet.urlPathAllowed
            guard let encoded = deviceCode.addingPercentEncoding(withAllowedCharacters: allowed) else { return "" }
            return "/api/device/\(encoded)/deactivate"
        }
    }
    
    public struct Resources {
        public func list(_ resource: String) -> String {
            return "/api/\(resource)"
        }
        
        public func byDeviceCode(_ resource: String, deviceCode: CustomStringConvertible) -> String {
            guard let encoded = String(describing: deviceCode).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return "" }
            return "/api/\(resource)/masjid/\(encoded)"
        }
        
        public func byId(_ resource: String, id: CustomStringConvertible) -> String {
            guard let encoded = String(describing: id).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return "" }
            return "/api/\(resource)/\(encoded)"
        }
    }
    
    
    public static let auth = Auth()
    public static let oauth = OAuth()
    public static let device = Device()
    public static let resources = Resources()
    
}

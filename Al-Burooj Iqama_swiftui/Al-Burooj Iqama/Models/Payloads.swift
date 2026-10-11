//
//  Payloads.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/31/26.
//

// MARK: - Payload Transfer Models

public struct LoginPayload {
    public let username: String
    public let password: String
    public let clientId: String
}

public struct ForgotPasswordPayload {
    public let email: String
}

public struct ResetPasswordPayload {
    public let email: String
    public let token: String
    public let newPassword: String
}

public struct RegisterDevicePayload {
    public let userEmail: String
    public let deviceName: String
}

public struct authPayLoad {
    public let clientId : String
    public let deviceCode : String
    public let redirectUri : String
    public let responseType : String
    public let state: String
    public let scope: String
    public let codeChallenge: String
    public let codeChallengeMethod: String
}

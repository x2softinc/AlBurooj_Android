//
//  ColorExtension.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 9/3/26.
//

import SwiftUI

extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

// Usage:
let maroonColor = Color(hex: 0x800000)

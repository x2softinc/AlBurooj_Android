//
//  PrayerSettings.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/30/26.
//
import Foundation
struct PrayerSetting : Codable{
    var id: Int? = nil
    var deviceCode: String? = nil
    var calcMethod: String = "MWL"
    var maintMethod: Int = 0
    var jumma: String? = nil
    var jumma2: String? = nil
    var hijriAdjustment: Int = 0
    var asrMethod: Int = 0
    var maghribDelay: Int = 3
    var roundMinutes: Int = 0
 
}

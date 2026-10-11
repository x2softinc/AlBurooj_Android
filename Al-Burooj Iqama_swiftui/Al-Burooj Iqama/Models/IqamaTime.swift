//
//  IqamaTime.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 9/2/26.
//
import Foundation
struct IqamaTime: Codable {
    var fajr: Date? = nil
    var dhuhar: Date? = nil
    var asar: Date? = nil
    var maghrib: Date? = nil
    var isha: Date? = nil
}

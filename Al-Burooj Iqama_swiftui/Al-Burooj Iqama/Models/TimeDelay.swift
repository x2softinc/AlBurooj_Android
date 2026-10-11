//
//  TimeDelays.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/30/26.
//
import Foundation
struct TimeDelay : Codable{
    var id: Int? = nil
    var masjidCode: String? = nil
    var fajr: Int = 0
    var dhuhar: Int = 0
    var asr: Int = 0
    var isha: Int = 0
}

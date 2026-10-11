//
//  FixedIqamaTimes.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/30/26.
//
import Foundation
struct FixedTime : Codable{
    var id: Int? = nil
    var masjidCode: String? = nil
    var fajr: String? = nil
    var dhuhar: String? = nil
    var asr: String? = nil
    var isha: String? = nil
}

//
//  AnnualTimes.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/30/26.
//
import Foundation
struct AnnualTime : Codable{
    var id: Int? = nil
    var recordType : String? = nil
    var masjidCode: String? = nil
    var month: Int? = nil
    var fromDay: Int? = nil
    var toDay: Int? = nil
    var fajrTime: String? = nil
    var dhuharTime: String? = nil
    var asrTime: String? = nil
    var maghribTime: String? = nil
    var ishaTime: String? = nil
}

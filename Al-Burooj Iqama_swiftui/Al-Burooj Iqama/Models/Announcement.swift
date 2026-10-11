//
//  Announcement.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/30/26.
//
import Foundation
struct Announcement : Codable{
    var id: Int = 0
    var masjidCode: String? = nil
        var fromDate: Date? = nil
        var toDate: Date? = nil
        var infoText: String? = nil
}

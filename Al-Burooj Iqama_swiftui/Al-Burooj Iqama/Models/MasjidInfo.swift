//
//  MasjidInfo.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/30/26.
//
import Foundation
struct MasjidInfo : Codable{
    var id: Int? = nil
    var masjidCode: String? = nil
    var masjidName: String? = nil
    var address: String? = nil
    var address1: String? = nil
    var city: String? = nil
    var state: String? = nil
    var postalCode: String? = nil
    var country: String? = nil
    var email: String? = nil
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var phone: String? = nil
    var url: String? = nil
}

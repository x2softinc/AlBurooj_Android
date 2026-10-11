//
//  deviceCodeHelper.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 9/4/26.
//
import SwiftUI

func getDeviceCode()  -> String {
    
    @AppStorage(DEVICE_CODE)  var deviceCode = ""
    if  (deviceCode.isEmpty) {
        deviceCode = "18549825"
    }
    deviceCode = "18549825"  //force
    return deviceCode
}

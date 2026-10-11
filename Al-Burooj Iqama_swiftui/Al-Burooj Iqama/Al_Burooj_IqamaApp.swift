//
//  Al_Burooj_IqamaApp.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 8/29/26.
//

import SwiftUI
import SwiftData

@main
struct Al_Burooj_IqamaApp: App {
    

    var body: some Scene {
        WindowGroup {
            AppVersionGate(appStoreURL: URL(string: APP_URL)!) {
                ContentView()
            }
        }
         
    }
}

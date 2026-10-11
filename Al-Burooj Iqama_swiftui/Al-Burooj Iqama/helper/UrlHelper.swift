//
//  UrlHelper.swift
//  Al-Burooj Iqama
//
//  Created by Shiha on 9/9/26.
//
  import SwiftUI
  func getBaseUrl() -> String {
      @AppStorage(BASE_URL) var baseUrl = ""
      if (baseUrl.isEmpty) {
          baseUrl = "https://masjidpro.x2softinc.com"
      }
      return baseUrl
}

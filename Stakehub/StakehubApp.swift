//
//  StakehubApp.swift
//  Stakehub
//
//  Created by Mohit Khairia on 24/01/25.
//

import SwiftUI
import FirebaseCore
import UserNotifications

@main
struct StakehubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var webViewStore = WebViewStore()
    @StateObject private var deepLink    = DeepLinkManager.shared
    
    @State private var isActive: Bool = true
    var body: some Scene {
        WindowGroup {
            if isActive {
                LaunchScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isActive = false
                        }
                    }
            } else {
                ContentView()
                    .environmentObject(webViewStore)
                    .environmentObject(deepLink)
                    .preferredColorScheme(.light)
            }
        }
    }
}

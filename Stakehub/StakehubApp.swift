//
//  StakehubApp.swift
//  Stakehub
//
//  Created by Mohit Khairia on 24/01/25.
//

import SwiftUI

@main
struct StakehubApp: App {
    @State private var isActive = true

    var body: some Scene {
        WindowGroup {
            if isActive {
                LaunchScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isActive = false
                        }
                    }
            } else {
                ContentView()
            }
        }
    }
}

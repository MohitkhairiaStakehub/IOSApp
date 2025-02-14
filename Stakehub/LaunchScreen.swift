//
//  LaunchScreen.swift
//  Stakehub
//
//  Created by Stakehub Dev on 10/02/25.
//

import SwiftUI

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            Image("logo") // Ensure "logo" exists in Assets.xcassets
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200, maxHeight: 200) // Use maxWidth/maxHeight instead of fixed width/height
        }
    }
}



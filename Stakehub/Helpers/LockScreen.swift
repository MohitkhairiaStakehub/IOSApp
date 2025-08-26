//
//  LockScreen.swift
//  Stakehub
//
//  Created by Stakehub Dev on 21/08/25.
//
import SwiftUI

struct LockScreen: View {
    let unlockTapped: () -> Void
    let logoutTapped: () -> Void

    var body: some View {
        ZStack {
            // dim the content
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)

                Text("Stakehub Locked")
                    .font(.title2).bold()
                    .foregroundColor(.white)

                Text("Use Face ID / Touch ID or your passcode to continue.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 24)

                Button(action: unlockTapped) {
                    Text("Unlock")
                        .font(.headline)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                .padding(.top, 6)

                Button(role: .destructive, action: logoutTapped) {
                    Text("Log out")
                        .font(.subheadline.weight(.medium))
                        .padding(.top, 4)
                }
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(Color.black.opacity(0.35))
            .cornerRadius(18)
            .padding(.horizontal, 24)
        }
        .accessibilityIdentifier("StakehubLockScreen")
    }
}

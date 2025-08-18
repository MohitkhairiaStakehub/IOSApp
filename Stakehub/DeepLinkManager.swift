//
//  DeepLinkManager.swift
//  Stakehub
//
//  Created by Stakehub Dev on 14/08/25.
//

// DeepLinkManager.swift
import Foundation
final class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    private init() {}

    // store the last tapped URL until UI consumes it
    @Published var pendingURL: URL?
}

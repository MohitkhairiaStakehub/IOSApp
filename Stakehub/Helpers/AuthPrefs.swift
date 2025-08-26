//
//  AuthPrefs.swift
//  Stakehub
//
//  Created by Stakehub Dev on 21/08/25.
//

import Foundation

enum AuthPrefs {
    static let key = "stakehub.isLoggedIn"
    static var isLoggedIn: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

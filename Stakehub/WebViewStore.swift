//
//  WebViewStore.swift
//  Stakehub
//
//  Created by Stakehub Dev on 02/04/25.
//

import Foundation
import WebKit

class WebViewStore: ObservableObject {
    @Published var webView: WKWebView

    init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default() // Enables cookie and cache persistence

        self.webView = WKWebView(frame: .zero, configuration: config)
    }
}

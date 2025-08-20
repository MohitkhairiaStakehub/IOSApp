//
//  ContentView.swift
//  Stakehub
//
//  Created by Mohit Khairia on 24/01/25.
//
import SwiftUI
@preconcurrency import WebKit

struct ContentView: View {
    @EnvironmentObject var webViewStore: WebViewStore
    @EnvironmentObject var deepLink: DeepLinkManager
    
    var body: some View {
        VStack {
            WebView(webView: $webViewStore.webView, urlString: "https://testfrontend.stakehub.in")
        }
         // ➊ Handle warm/foreground taps
        .onReceive(NotificationCenter.default.publisher(for: .openDeepLink)) { note in
            if let url = note.object as? URL {
                webViewStore.webView.load(URLRequest(url: url))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .networkStatusChanged)) { note in
            guard let isOnline = note.object as? Bool, isOnline else { return }

            // If we’re currently showing the offline file, go back to home or last URL
            let showingOffline = webViewStore.webView.url?.lastPathComponent == "offline.html"
            if showingOffline {
                if let last = (webViewStore.webView.backForwardList.forwardList.last?.url)
                    ?? (webViewStore.webView.backForwardList.backList.last?.url) {
                    webViewStore.webView.load(URLRequest(url: last))
                } else if let home = URL(string: "https://testfrontend.stakehub.in") {
                    webViewStore.webView.load(URLRequest(url: home))
                }
            }
        }
        // ➋ Handle cold-start case (event may have fired before this view existed)
        .onAppear {
            if let url = deepLink.pendingURL {
                webViewStore.webView.load(URLRequest(url: url))
                deepLink.pendingURL = nil // consume it
            }
        }
        // ➌ FCM token to page
        .onReceive(NotificationCenter.default.publisher(for: .fcmTokenUpdated)) { note in
            guard let token = note.object as? String else { return }
            let js = """
            window.__fcm_token = \(jsonString(token));
            window.dispatchEvent(new CustomEvent('fcm-token-ready', { detail: { platform: 'ios', token: \(jsonString(token)) } }));
            """
            webViewStore.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    // Safely quote a Swift string into JS as JSON
    private func jsonString(_ s: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [s])
        let raw = String(data: data, encoding: .utf8)! // -> ["actual"]
        return String(raw.dropFirst().dropLast())      // -> "actual"
    }
}

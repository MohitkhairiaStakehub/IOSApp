//
//  WebView.swift.swift
//  Stakehub
//
//  Created by Stakehub Dev on 10/02/25.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let webViewConfig = WKWebViewConfiguration()

        // ✅ Enable JavaScript using recommended method
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        webViewConfig.defaultWebpagePreferences = preferences

        webViewConfig.allowsInlineMediaPlayback = true // Allow inline videos
        webViewConfig.mediaTypesRequiringUserActionForPlayback = [] // Auto-play media

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.allowsBackForwardNavigationGestures = true // Enable gestures
        webView.navigationDelegate = context.coordinator // Handle loading, errors, navigation
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            var request = URLRequest(url: url)
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    request.timeoutInterval = 30
                    webView.load(request)
        } else {
            print("Invalid URL: \(urlString)")
        }
//        if let url = URL(string: urlString) {
//            webView.load(URLRequest(url: url))
//        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView finished loading.")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Failed to load: \(error.localizedDescription)")
        }	
    }
}

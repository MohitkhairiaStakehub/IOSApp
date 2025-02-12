//
//  WebView.swift.swift
//  Stakehub
//
//  Created by Stakehub Dev on 10/02/25.
//

import SwiftUI
@preconcurrency import WebKit

struct WebView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let webViewConfig = WKWebViewConfiguration()

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        webViewConfig.defaultWebpagePreferences = preferences

        webViewConfig.allowsInlineMediaPlayback = true
        webViewConfig.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator

        // ✅ Force High-Resolution Rendering
        webView.contentScaleFactor = UIScreen.main.scale
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.contentScaleFactor = UIScreen.main.scale

        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 30
            webView.load(request)
        } else {
            print("Invalid URL: \(urlString)")
        }

        // ✅ Add Pull-to-Refresh
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.refreshWebView(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        // ✅ Store WebView in Coordinator
        context.coordinator.webView = webView

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var webView: WKWebView?

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView finished loading.")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Failed to load: \(error.localizedDescription)")
        }

        // ✅ Handle External Links
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                       let host = url.host
                       if host != "testfrontend.stakehub.in" { // Change this to your domain
                           UIApplication.shared.open(url) // Opens external links in Safari
                           decisionHandler(.cancel)
                           return
                       }
                   }
                   decisionHandler(.allow) // ✅ Allow internal links
        }

        @objc func refreshWebView(_ refreshControl: UIRefreshControl) {
            webView?.reloadFromOrigin()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                refreshControl.endRefreshing()
            }
        }
    }
}

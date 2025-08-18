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
            WebViewWrapper(webView: $webViewStore.webView, urlString: "https://testfrontend.stakehub.in")
        }
         // ➊ Handle warm/foreground taps
        .onReceive(NotificationCenter.default.publisher(for: .openDeepLink)) { note in
            if let url = note.object as? URL {
                webViewStore.webView.load(URLRequest(url: url))
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

struct WebViewWrapper: UIViewRepresentable {
    @Binding var webView: WKWebView
    let urlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = webView
        webView.navigationDelegate = context.coordinator // Set delegate
        
        if let url = URL(string: urlString),   webView.url == nil  {
            webView.load(URLRequest(url: url))
        }
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.refreshWebView), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper
        
        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }
        
        @objc func refreshWebView(refreshControl: UIRefreshControl) {
            parent.webView.reload()
            refreshControl.endRefreshing()
        }
        
        // MARK: - Handle External Links
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            print("URL Clicked: \(navigationAction.request.url?.absoluteString ?? "Unknown")")
            
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            let kick = """
                if (window.__fcm_token) {
                  window.dispatchEvent(new CustomEvent('fcm-token-ready', { detail: { platform: 'ios', token: window.__fcm_token } }));
                }
                """
                webView.evaluateJavaScript(kick, completionHandler: nil)
            
            let urlString = url.absoluteString

            // Instagram Deep Link
            if urlString.contains("https://www.instagram.com/stakehub.in/") {
                openApp(urlScheme: "instagram://profile/stakehub.in", fallbackURL: url)
                decisionHandler(.cancel)
                return
            }

            // LinkedIn Deep Link
            if urlString.contains("https://www.linkedin.com/company/stakehub-infotech/") {
                openApp(urlScheme: "linkedin://company/stakehub-infotech", fallbackURL: url)
                decisionHandler(.cancel)
                return
            }

            // YouTube Deep Link
            if urlString.contains("https://www.youtube.com/@stakehub/") {
                openApp(urlScheme: "youtube://www.youtube.com/@stakehub/", fallbackURL: url)
                decisionHandler(.cancel)
                return
            }
            
            if urlString.hasSuffix(".pdf") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            
            // Specific Link
            if urlString.contains("https://g.page/r/CWAgUdxaj-4eEBM/review") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)  // Allow internal links
          
        }

        // Helper function to open an app if installed, otherwise open in Safari
        func openApp(urlScheme: String, fallbackURL: URL) {
            if let appURL = URL(string: urlScheme), UIApplication.shared.canOpenURL(appURL) {
                UIApplication.shared.open(appURL)
            } else {
                UIApplication.shared.open(fallbackURL) // Open in Safari if app is not installed
            }
        }

    }
    
}

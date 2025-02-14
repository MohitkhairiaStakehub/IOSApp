//
//  ContentView.swift
//  Stakehub
//
//  Created by Mohit Khairia on 24/01/25.
//
import SwiftUI
@preconcurrency import WebKit

struct ContentView: View {
    @State private var webView = WKWebView()
    
    var body: some View {
        VStack {
            WebViewWrapper(webView: $webView, urlString: "https://testfrontend.stakehub.in")
        }
    }
}

struct WebViewWrapper: UIViewRepresentable {
    @Binding var webView: WKWebView
    let urlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator // Set delegate
        
        if let url = URL(string: urlString) {
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

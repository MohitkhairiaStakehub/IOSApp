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
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.configuration.websiteDataStore = WKWebsiteDataStore.default()

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
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.refreshWebView), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        // Optionally, keep a reference to the web view if needed.
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

        // Allow all navigation actions.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(.allow)
        }
        
        // Handle new window requests (e.g., target="_blank")
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        // Handle PDF Downloads (unchanged)
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationResponse: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            guard let url = navigationResponse.response.url else {
                decisionHandler(.allow)
                return
            }

            let mimeType = navigationResponse.response.mimeType
            if mimeType == "application/pdf" {
                print("Downloading PDF from: \(url)")
                DispatchQueue.global(qos: .background).async {
                    if let pdfData = try? Data(contentsOf: url) {
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("downloaded.pdf")
                        do {
                            try pdfData.write(to: tempURL)
                            DispatchQueue.main.async {
                                self.presentShareSheet(fileURL: tempURL)
                            }
                        } catch {
                            print("Error saving PDF: \(error.localizedDescription)")
                        }
                    }
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        // Present the share sheet for PDFs.
        private func presentShareSheet(fileURL: URL) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first {
                let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                window.rootViewController?.present(activityViewController, animated: true, completion: nil)
            }
        }
       // Pull-to-Refresh function.
        @objc func refreshWebView(_ refreshControl: UIRefreshControl) {
            webView?.reloadFromOrigin()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                refreshControl.endRefreshing()
            }
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers
import SafariServices
@preconcurrency import WebKit
import MessageUI
struct WebView: UIViewRepresentable {
    @Binding var webView: WKWebView
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let webViewConfig = WKWebViewConfiguration()

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        webViewConfig.defaultWebpagePreferences = preferences

        webViewConfig.allowsInlineMediaPlayback = true
        webViewConfig.mediaTypesRequiringUserActionForPlayback = []

//        let webView = WKWebView(frame: .zero, configuration: webViewConfig)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
//        webView.configuration.websiteDataStore = WKWebsiteDataStore.default()
        // JS -> native bridge
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "authState")
        webView.configuration.userContentController.add(context.coordinator, name: "authState")
        // ✅ Force High-Resolution Rendering
        webView.contentScaleFactor = UIScreen.main.scale
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.contentScaleFactor = UIScreen.main.scale

        if let url = URL(string: urlString), webView.url == nil {
            if NetworkMonitor.shared.isOnline {
                var request = URLRequest(url: url)
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.timeoutInterval = 30
                webView.load(request)
            } else {
                loadOfflinePage(into: webView)   // or self.loadOfflinePage(into: webView)
            }
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
    
    // MARK: - Offline loader (shared by makeUIView & Coordinator)
    private func loadOfflinePage(into webView: WKWebView) {
        // Try Resources/offline/offline.html first, then just offline.html at bundle root
        let candidate =
            Bundle.main.url(forResource: "offline", withExtension: "html", subdirectory: "offline") ??
            Bundle.main.url(forResource: "offline", withExtension: "html")
        guard let url = candidate else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    
    class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
        private let completion: ([URL]?) -> Void

        init(completion: @escaping ([URL]?) -> Void) {
            self.completion = completion
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            completion(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            completion(nil)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, MFMailComposeViewControllerDelegate, WKScriptMessageHandler {
        var parent: WebView
        private var lastRequestedURL: URL? // remember where we tried to go
        // Optionally, keep a reference to the web view if needed.
//        var webView: WKWebView?
        var documentPickerDelegate: DocumentPickerDelegate?
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        // Helper to present a VC from the current window scene
        private func present(_ vc: UIViewController) {
            guard
                let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let root = scene.windows.first?.rootViewController
            else { return }
            root.present(vc, animated: true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let kick = """
            if (window.__fcm_token) {
              window.dispatchEvent(new CustomEvent('fcm-token-ready', { detail: { platform: 'ios', token: window.__fcm_token } }));
            }
            """
            webView.evaluateJavaScript(kick, completionHandler: nil)
        }

        // When a provisional navigation fails (DNS/connection/etc)
        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            if isOfflineError(error) {
                parent.loadOfflinePage(into: webView)
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if isOfflineError(error) {
                        parent.loadOfflinePage(into: webView)
            }
            print("Failed to load: \(error.localizedDescription)")
        }
        
        

        // Allow/handle external schemes and special links
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            print("URL Clicked: \(navigationAction.request.url?.absoluteString ?? "Unknown")")

            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // First handle system schemes (phone, sms, facetime, mail)
            if let scheme = url.scheme?.lowercased() {
                switch scheme {
                case "tel", "telprompt", "sms", "facetime", "facetime-audio":
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                    return
                case "mailto":
                    if MFMailComposeViewController.canSendMail() {
                        let composer = MFMailComposeViewController()
                        composer.mailComposeDelegate = self
                        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                            if let addr = comps.path.removingPercentEncoding, !addr.isEmpty {
                                composer.setToRecipients([addr])
                            }
                            if let q = comps.queryItems {
                                if let subject = q.first(where: { $0.name == "subject" })?.value?.removingPercentEncoding {
                                    composer.setSubject(subject)
                                }
                                if let body = q.first(where: { $0.name == "body" })?.value?.removingPercentEncoding {
                                    composer.setMessageBody(body, isHTML: false)
                                }
                            }
                        }
                        present(composer)
                    } else {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                    decisionHandler(.cancel)
                    return
                default:
                    break
                }
            }

            // Kick JS so page gets the token ASAP
            let kick = """
                if (window.__fcm_token) {
                  window.dispatchEvent(new CustomEvent('fcm-token-ready', { detail: { platform: 'ios', token: window.__fcm_token } }));
                }
                """
            webView.evaluateJavaScript(kick, completionHandler: nil)

            let urlString = url.absoluteString

            // Social/app deep links
            if urlString.contains("https://www.instagram.com/stakehub.in/") {
                openApp(urlScheme: "instagram://profile/stakehub.in", fallbackURL: url)
                decisionHandler(.cancel)
                return
            }
            if urlString.contains("https://www.linkedin.com/company/stakehub-infotech/") {
                openApp(urlScheme: "linkedin://company/stakehub-infotech", fallbackURL: url)
                decisionHandler(.cancel)
                return
            }
            if urlString.contains("https://www.youtube.com/@stakehub/") {
                openApp(urlScheme: "youtube://www.youtube.com/@stakehub/", fallbackURL: url)
                decisionHandler(.cancel)
                return
            }

            // Open PDFs externally
            if urlString.lowercased().hasSuffix(".pdf") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            // Specific external link
            if urlString.contains("https://g.page/r/CWAgUdxaj-4eEBM/review") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            // Otherwise allow the navigation in the web view
            decisionHandler(.allow)
        }
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "authState" else { return }
            if let body = message.body as? [String: Any],
               let loggedIn = body["loggedIn"] as? Bool {
                AuthPrefs.isLoggedIn = loggedIn
                print("[AuthPrefs] isLoggedIn =", loggedIn)
            }
        }
        private func openApp(urlScheme: String, fallbackURL: URL) {
            if let appURL = URL(string: urlScheme), UIApplication.shared.canOpenURL(appURL) {
                UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.open(fallbackURL, options: [:], completionHandler: nil)
            }
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
        
        private func isOfflineError(_ error: Error) -> Bool {
            let ns = error as NSError
            // Common offline cases:
            return ns.domain == NSURLErrorDomain && (
                ns.code == NSURLErrorNotConnectedToInternet ||
                ns.code == NSURLErrorTimedOut ||
                ns.code == NSURLErrorNetworkConnectionLost ||
                ns.code == NSURLErrorCannotFindHost ||
                ns.code == NSURLErrorCannotConnectToHost ||
                ns.code == NSURLErrorDNSLookupFailed
            )
        }

       
        func webView(_ webView: WKWebView,
                     runOpenPanelWith parameters: Any,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping ([URL]?) -> Void) {

            if #available(iOS 14.0, *),
               let panelParams = parameters as? NSObject,
               let allowsMultipleSelection = panelParams.value(forKey: "allowsMultipleSelection") as? Bool {

                let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
                documentPicker.allowsMultipleSelection = allowsMultipleSelection

                let pickerDelegate = DocumentPickerDelegate(completion: completionHandler)
                self.documentPickerDelegate = pickerDelegate
                documentPicker.delegate = pickerDelegate

                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = scene.windows.first?.rootViewController {
                    rootVC.present(documentPicker, animated: true)
                }
            } else {
                completionHandler(nil)
            }
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
            parent.webView.reloadFromOrigin()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                refreshControl.endRefreshing()
            }
        }
        
        // MARK: - MFMailComposeViewControllerDelegate
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true)
        }
    }
}

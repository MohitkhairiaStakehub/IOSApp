//
//  ContentView.swift
//  Stakehub
//
//  Created by Mohit Khairia on 24/01/25.
//
import SwiftUI
@preconcurrency import WebKit
import UIKit

struct ContentView: View {
    @EnvironmentObject var webViewStore: WebViewStore
    @EnvironmentObject var deepLink: DeepLinkManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLock = false    // <- overlay if biometrics not available / failed
    @State private var isGating = false          // prevent re-entrancy
    @State private var lastUnlockAt = Date.distantPast  // cool-down marker
    @State private var previousPhase: ScenePhase = .active // remember last phase
    var body: some View {
        ZStack {
                    VStack {
                        if !showLock {
                                            WebView(webView: $webViewStore.webView, urlString: "https://www.stakehub.in")
                        }
                    }
                    
                    // 🔒 Lock overlay when biometrics aren’t available or user cancels
                    if showLock {
                        Color.white
                                    .ignoresSafeArea()
                                    .zIndex(9) // Ensures it's above the WebView
                        LockScreen(
                            unlockTapped: { presentGate(forceDashboard: true, userInitiated: true) },
                            logoutTapped:  { handleLogout() }
                        )
                        .transition(.opacity)
                        .zIndex(10)
                        .allowsHitTesting(!isGating)
                    }
                }
        
         // ➊ Handle warm/foreground taps
        .onReceive(NotificationCenter.default.publisher(for: .openDeepLink)) { note in
            if let url = note.object as? URL, !showLock {
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
                } else if let home = URL(string: "https://www.stakehub.in") {
                    webViewStore.webView.load(URLRequest(url: home))
                }
            }
        }
        // ➌ Cold-start: consume any pending push deep link
        .onAppear {
            if AuthPrefs.isLoggedIn {
                showLock = true         // ensure overlay is up first
            }
//            if let url = deepLink.pendingURL {
//                webViewStore.webView.load(URLRequest(url: url))
//                deepLink.pendingURL = nil
//                return
//            }
            DispatchQueue.main.async {
                presentGate(forceDashboard: true)
            }
        }
        
        // ➍ Foreground every time: re-gate if user is logged in
        // Foreground: only when returning from background, and not re-entrant
                .onChange(of: scenePhase) { phase in
                    defer { previousPhase = phase }
                    guard phase == .active else { return }

                    // Only gate when we *came from background* (not from FaceID’s brief inactive)
                    guard previousPhase == .background else { return }

                    // Don’t interrupt a just-arrived deep link
                    if deepLink.pendingURL != nil { return }

                    // Avoid re-entrancy
                    if isGating { return }

                    // Small cool-down after a successful unlock
                    if Date().timeIntervalSince(lastUnlockAt) < 0.5 { return }

                    presentGate(forceDashboard: true)
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
    
    private func loadPostUnlockDestination(forceDashboard: Bool) {
            // Priority: pending deep link > dashboard (if requested) > home
            if let pending = deepLink.pendingURL {
                webViewStore.webView.load(URLRequest(url: pending))
                deepLink.pendingURL = nil
                return
            }
            if forceDashboard, let dash = URL(string: "https://www.stakehub.in/dashboard") {
                webViewStore.webView.load(URLRequest(url: dash))
                return
            }
            if let home = URL(string: "https://www.stakehub.in") {
                webViewStore.webView.load(URLRequest(url: home))
            }
        }
    
    func appIsForegroundActive() -> Bool {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return false }
        // Also ensure there is a key window
        return scene.windows.contains(where: { $0.isKeyWindow })
    }
    // MARK: - Gate logic
    /// Ask for Face ID/Touch ID (falls back to device passcode).
    /// If unavailable or user cancels -> show lock overlay.

    private func presentGate(forceDashboard: Bool, userInitiated: Bool = false) {
        guard AuthPrefs.isLoggedIn else { return }

        // If the user tapped Unlock, override reentrancy/cooldown
        if isGating && !userInitiated { return }
        // keep the overlay up while prompting
        showLock = true

        // only prompt when really active on screen
        guard UIApplication.shared.applicationState == .active, appIsForegroundActive() else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
                presentGate(forceDashboard: forceDashboard, userInitiated: userInitiated)
            }
            return
        }

        isGating = true
        Biometrics.authenticate(reason: "Confirm it’s you to open Stakehub") { ok in
            self.isGating = false
            if ok {
                withAnimation { self.showLock = false }
                self.loadPostUnlockDestination(forceDashboard: forceDashboard)

            } else {
                // stay on lock; user can press Unlock to retry
                self.showLock = true
            }
        }
    }

    // MARK: - Logout (native, direct request + cookie aware)
    private func handleLogout() {
        // Prevent the gate from re-prompting while we exit
        isGating = false
        showLock = true

        // 1) Build the logout URL
        guard let logoutURL = URL(string: "https://www.stakehub.in/api/auth/logout") else {
            hardResetToHome()
            return
        }

        // 2) Pull cookies from WKWebView's store and send the request using URLSession
        let cookieStore = webViewStore.webView.configuration.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            // Create the Cookie header for this domain
            let cookieHeader = Self.cookieHeader(for: logoutURL, from: cookies)

            var req = URLRequest(url: logoutURL)
            req.httpMethod = "GET"
            req.cachePolicy = .reloadIgnoringLocalCacheData
            if !cookieHeader.isEmpty {
                req.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
            // If your server accepts cookie-only logout, this is enough.
            // If it ALSO requires an Authorization header, add it here once you have the token:
            // req.setValue("Bearer \(encryptAuthKey)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: req) { _, _, _ in
                // 3) Regardless of network result, clear web data & go home
                DispatchQueue.main.async { self.finishLogoutAndReset() }
            }.resume()
        }
    }

    // Compose a Cookie header string for this URL from available cookies
    private static func cookieHeader(for url: URL, from cookies: [HTTPCookie]) -> String {
        let matching = cookies.filter { cookie in
            guard let domain = cookie.domain.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else { return false }
            // Basic domain match (WK cookies are usually `.yourdomain.com`)
            let host = url.host ?? ""
            let domainMatches = host == domain || host.hasSuffix("." + domain) || domain.hasSuffix("." + host)
            let pathMatches = (url.path.hasPrefix(cookie.path) || cookie.path == "/")
            return domainMatches && pathMatches
        }
        guard !matching.isEmpty else { return "" }
        return matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    // Finish: clear cookies/storage, flip auth, and load `/`
    private func finishLogoutAndReset() {
        AuthPrefs.isLoggedIn = false
        webViewStore.webView.stopLoading()

        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            store.removeData(ofTypes: types, for: records) {
                // Extra belt-and-suspenders
                HTTPCookieStorage.shared.cookies?.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
                URLCache.shared.removeAllCachedResponses()

                withAnimation { self.showLock = false }

                // Finally go to home
                if let home = URL(string: "https://www.stakehub.in/") {
                    self.webViewStore.webView.load(URLRequest(url: home))
                }
            }
        }
    }

    // Fallback when URL building fails, or if you want an immediate reset
    private func hardResetToHome() {
        AuthPrefs.isLoggedIn = false
        webViewStore.webView.stopLoading()
        withAnimation { self.showLock = false }
        if let home = URL(string: "https://www.stakehub.in/") {
            webViewStore.webView.load(URLRequest(url: home))
        }
    }

    // Safely quote a Swift string into JS as JSON
    private func jsonString(_ s: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [s])
        let raw = String(data: data, encoding: .utf8)! // -> ["actual"]
        return String(raw.dropFirst().dropLast())      // -> "actual"
    }
}

//
//  ContentView.swift
//  Stakehub
//
//  Created by Mohit Khairia on 24/01/25.
//
import SwiftUI
import WebKit

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

    class Coordinator: NSObject {
        var parent: WebViewWrapper

        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }

        @objc func refreshWebView(refreshControl: UIRefreshControl) {
            parent.webView.reload()
            refreshControl.endRefreshing()
        }
    }
}

//
//  HeadlessHTMLRenderer.swift
//  stts
//

import Cocoa
import WebKit

// Because some services obfuscate the javascript a LOT (whyyyyyy? why do you even need javascript for a status page?
// this why I quit web development, y'all keep making stuff up just to keep yourself relevant) and we have better things
// to do than decrypt that, this is a wrapper that creates a web view to render the page and run its javascript
// only to read the DOM then discard the web view immediately. The Web Content process that gets spawned likely uses
// more memory than the entire stts app and should not be allowed to stay alive.
// This is a last resort and shouldn't be used unless necessary otherwise we would be creating too many web views (and/
// or have to make some sort of limiter to deal with that...)
@MainActor
class HeadlessHTMLRenderer: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String?, Never>?

    func retrieveRenderedHTML(for url: URL) async -> String? {
        await withCheckedContinuation { continuation in
            // Resume and discard any in-flight request
            self.continuation?.resume(returning: nil)

            self.continuation = continuation
            let webView = WKWebView()
            webView.navigationDelegate = self
            webView.load(URLRequest(url: url))
            self.webView = webView
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView == self.webView, let continuation else { return }
        self.continuation = nil

        Task {
            let html = try? await webView.evaluateJavaScript("document.body.innerHTML")
            continuation.resume(returning: html as? String)

            // Discard the web view so that the web content process is killed
            if webView == self.webView { self.webView = nil }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        guard webView == self.webView, let continuation else { return }
        self.continuation = nil
        self.webView = nil
        continuation.resume(returning: nil)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        guard webView == self.webView, let continuation else { return }
        self.continuation = nil
        self.webView = nil
        continuation.resume(returning: nil)
    }
}

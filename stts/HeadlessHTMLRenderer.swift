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
class HeadlessHTMLRenderer: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var callback: ((String?) -> Void)?

    func retrieveRenderedHTML(for url: URL, callback: @escaping (String?) -> Void) {
        // Throw away current callback and web view
        self.callback = nil
        self.webView = nil

        // Create new web view and set up delegate/callback
        self.callback = callback
        let webView = WKWebView()
        webView.navigationDelegate = self
        webView.load(URLRequest(url: url))
        self.webView = webView
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView == self.webView, let callback else { return }

        webView.evaluateJavaScript("document.body.innerHTML") { [weak self] html, _ in
            callback(html as? String)

            // Discard the web view so that the web content process is killed
            if webView == self?.webView {
                self?.callback = nil
                self?.webView = nil
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        guard webView == self.webView, let callback else { return }

        callback(nil)

        // Discard the web view so that the web content process is killed
        if webView == self.webView {
            self.callback = nil
            self.webView = nil
        }
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        guard webView == self.webView, let callback else { return }

        callback(nil)

        // Discard the web view so that the web content process is killed
        if webView == self.webView {
            self.callback = nil
            self.webView = nil
        }
    }
}

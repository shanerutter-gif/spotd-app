import UIKit
import WebKit

class MainViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
        webView.isOpaque = false
        view.addSubview(webView)

        if let url = URL(string: "https://spotd.biz") {
            webView.load(URLRequest(url: url))
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           let host = url.host,
           !host.contains("spotd.biz") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            if let host = url.host, !host.contains("spotd.biz") {
                UIApplication.shared.open(url)
            } else {
                webView.load(navigationAction.request)
            }
        }
        return nil
    }
}

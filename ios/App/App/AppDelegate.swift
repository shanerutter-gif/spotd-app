import UIKit
import WebKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WKNavigationDelegate {

    var window: UIWindow?
    var webView: WKWebView!
    var webViewBottomConstraint: NSLayoutConstraint!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        window = UIWindow(frame: UIScreen.main.bounds)

        let vc = UIViewController()
        vc.view.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
        webView.isOpaque = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        vc.view.addSubview(webView)

        let safeArea = vc.view.safeAreaLayoutGuide
        webViewBottomConstraint = webView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            webViewBottomConstraint,
            webView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor)
        ])

        if let url = URL(string: "https://spotd.biz") {
            webView.load(URLRequest(url: url))
        }

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        window!.rootViewController = vc
        window!.makeKeyAndVisible()

        return true
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        webViewBottomConstraint.constant = -keyboardFrame.height
        UIView.animate(withDuration: duration) {
            self.window?.rootViewController?.view.layoutIfNeeded()
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        webViewBottomConstraint.constant = 0
        UIView.animate(withDuration: duration) {
            self.window?.rootViewController?.view.layoutIfNeeded()
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let host = navigationAction.request.url?.host, !host.contains("spotd.biz") {
            UIApplication.shared.open(navigationAction.request.url!)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}

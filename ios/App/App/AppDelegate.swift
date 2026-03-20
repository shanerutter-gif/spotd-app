import UIKit
import WebKit
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WKNavigationDelegate, WKUIDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    var webView: WKWebView!
    var webViewBottomConstraint: NSLayoutConstraint!
    var pendingDeviceToken: String?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Set up push notification delegate
        UNUserNotificationCenter.current().delegate = self

        window = UIWindow(frame: UIScreen.main.bounds)

        let vc = UIViewController()
        vc.view.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Add JS bridge for push notifications
        let userController = config.userContentController
        userController.add(self, name: "spotdPush")

        // Inject native platform flag so the web app knows it's in the iOS wrapper
        let script = WKUserScript(
            source: "window.spotdNative = { platform: 'ios' };",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userController.addUserScript(script)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
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

    // MARK: - Push Notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Push] Device token: \(token)")
        pendingDeviceToken = token
        // Send token to web app via JS bridge
        webView?.evaluateJavaScript("window.spotdNative && (window.spotdNative.deviceToken = '\(token)'); if (typeof window.onNativePushToken === 'function') window.onNativePushToken('\(token)');")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] Failed to register: \(error.localizedDescription)")
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        if let url = userInfo["url"] as? String {
            await MainActor.run {
                webView?.evaluateJavaScript("window.location.href = '\(url)';")
            }
        }
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

// MARK: - JS Bridge for Push Notifications
extension AppDelegate: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "spotdPush" else { return }
        guard let body = message.body as? String else { return }

        if body == "requestPermission" {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                print("[Push] Permission granted: \(granted)")
                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
                DispatchQueue.main.async {
                    self.webView?.evaluateJavaScript("if (typeof window.onNativePushResult === 'function') window.onNativePushResult(\(granted));")
                }
            }
        } else if body == "getToken" {
            if let token = pendingDeviceToken {
                webView?.evaluateJavaScript("if (typeof window.onNativePushToken === 'function') window.onNativePushToken('\(token)');")
            }
        }
    }
}

import UIKit
import WebKit
import UserNotifications
import CoreSpotlight
import MobileCoreServices

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, WKNavigationDelegate, WKUIDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    var webView: WKWebView!
    var webViewBottomConstraint: NSLayoutConstraint!
    var pendingDeviceToken: String?
    var splashView: UIView?

    // MARK: - App Lifecycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        UNUserNotificationCenter.current().delegate = self

        window = UIWindow(frame: UIScreen.main.bounds)

        let vc = UIViewController()
        let bgColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
        vc.view.backgroundColor = bgColor

        // ── WKWebView setup ──
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let userController = config.userContentController
        userController.add(self, name: "spotdPush")
        userController.add(self, name: "spotdCache")
        userController.add(self, name: "spotdSpotlight")

        // Inject native platform flag + offline cache helper
        let script = WKUserScript(
            source: """
            window.spotdNative = { platform: 'ios' };
            window.spotdCache = {
                set: function(key, value) {
                    window.webkit.messageHandlers.spotdCache.postMessage(JSON.stringify({ action: 'set', key: key, value: value }));
                },
                get: function(key) {
                    return new Promise(function(resolve) {
                        window._cacheResolve = resolve;
                        window.webkit.messageHandlers.spotdCache.postMessage(JSON.stringify({ action: 'get', key: key }));
                    });
                }
            };
            window.spotdSpotlight = {
                indexVenues: function(venues) {
                    window.webkit.messageHandlers.spotdSpotlight.postMessage(JSON.stringify(venues));
                }
            };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userController.addUserScript(script)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.backgroundColor = bgColor
        webView.isOpaque = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.alpha = 0 // Hidden until loaded

        vc.view.addSubview(webView)

        let safeArea = vc.view.safeAreaLayoutGuide
        webViewBottomConstraint = webView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            webViewBottomConstraint,
            webView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor)
        ])

        // ── Native splash screen overlay ──
        setupSplashScreen(in: vc.view)

        if let url = URL(string: "https://spotd.biz") {
            webView.load(URLRequest(url: url))
        }

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        window!.rootViewController = vc
        window!.makeKeyAndVisible()

        return true
    }

    // MARK: - Native Splash Screen

    func setupSplashScreen(in parentView: UIView) {
        let splash = UIView(frame: parentView.bounds)
        splash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        splash.backgroundColor = UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)

        // App logo
        let logoLabel = UILabel()
        logoLabel.text = "Spotd"
        logoLabel.font = UIFont.systemFont(ofSize: 42, weight: .heavy)
        logoLabel.textColor = UIColor(red: 1.0, green: 0.42, blue: 0.29, alpha: 1.0) // #FF6B4A
        logoLabel.textAlignment = .center
        logoLabel.translatesAutoresizingMaskIntoConstraints = false
        splash.addSubview(logoLabel)

        // Subtitle
        let subLabel = UILabel()
        subLabel.text = "Happy Hours & Events"
        subLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        subLabel.textColor = UIColor(red: 0.42, green: 0.38, blue: 0.35, alpha: 0.6)
        subLabel.textAlignment = .center
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        splash.addSubview(subLabel)

        // Loading dots
        let dotsStack = UIStackView()
        dotsStack.axis = .horizontal
        dotsStack.spacing = 8
        dotsStack.alignment = .center
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        splash.addSubview(dotsStack)

        for i in 0..<3 {
            let dot = UIView()
            dot.backgroundColor = UIColor(red: 1.0, green: 0.42, blue: 0.29, alpha: 0.4)
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.tag = 100 + i
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8)
            ])
            dotsStack.addArrangedSubview(dot)
        }

        NSLayoutConstraint.activate([
            logoLabel.centerXAnchor.constraint(equalTo: splash.centerXAnchor),
            logoLabel.centerYAnchor.constraint(equalTo: splash.centerYAnchor, constant: -20),
            subLabel.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 6),
            subLabel.centerXAnchor.constraint(equalTo: splash.centerXAnchor),
            dotsStack.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 28),
            dotsStack.centerXAnchor.constraint(equalTo: splash.centerXAnchor)
        ])

        parentView.addSubview(splash)
        self.splashView = splash

        // Animate dots
        animateSplashDots(in: splash)
    }

    func animateSplashDots(in splash: UIView) {
        for i in 0..<3 {
            guard let dot = splash.viewWithTag(100 + i) else { continue }
            UIView.animate(
                withDuration: 0.4,
                delay: Double(i) * 0.15,
                options: [.repeat, .autoreverse, .curveEaseInOut]
            ) {
                dot.alpha = 1.0
                dot.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            }
        }
    }

    func dismissSplash() {
        guard let splash = splashView else { return }
        // Fade in webview, fade out splash
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut) {
            self.webView.alpha = 1.0
            splash.alpha = 0
        } completion: { _ in
            splash.removeFromSuperview()
            self.splashView = nil
        }
    }

    // MARK: - WKNavigationDelegate (transitions + splash dismiss)

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Dismiss splash once the page is loaded
        if splashView != nil {
            // Small delay so the web content renders before we show it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.dismissSplash()
            }
        }

        // Inject offline cached data if available
        injectCachedData()
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

    // Handle load failures — show cached content
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showOfflineFallback()
    }

    // MARK: - Offline Caching

    func injectCachedData() {
        // Tell the web app we have native caching available
        webView?.evaluateJavaScript("""
            if (window.spotdNative) { window.spotdNative.hasCache = true; }
        """)
    }

    func showOfflineFallback() {
        let cachedVenues = UserDefaults.standard.string(forKey: "spotd_venues") ?? "[]"
        let cachedCity = UserDefaults.standard.string(forKey: "spotd_city") ?? "San Diego"

        let offlineHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { margin:0; padding:0; box-sizing:border-box; }
                body { font-family: -apple-system, sans-serif; background: #F5F0E6; color: #2A1F14; padding: 20px; padding-top: env(safe-area-inset-top, 20px); }
                .header { text-align: center; padding: 20px 0; }
                .logo { font-size: 32px; font-weight: 900; color: #FF6B4A; }
                .offline-badge { display: inline-block; background: rgba(255,107,74,0.12); color: #FF6B4A; font-size: 12px; font-weight: 700; padding: 4px 12px; border-radius: 100px; margin-top: 8px; }
                .city { font-size: 16px; color: rgba(42,31,20,0.5); margin-top: 4px; }
                .card { background: #fff; border-radius: 16px; padding: 16px; margin-bottom: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
                .card-name { font-size: 16px; font-weight: 700; }
                .card-hood { font-size: 13px; color: rgba(42,31,20,0.5); margin-top: 2px; }
                .card-deals { margin-top: 8px; font-size: 13px; }
                .deal { padding: 2px 0; }
                .dot { display: inline-block; width: 6px; height: 6px; border-radius: 3px; background: #FF6B4A; margin-right: 6px; vertical-align: middle; }
                .retry { display: block; width: 100%; padding: 14px; background: #FF6B4A; color: white; border: none; border-radius: 12px; font-size: 16px; font-weight: 700; margin-top: 16px; cursor: pointer; font-family: -apple-system, sans-serif; }
            </style>
        </head>
        <body>
            <div class="header">
                <div class="logo">Spotd</div>
                <div class="offline-badge">Offline Mode</div>
                <div class="city">\(cachedCity)</div>
            </div>
            <div id="cards"></div>
            <button class="retry" onclick="window.location.href='https://spotd.biz'">Retry Connection</button>
            <script>
                try {
                    const venues = \(cachedVenues);
                    const grid = document.getElementById('cards');
                    venues.slice(0, 20).forEach(v => {
                        const deals = (v.deals || []).slice(0, 3).map(d => '<div class="deal"><span class="dot"></span>' + d + '</div>').join('');
                        grid.innerHTML += '<div class="card"><div class="card-name">' + v.name + '</div>' +
                            (v.neighborhood ? '<div class="card-hood">' + v.neighborhood + '</div>' : '') +
                            '<div class="card-deals">' + deals + '</div></div>';
                    });
                    if (!venues.length) {
                        grid.innerHTML = '<div style="text-align:center;padding:40px;color:rgba(42,31,20,0.4)">No cached data available.<br>Connect to the internet to browse spots.</div>';
                    }
                } catch(e) {}
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(offlineHTML, baseURL: nil)
    }

    // MARK: - Core Spotlight Indexing

    func indexVenuesInSpotlight(_ venuesJSON: String) {
        guard let data = venuesJSON.data(using: .utf8),
              let venues = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }

        var items: [CSSearchableItem] = []
        for venue in venues.prefix(50) {
            guard let id = venue["id"] as? String,
                  let name = venue["name"] as? String else { continue }

            let attrs = CSSearchableItemAttributeSet(contentType: .content)
            attrs.title = name
            attrs.contentDescription = [
                venue["neighborhood"] as? String,
                venue["cuisine"] as? String,
                (venue["deals"] as? [String])?.first
            ].compactMap { $0 }.joined(separator: " · ")
            attrs.namedLocation = venue["neighborhood"] as? String
            if let lat = venue["lat"] as? Double, let lng = venue["lng"] as? Double {
                attrs.latitude = NSNumber(value: lat)
                attrs.longitude = NSNumber(value: lng)
            }

            let item = CSSearchableItem(
                uniqueIdentifier: "venue-\(id)",
                domainIdentifier: "biz.spotd.venues",
                attributeSet: attrs
            )
            item.expirationDate = Date().addingTimeInterval(7 * 24 * 3600) // 7 day expiry
            items.append(item)
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                print("[Spotlight] Indexing error: \(error.localizedDescription)")
            } else {
                print("[Spotlight] Indexed \(items.count) venues")
            }
        }
    }

    // Handle Spotlight search result tap — open venue in app
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == CSSearchableItemActionType,
           let venueId = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
            let cleanId = venueId.replacingOccurrences(of: "venue-", with: "")
            webView?.evaluateJavaScript("openModal('\(cleanId)','venue');")
            return true
        }
        return false
    }

    // MARK: - Push Notifications

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Push] Device token: \(token)")
        pendingDeviceToken = token
        webView?.evaluateJavaScript("window.spotdNative && (window.spotdNative.deviceToken = '\(token)'); if (typeof window.onNativePushToken === 'function') window.onNativePushToken('\(token)');")
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] Failed to register: \(error.localizedDescription)")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        if let url = userInfo["url"] as? String {
            await MainActor.run {
                webView?.evaluateJavaScript("window.location.href = '\(url)';")
            }
        }
    }

    // MARK: - Keyboard Management

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
}

// MARK: - JS Bridge

extension AppDelegate: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

        // ── Push notifications ──
        if message.name == "spotdPush" {
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

        // ── Offline caching ──
        if message.name == "spotdCache" {
            guard let body = message.body as? String,
                  let data = body.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            let action = json["action"] as? String ?? ""
            let key = json["key"] as? String ?? ""

            if action == "set" {
                if let value = json["value"] {
                    if let stringValue = value as? String {
                        UserDefaults.standard.set(stringValue, forKey: "spotd_\(key)")
                    } else if let jsonData = try? JSONSerialization.data(withJSONObject: value),
                              let jsonString = String(data: jsonData, encoding: .utf8) {
                        UserDefaults.standard.set(jsonString, forKey: "spotd_\(key)")
                    }
                }
            } else if action == "get" {
                let value = UserDefaults.standard.string(forKey: "spotd_\(key)") ?? "null"
                webView?.evaluateJavaScript("if (window._cacheResolve) { window._cacheResolve(\(value)); window._cacheResolve = null; }")
            }
        }

        // ── Spotlight indexing ──
        if message.name == "spotdSpotlight" {
            guard let body = message.body as? String else { return }
            indexVenuesInSpotlight(body)
        }
    }
}

import SwiftUI
import WebKit
import NetDiskCore

@Observable @MainActor
final class WebLoginSession: NSObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    var loading = true
    var message = "在百度页面点击“去登录”，选择“短信登录”，输入手机号及验证码。"
    var failed = false
    private var lastAttempt: String?

    override init() {
        let configuration = WKWebViewConfiguration()
        // No browser session is written to disk or shared with Safari.
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        reload()
    }

    func reload() {
        failed = false
        lastAttempt = nil
        message = "在百度页面点击“去登录”，选择“短信登录”，输入手机号及验证码。"
        guard let url = URL(string: "https://pan.baidu.com/") else { return }
        loading = true
        webView.load(URLRequest(url: url))
    }

    func retrySession() { lastAttempt = nil; failed = false }

    func monitor(model: AppModel) async {
        defer { webView.stopLoading() }
        do {
            while !Task.isCancelled {
                let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
                try Task.checkCancellation()
                if !model.signingIn, let credentials = try WebLoginPolicy.credentials(from: cookies), credentials.cookie != lastAttempt {
                    lastAttempt = credentials.cookie
                    message = "正在验证网盘会话…"
                    failed = false
                    await model.login(cookie: credentials.cookie)
                    try Task.checkCancellation()
                    if model.username != nil { return }
                    failed = true
                    message = "会话验证未完成，请完成网页验证后重试连接。"
                }
                try await Task.sleep(for: .seconds(1))
            }
        } catch {
            if !Task.isCancelled { failed = true; message = "无法读取登录会话，请刷新页面重试。" }
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url, WebLoginPolicy.allowsNavigation(url) else { return .cancel }
        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { loading = true }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { loading = false }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { report(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { report(error) }
    private func report(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        loading = false
        failed = true
        message = "登录页面加载失败，请检查网络后刷新。"
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, WebLoginPolicy.allowsNavigation(url) {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

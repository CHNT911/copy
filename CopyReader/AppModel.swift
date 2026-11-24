import Foundation
import WebKit

enum Site {
    static let primary = "https://www.copy5000.com"
    static let mirror  = "https://www.copy4000.com"

    static let mobileUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
    static let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
}

final class AppModel: ObservableObject {
    @Published var urlString: String = Site.primary
    @Published var pageTitle: String = "拷貝閱讀器"
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var isReady = false
    @Published var isDesktop = false
    @Published var blockAds = true
    @Published var banner: String?

    weak var webView: WKWebView?

    private static var ruleList: WKContentRuleList?

    var homeURL: URL { URL(string: Site.primary)! }

    private static let adRuleJSON = """
    [{
      "trigger": {
        "url-filter": ".*(exoclick|trafficjunky|doubleclick|googlesyndication|popads|propellerads|adsterra|juicyads|adnium|realsrv|tsyndicate|hilltopads|adcash|clickadu|mgid)\\\\.",
        "resource-type": ["image","script","style-sheet","media","raw","subdocument","font"]
      },
      "action": { "type": "block" }
    }]
    """

    private static let cleanJS = """
    (function () {
      try { window.open = function () { return null; }; } catch (e) {}
      var CSS = 'ins.adsbygoogle,.adsbygoogle,#ad_iframe,iframe[src*="exoclick"],iframe[src*="trafficjunky"],iframe[src*="doubleclick"],iframe[src*="popads"]{display:none!important}';
      var timer = null;
      function nuke() {
        var s = document.getElementById('__cr_style');
        if (!s) {
          s = document.createElement('style');
          s.id = '__cr_style';
          s.textContent = CSS;
          (document.head || document.documentElement).appendChild(s);
        } else if (s.textContent !== CSS) {
          s.textContent = CSS;
        }
      }
      function schedule() { if (timer) { clearTimeout(timer); } timer = setTimeout(nuke, 250); }
      nuke();
      try { new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true }); } catch (e) {}
      document.addEventListener('click', function (e) {
        var a = e.target && e.target.closest ? e.target.closest('a') : null;
        if (!a) { return; }
        var h = a.getAttribute('href') || '';
        if (h.indexOf('javascript:') === 0 && /open\\(/.test(h)) { e.preventDefault(); }
      }, true);
    })();
    """

    func prepare() {
        guard !isReady else { return }
        if AppModel.ruleList != nil {
            isReady = true
            return
        }
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "copyreader-ads",
            encodedContentRuleList: AppModel.adRuleJSON
        ) { list, _ in
            AppModel.ruleList = list
            DispatchQueue.main.async { self.isReady = true }
        }
    }

    func makeConfiguration() -> WKWebViewConfiguration {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = .all
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        let controller = cfg.userContentController
        if blockAds {
            let script = WKUserScript(source: AppModel.cleanJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
            controller.addUserScript(script)
            if let rules = AppModel.ruleList { controller.add(rules) }
        }
        return cfg
    }

    func userAgent() -> String { isDesktop ? Site.desktopUA : Site.mobileUA }

    func load(_ url: URL, force: Bool = false) {
        guard let webView else { return }
        if force {
            webView.load(URLRequest(url: url))
        } else if webView.url == nil {
            webView.load(URLRequest(url: url))
        }
    }

    func goHome() {
        webView?.load(URLRequest(url: homeURL))
    }

    func toggleMirror() {
        guard let current = webView?.url?.absoluteString else {
            webView?.load(URLRequest(url: URL(string: Site.mirror)!)); return
        }
        let target: String
        if current.contains("copy5000.com") {
            target = current.replacingOccurrences(of: "copy5000.com", with: "copy4000.com")
        } else if current.contains("copy4000.com") {
            target = current.replacingOccurrences(of: "copy4000.com", with: "copy5000.com")
        } else {
            target = Site.mirror
        }
        if let url = URL(string: target) { webView?.load(URLRequest(url: url)) }
    }

    func reload() {
        if isDesktop {
            let ua = Site.desktopUA
            webView?.customUserAgent = ua
            webView?.load(URLRequest(url: webView?.url ?? homeURL))
        } else {
            webView?.reload()
        }
    }

    func setDesktop(_ on: Bool) {
        isDesktop = on
        webView?.customUserAgent = on ? Site.desktopUA : Site.mobileUA
        if let u = webView?.url { webView?.load(URLRequest(url: u)) }
    }

    func extractImageURLs(completion: @escaping ([URL]) -> Void) {
        guard let webView else { completion([]); return }
        let js = """
        (function () {
          var seen = {}, out = [], imgs = document.images;
          for (var i = 0; i < imgs.length; i++) {
            var im = imgs[i];
            if (im.naturalWidth < 200 && im.naturalHeight < 200) { continue; }
            var u = im.currentSrc || im.src || '';
            if (!u || u.indexOf('data:') === 0 || seen[u]) { continue; }
            seen[u] = 1; out.push(u);
          }
          return JSON.stringify(out);
        })()
        """
        webView.evaluateJavaScript(js) { result, _ in
            var urls: [URL] = []
            if let str = result as? String,
               let data = str.data(using: .utf8),
               let list = try? JSONSerialization.jsonObject(with: data) as? [String] {
                urls = list.compactMap { URL(string: $0) }
            }
            DispatchQueue.main.async { completion(urls) }
        }
    }

    func showBanner(_ text: String) {
        banner = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if self.banner == text { self.banner = nil }
        }
    }
}

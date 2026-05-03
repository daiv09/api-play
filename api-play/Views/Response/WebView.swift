import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let htmlString: String
    let baseURL: URL?
    var data: Data? = nil
    var mimeType: String? = nil
    
    // Add a way to identify the specific WKWebView instance
    let requestId: UUID

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // Security settings
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        webView.navigationDelegate = context.coordinator
        
        // Match the app's theme
        webView.setValue(false, forKey: "drawsBackground")
        
        // Store a reference to the webview in the coordinator for snapshotting
        context.coordinator.webView = webView
        
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Only reload if content actually changed to prevent flickering during UI updates
        if let data = data, let mimeType = mimeType {
            let lowerMime = mimeType.lowercased()
            
            if lowerMime.contains("image/") {
                let base64 = data.base64EncodedString()
                let html = wrapImageInHTML(base64: base64, mimeType: mimeType)
                DispatchQueue.main.async { nsView.loadHTMLString(html, baseURL: baseURL) }
                return
            } else if lowerMime.contains("pdf") || lowerMime.contains("video/") || lowerMime.contains("audio/") {
                DispatchQueue.main.async {
                    nsView.load(data, mimeType: mimeType, characterEncodingName: "utf-8", baseURL: baseURL ?? URL(string: "about:blank")!)
                }
                return
            }
        }

        let content = htmlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDirectVideoLink = content.lowercased().hasPrefix("http") &&
                               (content.lowercased().contains(".mp4") ||
                                content.lowercased().contains(".mov") ||
                                content.lowercased().contains(".m4v"))

        let finalHTML: String
        if isDirectVideoLink {
            finalHTML = wrapVideoInPlayer(content)
        } else {
            finalHTML = wrapInSystemTheme(content.isEmpty ? "<html><body>No Content</body></html>" : content)
        }
        
        DispatchQueue.main.async {
            nsView.loadHTMLString(finalHTML, baseURL: baseURL)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        weak var webView: WKWebView?
        
        init(_ parent: WebView) {
            self.parent = parent
        }

        // --- VISUAL EXPLAIN SNAPSHOT LOGIC ---
        func takeSnapshot(completion: @escaping (NSImage?) -> Void) {
            guard let webView = webView else {
                completion(nil)
                return
            }
            
            let config = WKSnapshotConfiguration()
            // Capture the full visible area
            config.rect = webView.bounds
            
            webView.takeSnapshot(with: config) { image, error in
                if let error = error {
                    print("❌ Snapshot Error: \(error.localizedDescription)")
                    completion(nil)
                } else {
                    completion(image)
                }
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleWebKitError(error, context: "Provisional")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleWebKitError(error, context: "Navigation")
        }
        
        private func handleWebKitError(_ error: Error, context: String) {
            let nsError = error as NSError
            if nsError.domain == "WebKitErrorDomain" && nsError.code == 204 { return }
            if nsError.code == NSURLErrorCancelled { return }
            print("❌ WebView \(context) Error (\(nsError.code)): \(error.localizedDescription)")
        }
    }

    // MARK: - HTML Templates

    private func wrapImageInHTML(base64: String, mimeType: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                :root { color-scheme: light dark; }
                body { margin: 0; background-color: transparent; display: flex; align-items: center; justify-content: center; height: 100vh; overflow: hidden; }
                img { max-width: 100%; max-height: 100%; object-fit: contain; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.15); }
            </style>
        </head>
        <body><img src="data:\(mimeType);base64,\(base64)" /></body>
        </html>
        """
    }

    private func wrapVideoInPlayer(_ url: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body { margin: 0; background-color: #000; display: flex; align-items: center; justify-content: center; height: 100vh; overflow: hidden; }
                video { width: 100%; height: 100%; border-radius: 4px; }
            </style>
        </head>
        <body>
            <video controls autoplay playsinline>
                <source src="\(url)" type="video/mp4">
            </video>
        </body>
        </html>
        """
    }

    private func wrapInSystemTheme(_ content: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                :root { color-scheme: light dark; }
                body { margin: 0; padding: 20px; font-family: -apple-system, sans-serif; background-color: Canvas; color: CanvasText; line-height: 1.6; }
                video, img, iframe { max-width: 100%; height: auto; border-radius: 12px; margin-top: 10px; }
                pre { white-space: pre-wrap; background: rgba(120,120,120,0.1); padding: 12px; border-radius: 8px; font-family: "SF Mono", monospace; font-size: 13px; }
            </style>
        </head>
        <body>\(content)</body>
        </html>
        """
    }
}

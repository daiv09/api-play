import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let htmlString: String
    let baseURL: URL?
    var data: Data? = nil
    var mimeType: String? = nil

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Essential for media playback in a macOS app
        config.allowsAirPlayForMediaPlayback = true
        
        // Allows video to start immediately without requiring a user click
        config.mediaTypesRequiringUserActionForPlayback = []
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: config)
        
        // Modern User Agent to ensure video players load correctly
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        webView.navigationDelegate = context.coordinator
        
        // Set transparent background to match the app's SwiftUI theme
        webView.setValue(false, forKey: "drawsBackground")
        
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if let data = data, let mimeType = mimeType {
            let lowerMime = mimeType.lowercased()
            if lowerMime.contains("image/") {
                // Base64 encode the image to display it centered with a nice dark/light mode background
                let base64 = data.base64EncodedString()
                let html = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <style>
                        :root { color-scheme: light dark; }
                        body { 
                            margin: 0; 
                            background-color: transparent; 
                            display: flex; 
                            align-items: center; 
                            justify-content: center; 
                            height: 100vh; 
                            overflow: hidden;
                        }
                        img { 
                            max-width: 100%; 
                            max-height: 100%; 
                            object-fit: contain;
                            border-radius: 8px;
                            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
                        }
                    </style>
                </head>
                <body>
                    <img src="data:\(mimeType);base64,\(base64)" />
                </body>
                </html>
                """
                DispatchQueue.main.async {
                    nsView.loadHTMLString(html, baseURL: baseURL)
                }
                return
            } else if lowerMime.contains("pdf") || lowerMime.contains("video/") || lowerMime.contains("audio/") {
                DispatchQueue.main.async {
                    nsView.load(data, mimeType: mimeType, characterEncodingName: "utf-8", baseURL: baseURL ?? URL(string: "about:blank")!)
                }
                return
            }
        }

        let content = htmlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Logic to detect if we are dealing with a direct video link or raw HTML
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
            // baseURL allows for relative path resolution for local resources
            nsView.loadHTMLString(finalHTML, baseURL: baseURL)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView Navigation Error: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView Load Error: \(error.localizedDescription)")
        }
    }

    // MARK: - HTML Templates

    /// Wraps a direct .mp4/.mov URL into a full-screen, centered HTML5 video player
    private func wrapVideoInPlayer(_ url: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body { 
                    margin: 0; 
                    background-color: #000; 
                    display: flex; 
                    align-items: center; 
                    justify-content: center; 
                    height: 100vh; 
                    overflow: hidden;
                }
                video { 
                    max-width: 100%; 
                    max-height: 100%; 
                    border-radius: 4px; 
                    box-shadow: 0 0 20px rgba(0,0,0,0.5);
                }
            </style>
        </head>
        <body>
            <video controls autoplay playsinline>
                <source src="\(url)" type="video/mp4">
                Your browser does not support the video tag.
            </video>
        </body>
        </html>
        """
    }

    /// Wraps general HTML content in a theme that respects Dark/Light mode
    private func wrapInSystemTheme(_ content: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                :root { color-scheme: light dark; }
                body { 
                    margin: 0; 
                    padding: 20px;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; 
                    background-color: Canvas; 
                    color: CanvasText; 
                    line-height: 1.6;
                }
                video, img, iframe { 
                    max-width: 100%; 
                    height: auto; 
                    border-radius: 12px;
                    margin-top: 10px;
                }
                pre { 
                    white-space: pre-wrap; 
                    word-wrap: break-word; 
                    background: rgba(120,120,120,0.1); 
                    padding: 12px; 
                    border-radius: 8px; 
                    font-family: "SF Mono", "Menlo", monospace;
                    font-size: 13px;
                }
                a { color: #007AFF; }
            </style>
        </head>
        <body>\(content)</body>
        </html>
        """
    }
}

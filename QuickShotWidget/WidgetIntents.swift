import AppIntents
import WidgetKit
import SwiftData
import AppKit

// Make sure NetworkManager, SharedContainer, and APIRequest are added to the Widget target

// MARK: - AppIntent: Send / Execute Request

struct SendQuickShotIntent: AppIntent {
    static var title: LocalizedStringResource = "Send QuickShot"
    static var description = IntentDescription(
        "Executes a starred API request, persists the response, and caches any image thumbnail.")

    @Parameter(title: "Request ID") var requestID: String

    init() {}
    init(requestID: String) { self.requestID = requestID }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = ModelContext(SharedContainer.shared)
        guard let uuid = UUID(uuidString: requestID) else { return .result() }

        let descriptor = FetchDescriptor<APIRequest>(predicate: #Predicate { $0.id == uuid })
        guard let apiRequest = try? context.fetch(descriptor).first else { return .result() }

        let manager = NetworkManager()
        if let response = await manager.execute(apiRequest, env: nil) {
            apiRequest.lastResponse = response
            apiRequest.updatedAt = Date()
            try? context.save()

            // Download & cache thumbnail if the URL points to an image
            await cacheImageIfNeeded(urlString: apiRequest.urlString, requestID: requestID)
        }

        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    /// Downloads image data and writes a 300-pt thumbnail to the App Group container.
    /// The widget reads this file synchronously at render time — no async needed.
    private func cacheImageIfNeeded(urlString: String, requestID: String) async {
        let lower = urlString.lowercased()
        guard lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")
                || lower.hasSuffix(".gif") || lower.hasSuffix(".webp"),
              let remoteURL = URL(string: urlString),
              let cacheURL  = cachedImageURL(for: requestID) else { return }

        guard let (data, _) = try? await URLSession.shared.data(from: remoteURL),
              let image = NSImage(data: data),
              let thumb  = image.thumbnail(maxDimension: 300),
              let png    = thumb.pngData else { return }

        try? png.write(to: cacheURL)
    }
}

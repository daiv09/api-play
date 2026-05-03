// QuickShotWidget.swift
// QuickShot — Premium macOS Widget  v2
// Segmented tab control (Code · Response · Preview), image caching, SwiftData integration.
//
// ⚠️  SETUP REQUIRED:
//   1. Add your App Group ID to `AppGroupID.suite` below.
//   2. Enable the same App Group in both the main target and the widget extension entitlements.
//   3. Ensure SharedContainer, APIRequest, APIResponse, NetworkManager are in the widget target.

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents
import AppKit

// MARK: - App Group

private enum AppGroupID {
    /// Replace with your actual App Group identifier from Xcode → Signing & Capabilities.
    static let suite = "group.com.apiplay.shared"
}

// MARK: - Tab State Helpers

private enum WidgetTab: Int, CaseIterable {
    case code     = 0
    case response = 1
    case preview  = 2

    var label: String {
        switch self {
        case .code:     return "Code"
        case .response: return "Response"
        case .preview:  return "Preview"
        }
    }

    var icon: String {
        switch self {
        case .code:     return "curlybraces"
        case .response: return "antenna.radiowaves.left.and.right"
        case .preview:  return "eye"
        }
    }
}

private func activeTab(for requestID: String) -> WidgetTab {
    let raw = UserDefaults(suiteName: AppGroupID.suite)?
        .integer(forKey: "widget_tab_\(requestID)") ?? 0
    return WidgetTab(rawValue: raw) ?? .code
}

// MARK: - Cached Image Helpers

/// Returns the file URL where a thumbnail is cached for a given request ID.
func cachedImageURL(for requestID: String) -> URL? {
    guard let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: AppGroupID.suite) else { return nil }
    return container.appendingPathComponent("thumb_\(requestID).png")
}

/// Loads a cached NSImage from the App Group container.
private func loadCachedImage(for requestID: String) -> NSImage? {
    guard let url = cachedImageURL(for: requestID),
          let data = try? Data(contentsOf: url) else { return nil }
    return NSImage(data: data)
}

// MARK: - Timeline Provider

@MainActor
struct QuickShotProvider: TimelineProvider {
    typealias Entry = QuickShotEntry

    func placeholder(in context: Context) -> QuickShotEntry {
        QuickShotEntry(date: .now, requests: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickShotEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickShotEntry>) -> Void) {
        let entry = fetchEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func fetchEntry() -> QuickShotEntry {
        let context = ModelContext(SharedContainer.shared)
        let descriptor = FetchDescriptor<APIRequest>(
            predicate: #Predicate { $0.isFavorite },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let requests = (try? context.fetch(descriptor)) ?? []
        return QuickShotEntry(date: .now, requests: requests)
    }
}

struct QuickShotEntry: TimelineEntry {
    let date: Date
    let requests: [APIRequest]
}

// MARK: - Main Entry View
struct QuickShotWidgetEntryView: View {
    let entry: QuickShotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ALWAYS VISIBLE HEADER
            HeaderRow()
            
            if entry.requests.isEmpty {
                EmptyStateView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // We only show ONE card in Small to ensure the header fits
                // We show TWO cards in Medium
                let limit = family == .systemSmall ? 1 : 2
                
                VStack(spacing: 8) {
                    ForEach(entry.requests.prefix(limit)) { request in
                        ModernRequestCard(request: request)
                    }
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(12) // Slightly reduced padding for more space
        .containerBackground(.ultraThinMaterial, for: .widget)
    }
}

private struct HeaderRow: View {
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Logo scaled to fit better within the 24pt frame
            Image("api-play")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            Text("api-play") // Changed from "api-play" for a cleaner look
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            Link(destination: URL(string: "apiplay://new")!) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .black))
                    .padding(5)
                    .background(.primary.opacity(0.08), in: Circle())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 10)    // Gives the header room to breathe from the top edge
        .padding(.bottom, 4)  // Space between header and the request cards
        .frame(height: 38)    // Increased height to accommodate padding + content
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var body: some View {
        Link(destination: URL(string: "apiplay://new")!) {
            VStack(spacing: 10) {
                Image(systemName: "star.slash")
                    .font(.system(size: 26, weight: .thin))
                    .foregroundStyle(.tertiary)
                    .symbolEffect(.pulse, options: .repeating)

                Text("No Starred Requests")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Tap to create one")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Request Card (Card-within-a-Card)

struct ModernRequestCard: View {
    let request: APIRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Top Row ────────────────────────────────────────────────
            HStack(alignment: .center, spacing: 8) {
                HTTPMethodBadge(method: request.httpMethod.rawValue)

                VStack(alignment: .leading, spacing: 1) {
                    Text(request.name.isEmpty ? "Untitled" : request.name)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(request.urlString)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)

                // Paperplane / Send Button
                Button(intent: SendQuickShotIntent(requestID: request.id.uuidString)) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.22, green: 0.55, blue: 1),
                                         Color(red: 0.10, green: 0.38, blue: 0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .shadow(color: .blue.opacity(0.35), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, request.lastResponse == nil ? 10 : 6)

            // ── Expanded Result Panel (only when response exists) ──────
            if let response = request.lastResponse {
                ResultPanel(
                    response: response,
                    urlString: request.urlString,
                    requestID: request.id.uuidString
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .transition(.asymmetric(
                    insertion: .push(from: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        )
        .animation(.spring(duration: 0.4), value: request.lastResponse != nil)
    }
}

private struct ResultPanel: View {
    @Environment(\.widgetFamily) var family
    
    let response: APIResponse
    let urlString: String
    let requestID: String

    var body: some View {
        let currentTab = activeTab(for: requestID)

        VStack(alignment: .leading, spacing: 8) {

            // ── Separator ─────────────────────────────────────────────
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 0.5)

            // ── Segmented Tab Bar ──────────────────────────────────────
            HStack(spacing: 4) {
                // Filter logic
                let visibleTabs = family == .systemSmall
                    ? WidgetTab.allCases.filter { $0 != .response }
                    : WidgetTab.allCases

                ForEach(visibleTabs, id: \.rawValue) { tab in
                    Button(intent: SelectTabIntent(requestID: requestID, tabIndex: tab.rawValue)) {
                        HStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                // Make icon slightly larger in Small widget since text is gone
                                .font(.system(size: family == .systemSmall ? 9 : 7.5, weight: .semibold))
                            
                            // ONLY show text if NOT small widget
                            if family != .systemSmall {
                                Text(tab.label)
                                    .font(.system(size: 8, design: .rounded).weight(.semibold))
                            }
                        }
                        .padding(.horizontal, family == .systemSmall ? 10 : 7)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(currentTab == tab ? Color.primary.opacity(0.12) : Color.clear)
                        )
                        .foregroundStyle(currentTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                // Copy Button
                Button(intent: CopyResponseIntent(text: response.body)) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(4)
                        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
            }

            // ── Tab Content ────────────────────────────────────────────
            Group {
                switch currentTab {
                case .code:
                    CodeTabView(responseText: response.body)
                case .response:
                    ResponseTabView(response: response)
                case .preview:
                    PreviewTabView(urlString: urlString, requestID: requestID)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: currentTab)
        }
    }
}
private struct CodeTabView: View {
    let responseText: String
    @Environment(\.widgetFamily) var family

    private var previewText: String {
        let trimmed = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        // Expand character limit significantly for Medium/Large
        let limit = family == .systemSmall ? 100 : 1500
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit)) + "..."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(previewText.isEmpty ? "// — empty body —" : previewText)
                .font(.system(size: family == .systemSmall ? 7.5 : 9, design: .monospaced))
                .foregroundStyle(.primary.opacity(family == .systemSmall ? 0.6 : 0.9))
                // Only blur in small to hint "there is more here"
                .blur(radius: family == .systemSmall ? 0.5 : 0)
                .lineLimit(family == .systemLarge ? 18 : (family == .systemMedium ? 8 : 4))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if family != .systemLarge {
                Text(family == .systemSmall ? "Tap ❏ to copy" : "Tap ❏ to copy full response")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.blue.opacity(0.8))
                    .padding(.top, 2)
            }
        }
        .padding(family == .systemSmall ? 7 : 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        // In Large widgets, we want this to take up available space
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Response Tab

private struct ResponseTabView: View {
    let response: APIResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {

            // Status + timing
            HStack(spacing: 6) {
                StatusBadge(code: response.statusCode)
                MetaChip(label: String(format: "%.0f ms", response.elapsedSeconds * 1_000),
                         icon: "clock")
                MetaChip(label: byteLabel(response.body.utf8.count), icon: "arrow.down.circle")
            }

            // Top headers
            let headers = response.headers
            if !headers.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(headers.prefix(4)), id: \.key) { kv in
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(kv.key)
                                .font(.system(size: 7, design: .monospaced).weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(kv.value)
                                .font(.system(size: 7, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
                .padding(7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func byteLabel(_ bytes: Int) -> String {
        if bytes < 1024                { return "\(bytes) B" }
        else if bytes < 1_048_576     { return String(format: "%.1f KB", Double(bytes) / 1_024) }
        else                           { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
    }
}

private struct MetaChip: View {
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 7, weight: .medium))
            Text(label).font(.system(size: 7.5, design: .monospaced).weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 5).padding(.vertical, 2.5)
        .background(.primary.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

// MARK: - Preview Tab

/// Routes to the correct preview sub-view based on URL content type.
/// ‼️  WidgetKit constraints:
///   • WKWebView / HTML rendering → impossible (use a rich deep-link card instead)
///   • AsyncImage → unavailable  (images must be pre-cached by SendQuickShotIntent)
///   • Video playback → impossible (use a deep-link card to open in the main app)
private struct PreviewTabView: View {
    let urlString: String
    let requestID: String

    private var isImageURL: Bool {
        let l = urlString.lowercased()
        return l.hasSuffix(".png") || l.hasSuffix(".jpg") || l.hasSuffix(".jpeg")
            || l.hasSuffix(".gif") || l.hasSuffix(".webp")
    }

    private var isVideoURL: Bool {
        let l = urlString.lowercased()
        return l.hasSuffix(".mp4") || l.hasSuffix(".mov")
            || l.hasSuffix(".m3u8") || l.hasSuffix(".avi")
    }

    var body: some View {
        if isImageURL {
            ImagePreviewView(requestID: requestID, urlString: urlString)
        } else if isVideoURL {
            VideoPreviewView(urlString: urlString)
        } else {
            WebPreviewView(urlString: urlString)
        }
    }
}

// ── Image Preview ────────────────────────────────────────────────────────────

private struct ImagePreviewView: View {
    let requestID: String
    let urlString: String

    private var cached: NSImage? { loadCachedImage(for: requestID) }

    var body: some View {
        if let img = cached {
            Link(destination: URL(string: urlString) ?? URL(string: "apiplay://")!) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(5)
                    }
            }
        } else {
            // Not yet cached — prompt user to fire the request first
            PreviewCallToAction(
                icon: "photo.badge.arrow.down",
                title: "Image Not Cached",
                subtitle: "Tap ✈︎ to load & cache the preview",
                color: .purple,
                urlString: urlString
            )
        }
    }
}

// ── Video Preview ────────────────────────────────────────────────────────────

private struct VideoPreviewView: View {
    let urlString: String

    private var deepLink: String {
        "apiplay://open?url=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    }

    var body: some View {
        PreviewCallToAction(
            icon: "play.rectangle.fill",
            title: "Video File",
            subtitle: "Opens in QuickPlay browser",
            color: .orange,
            urlString: deepLink
        )
    }
}

// ── Web / HTML Preview ───────────────────────────────────────────────────────

private struct WebPreviewView: View {
    let urlString: String

    private var host: String { URL(string: urlString)?.host ?? urlString }

    private var deepLink: String {
        "apiplay://open?url=\(urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    }

    var body: some View {
        Link(destination: URL(string: deepLink) ?? URL(string: "apiplay://")!) {
            HStack(spacing: 8) {
                // Favicon placeholder square
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "safari")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.blue)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(host)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(urlString)
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.blue)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.blue.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.blue.opacity(0.14), lineWidth: 0.5)
                    )
            )
        }
    }
}

// ── Shared CTA Card ──────────────────────────────────────────────────────────

private struct PreviewCallToAction: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let urlString: String

    var body: some View {
        Link(destination: URL(string: urlString) ?? URL(string: "apiplay://")!) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .thin))
                    .foregroundStyle(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 7.5, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(color.opacity(0.14), lineWidth: 0.5)
                    )
            )
        }
    }
}

// MARK: - Shared UI Components

struct HTTPMethodBadge: View {
    let method: String

    private var colors: (fg: Color, bg: Color) {
        switch method.uppercased() {
        case "GET":    return (.green,  .green.opacity(0.14))
        case "POST":   return (.blue,   .blue.opacity(0.14))
        case "PUT":    return (.orange, .orange.opacity(0.14))
        case "PATCH":  return (Color(red: 0.6, green: 0.3, blue: 1),
                                Color(red: 0.6, green: 0.3, blue: 1).opacity(0.14))
        case "DELETE": return (.red,    .red.opacity(0.14))
        case "HEAD":   return (.teal,   .teal.opacity(0.14))
        default:       return (.secondary, Color.primary.opacity(0.10))
        }
    }

    var body: some View {
        Text(method.uppercased())
            .font(.system(size: 7, design: .monospaced).weight(.black))
            .tracking(0.4)
            .foregroundStyle(colors.fg)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(colors.bg,
                        in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct StatusBadge: View {
    let code: Int

    private var color: Color {
        switch code {
        case 200..<300: return .green
        case 300..<400: return .yellow
        default:        return .red
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(code)")
                .font(.system(size: 8, design: .monospaced).weight(.black))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 5).padding(.vertical, 2)
        .background(color.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

// MARK: - Widget Configuration

struct QuickShotWidget: Widget {
    let kind = "QuickShotWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickShotProvider()) { entry in
            QuickShotWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("QuickShot")
        .description("Fire starred API requests and preview responses at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - AppIntent: Select Tab

struct SelectTabIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Widget Tab"
    static var description = IntentDescription("Switches the active tab on a QuickShot card.")

    @Parameter(title: "Request ID") var requestID: String
    @Parameter(title: "Tab Index")  var tabIndex: Int

    init() {}
    init(requestID: String, tabIndex: Int) {
        self.requestID = requestID
        self.tabIndex  = tabIndex
    }

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: AppGroupID.suite)?
            .set(tabIndex, forKey: "widget_tab_\(requestID)")
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}


// MARK: - AppIntent: Copy Response

// MARK: - Copy Intent (Fixed for Scope)
struct CopyResponseIntent: AppIntent {
    static var title: LocalizedStringResource = "Copy Response"
    
    @Parameter(title: "Text") var text: String

    init() {}
    init(text: String) { self.text = text }

    func perform() async throws -> some IntentResult {
        #if os(macOS)
        await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
        #endif
        return .result()
    }
}

// MARK: - NSImage Helpers

extension NSImage {
    /// Scales the image down so its longest side fits within `maxDimension`.
    func thumbnail(maxDimension: CGFloat) -> NSImage? {
        let s = size
        guard s.width > 0, s.height > 0 else { return nil }
        let scale = min(maxDimension / s.width, maxDimension / s.height, 1.0)
        let newSize = NSSize(width: s.width * scale, height: s.height * scale)

        let thumb = NSImage(size: newSize)
        thumb.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: newSize),
             from: NSRect(origin: .zero, size: s),
             operation: .copy, fraction: 1.0)
        thumb.unlockFocus()
        return thumb
    }

    /// Converts the receiver to a PNG Data blob.
    var pngData: Data? {
        guard let tiff   = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

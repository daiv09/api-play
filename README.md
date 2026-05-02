# api-play

A native macOS API client built with SwiftUI, designed for speed, clarity, and deep platform integration. `api-play` supports REST and GraphQL requests, on-device AI response analysis via Apple Intelligence, WebSocket connections, and a clean multi-panel workspace — all without leaving the Apple ecosystem.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Project Structure](#project-structure)
- [Architecture Overview](#architecture-overview)
- [Core Modules](#core-modules)
- [Feature Modules](#feature-modules)
- [Views](#views)
- [Data Models](#data-models)
- [Getting Started](#getting-started)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Configuration](#configuration)

---

## Features

### Request Editing
- **REST & GraphQL** support via a segmented control switcher
- Full HTTP method support: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`
- Query parameter, header, request body, and authentication editors
- Authentication types: None, Bearer Token, Basic Auth, API Key
- Drag-and-drop file import directly into the request body editor
- One-click **Save** and **Send** (`⌘↵`)

### Environments
- Create and switch between named environments in the sidebar
- `{{variable}}` placeholder interpolation across URLs, headers, params, and body
- Sensitive environment variables stored securely in the macOS **Keychain**
- In-app environment editor sheet accessible from the sidebar

### Response Inspection
- Four response view modes: **JSON Tree**, **Raw**, **Headers**, **Preview**
- Prettified, selectable, monospaced JSON display
- Response status badge, elapsed time, and byte count in the toolbar
- HTML/video response preview powered by **WKWebView** with system Dark/Light Mode support
- Automatic video player wrapping for `.mp4`, `.mov`, `.m4v` links
- Copy response to clipboard from the toolbar

### Apple Intelligence Integration
- On-device AI response analysis via the **FoundationModels** framework
- **AICoordinator** truncates large payloads and sends a structured prompt to the local language model
- **Computer Vision (Vision framework)** OCR scans the Preview panel screenshot and feeds extracted text back through the AI for visual context interpretation
- AI inspector panel slides in from the trailing edge of the response view

### Code Generation
- Generates ready-to-use code snippets for **cURL**, **Swift**, **Python**, and **JavaScript**
- GraphQL requests automatically switch to POST with a JSON body
- **GraphQL Introspection** — fetches and displays the live schema directly from the endpoint
- One-click copy button with a checkmark confirmation animation

### Workspace & Navigation
- **NavigationSplitView** with a resizable sidebar (250–350 pt) and a detail area
- Sidebar organizes requests into **nested collection folders** with drag-and-drop reordering
- **Command Palette** (`⌘K`) — Spotlight-style search and quick request creation
- **Multi-window support** — open any request detail in a detached secondary window
- Request context menu: rename, duplicate, pin/unpin, delete
- Inline rename via double-click row editing
- Sidebar search with live filtering

### Persistence & History
- All requests, folders, and environments are persisted via **SwiftData**
- `APIHistory` model records URL, method, request/response body, status code, duration, and timestamp
- `PersistenceController` singleton handles schema migration and a `clearAllData()` reset path

### Onboarding
- Three-step animated onboarding sheet on first launch (`@AppStorage`-gated)
- Skippable with a "Get Started" CTA on the final step

### WebSocket (Beta)
- `WebSocketService` supports connect, disconnect, send text, and a recursive receive listener
- Messages are stored as an `[WebSocketMessage]` array with `isOutgoing` flag for UI differentiation

### Diff Service
- `DiffService` computes line-by-line diffs using Swift's native `CollectionDifference` API
- Supports JSON prettify-then-diff for semantically meaningful comparisons
- Returns typed `DiffLine` objects (`added`, `removed`, `equal`) ready for highlighted rendering

---

## Requirements

| Requirement | Value |
|---|---|
| Platform | macOS |
| Deployment Target | macOS 26.4 |
| Swift Version | 5.0 |
| Xcode | Xcode 26+ (required for FoundationModels) |
| Bundle ID | `com.daiwiik.api-play` |
| Frameworks | SwiftUI, SwiftData, WebKit, Vision, FoundationModels, Combine, Security |

> **Note:** The `FoundationModels` framework and Apple Intelligence features require a device with the Apple Neural Engine and a compatible macOS version. The app gracefully handles unavailability with a user-facing message.

---

## Project Structure

```
api-play/
├── api_play.swift                      # @main App entry point, SwiftData container, scene setup
├── EnvironmentEditor.swift             # Sheet view for editing environment variables
│
├── Core/
│   ├── Models/
│   │   ├── APIEnvironment.swift        # SwiftData models: APIEnvironment, EnvVar
│   │   ├── APIModels.swift             # SwiftData model: APIHistory
│   │   ├── JSONNode.swift              # Recursive JSONNode enum + JSONParser
│   │   ├── Models.swift                # HTTPMethod, AuthType, RequestType, KVPair,
│   │   │                               #   APIResponse, RequestFolder, APIRequest
│   │   └── SidebarViewModel.swift      # @Observable view model for sidebar CRUD
│   │
│   ├── Networking/
│   │   └── NetworkManager.swift        # @MainActor ObservableObject; executes requests,
│   │                                   #   handles auth, URL building, env interpolation
│   └── Security/
│       └── KeychainHelper.swift        # Static Keychain read/write/delete wrapper
│
├── Features/
│   ├── AI/
│   │   ├── AICoordinator.swift         # @Observable; FoundationModels + Vision analysis
│   │   └── AIInspectorView.swift       # Sliding AI results panel (Markdown rendered)
│   │
│   ├── Editor/
│   │   ├── EditorView.swift            # URL bar, method picker, Send button, tab router
│   │   │                               #   KVPairEditor, BodyEditorView, AuthEditorView
│   │   ├── GraphQLEditorView.swift     # Query + Variables tab editor with Prettify action
│   │   └── CommandPallete.swift        # ⌘K command palette with search + quick-create
│   │
│   ├── Onboarding/
│   │   └── Onboarding.swift            # 3-step first-launch onboarding sheet
│   │
│   ├── Services/
│   │   ├── DiffService.swift           # Line diff engine using CollectionDifference
│   │   ├── ExportService.swift         # Stub (not yet implemented)
│   │   └── WebSocketService.swift      # @Observable WebSocket connect/send/receive
│   │
│   └── Storage/
│       └── PersistenceController.swift # SwiftData ModelContainer singleton
│
└── Views/
    ├── Main/
    │   ├── ContentView.swift           # NavigationSplitView shell (Editor + Response + Code)
    │   ├── MainView.swift              # Full workspace: AI overlay, toolbar, command palette
    │   ├── SidebarView.swift           # Folders, requests, environments, context menus
    │   └── CodeView.swift              # Code snippet generator (cURL/Swift/Python/JS)
    │
    └── Response/
        ├── ResponseView.swift          # 4-tab response viewer + Vision AI trigger
        ├── ResponseDetailView.swift    # Detached window response view with search highlighting
        └── WebView.swift               # WKWebView NSViewRepresentable with theme + video support
```

---

## Architecture Overview

`api-play` follows a feature-based layered architecture:

```
┌─────────────────────────────────────────────────────────┐
│                        Views Layer                       │
│   MainView · ContentView · SidebarView · ResponseView   │
│             CodeGenView · EditorView                    │
└────────────────────────┬────────────────────────────────┘
                         │ binds / observes
┌────────────────────────▼────────────────────────────────┐
│                     Features Layer                       │
│  AICoordinator · NetworkManager · WebSocketService      │
│  DiffService · PersistenceController                    │
└────────────────────────┬────────────────────────────────┘
                         │ reads / writes
┌────────────────────────▼────────────────────────────────┐
│                      Core Layer                          │
│  SwiftData Models · JSONNode · KeychainHelper           │
│  APIResponse · KVPair · HTTPMethod · AuthType           │
└─────────────────────────────────────────────────────────┘
```

**State management** relies on:
- `@Observable` (AICoordinator, SidebarViewModel, WebSocketService)
- `@ObservableObject` / `@StateObject` (NetworkManager)
- `@Query` for reactive SwiftData fetches
- `@Bindable` for in-place model editing
- `NotificationCenter` for cross-component events (command palette trigger, request selection)

---

## Core Modules

### `NetworkManager`

The central HTTP engine. Decorated with `@MainActor` and conforms to `ObservableObject`.

**Responsibilities:**
- Builds `URLRequest` objects from an `APIRequest` model and an optional `APIEnvironment`
- Applies `{{variable}}` interpolation to URLs, header values, and body content
- Handles REST body (`application/json`) and GraphQL body (wraps query + variables as JSON)
- Applies auth headers for Bearer, Basic, and API Key strategies
- Appends enabled query parameters from the `params` array
- Detects binary responses (image/pdf) and stores raw `Data` bytes alongside a readable `bodyString`
- Exposes `isLoading`, `response: APIResponse?`, and `error: NetworkError?` as `@Published` properties

### `KeychainHelper`

A static, zero-dependency wrapper around the `Security` framework.

- `write(_ value: String, forKey key: String)` — upserts a password entry under `com.api-play.envvars`
- `read(forKey key: String) -> String?` — retrieves stored value
- `delete(forKey key: String)` — removes the entry

### `JSONNode` + `JSONParser`

A recursive enum that models a JSON document as a tree of typed nodes:

```swift
indirect enum JSONNode: Identifiable {
    case object(key: String?, children: [JSONNode])
    case array(key: String?, children: [JSONNode])
    case string(key: String?, value: String)
    case number(key: String?, value: String)
    case bool(key: String?, value: Bool)
    case null(key: String?)
}
```

`JSONParser.parse(_:)` converts any valid JSON string into this tree using `JSONSerialization`, correctly distinguishing `Bool` from `NSNumber` via `kCFBooleanTrue`/`kCFBooleanFalse` pointer comparison. The tree is designed for use with SwiftUI's `OutlineGroup`.

---

## Feature Modules

### `AICoordinator`

An `@Observable` class that bridges the **FoundationModels** and **Vision** frameworks.

**`explainResponse(_ body: String)`**
- Checks `SystemLanguageModel.default.isAvailable` before proceeding
- Truncates payloads > 2000 characters to stay within token limits
- Opens a `LanguageModelSession` and sends a structured developer-assistant prompt
- Updates `analysisResult` on the main actor

**`analyzeVisualContext(text: String)`**
- Accepts OCR-extracted text from the Vision framework
- Sends a UI-interpretation prompt to the language model
- Falls back to displaying raw OCR text if the model fails

### `WebSocketService`

An `@Observable` class wrapping `URLSessionWebSocketTask`.

- `connect(url: URL)` — creates a task and starts the recursive `listen()` loop
- `send(_ text: String)` — sends a string message and appends it to `messages` on success
- `disconnect()` — cancels with `.goingAway` close code
- Incoming messages are appended as `WebSocketMessage(isOutgoing: false)` on the main actor

### `DiffService`

- Uses `newLines.difference(from: oldLines)` (Swift `CollectionDifference`) for O(n) diffing
- `prettifyForDiff(_:)` normalizes JSON with sorted keys and pretty-printing before comparison
- Shared via `DiffService.shared` singleton

### `PersistenceController`

Manages the SwiftData `ModelContainer` for the app's lifespan.

```swift
let schema = Schema([
    APIRequest.self,
    APIEnvironment.self
])
```

- `save()` — conditionally saves the main context only when `hasChanges` is true
- `clearAllData()` — deletes all `APIRequest` and `APIEnvironment` records (for a "Reset App" action)

---

## Views

### `MainView`

The top-level workspace view. Provides:
- `NavigationSplitView` with sidebar column (250–350 pt) and a detail column
- Toolbar items: AI Insights toggle (`⌘I`), New Window button, Environment picker
- Animated AI Inspector panel that slides in from the trailing edge of the response area
- Command Palette sheet triggered via `⌘K`
- A `CodeGenView` fixed-width column (350 pt) on the right of the detail area

### `SidebarView`

- Sections: **Collections** (folder tree) and **Requests** (flat root requests)
- `@Query` fetches with sort and filter predicates directly from SwiftData
- `FolderDisclosure` renders nested `RequestFolder` trees with drag-and-drop target support
- `RequestRow` shows HTTP method badge (color-coded), request name, and a favorite star
- Context menu per request: Pin, Rename, Duplicate, Delete
- Environment header with a picker and an edit button that opens `EnvironmentEditor`
- `+` toolbar menu: New Request, New Folder, New Environment

### `EditorView`

A tabbed request builder:
- **URL Bar**: Method picker + URL field + Send button (`⌘↵`) + Save button
- **Tabs**: Params, Headers, Auth, Body
- `KVPairEditor` — enabled/disabled toggle + key/value fields for params and headers
- `BodyEditorView` — monospaced `TextEditor` with file drag-and-drop and a "Format JSON" footer
- `AuthEditorView` — auth type picker with a conditional token input field
- Switches to `GraphQLEditorView` when `requestType == .graphql`

### `GraphQLEditorView`

- Query and Variables sub-tabs with character count footer
- Clear and Prettify toolbar actions
- `.writingToolsBehavior(.complete)` enabled for macOS 26 Writing Tools integration

### `ResponseView`

- **Toolbar**: Status badge, elapsed time, size, view mode picker, copy button
- **JSON tab**: Prettified, selectable monospaced text
- **Raw tab**: `TextEditor` in read-only constant binding
- **Headers tab**: Sorted key/value `List` with monospaced value text
- **Preview tab**: Full `WebView` with a "Visual Explain" button that triggers Vision OCR → AI pipeline
- Inspector panel for AI results (`isPresented: $isShowingAI`)
- Footer bar: Content-Type, request ID (first 8 chars of UUID)

### `CodeGenView`

- Language selector: cURL, Swift, Python, JavaScript
- GraphQL schema introspection via `POST { __schema { types { name } } }` query
- Floating copy button with spring animation and checkmark confirmation
- Adaptive header (switches between HStack and VStack via `ViewThatFits`)
- Footer: Live Sync / Draft status indicator

### `WebView`

An `NSViewRepresentable` wrapping `WKWebView`:
- JavaScript enabled via `WKWebpagePreferences`
- Custom user-agent mimicking Safari 17 for compatibility
- Transparent background to match SwiftUI theming
- Detects direct video URLs and wraps them in a full-screen HTML5 `<video>` player
- Wraps all other content in a `color-scheme: light dark` system-themed HTML shell

### `CommandPaletteView`

A `550 × 400` sheet with:
- Auto-focused search field
- "Suggested Commands" when empty: New REST Request, New GraphQL Request
- "Recent Requests" showing the 6 most recently updated requests
- Live filtering by name or URL
- `⏎` to execute the top result
- Posts `SelectRequestInMainView` notification to select the chosen request without tight coupling

---

## Data Models

### `APIRequest` (`@Model`)
| Property | Type | Notes |
|---|---|---|
| `id` | `UUID` | Unique, indexed |
| `name` | `String` | Display name |
| `urlString` | `String` | Raw URL, supports `{{var}}` placeholders |
| `httpMethod` | `HTTPMethod` | Enum: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS |
| `params` | `[KVPair]` | Query parameters |
| `headers` | `[KVPair]` | HTTP headers |
| `requestBody` | `String` | Raw body text |
| `auth` | `AuthType` | none / bearer / basic / apiKey |
| `authToken` | `String` | Bearer token or password |
| `requestType` | `RequestType` | `.rest` or `.graphql` |
| `graphqlQuery` | `String` | GQL operation |
| `graphqlVariables` | `String` | JSON variables string |
| `lastResponse` | `APIResponse?` | Most recent response (Codable, stored inline) |
| `isFavorite` | `Bool` | Pinned indicator |
| `tags` | `[String]` | For future filtering |
| `folder` | `RequestFolder?` | Parent collection |
| `updatedAt` | `Date` | Used for recency sort |

### `RequestFolder` (`@Model`)
Supports hierarchical nesting via `parent: RequestFolder?` and `children: [RequestFolder]?` relationships (cascade delete). Holds `requests: [APIRequest]?` with cascade delete.

### `APIEnvironment` (`@Model`)
Holds a name, `isActive` flag, and a cascade-delete `variables: [EnvVar]` relationship.

### `EnvVar` (`@Model`)
`key`, `value`, `isEnabled`, `isSensitive` flags. Inverse relationship to `APIEnvironment`.

### `APIHistory` (`@Model`)
Stores historical snapshots: `url`, `method`, `requestBody`, `responseBody`, `statusCode`, `duration`, `timestamp`.

### `APIResponse` (`Codable`, `Hashable`)
| Property | Notes |
|---|---|
| `statusCode` | HTTP status integer |
| `bodyData` | Raw `Data?` bytes (for binary/image responses) |
| `body` | UTF-8 string representation |
| `headers` | `[String: String]` |
| `elapsedSeconds` | Response time |
| `byteCount` | Raw byte count |
| `url` | Final resolved URL string |

---

## Getting Started

1. **Clone or unzip** the project and open `api-play.xcodeproj` in Xcode 26 or later.

2. **Build and run** on a Mac running macOS 26.4+. No third-party dependencies are required — the project uses only Apple frameworks.

3. On first launch, the **Onboarding** sheet will walk you through the core features. It can be dismissed at any time and is controlled by `@AppStorage("shouldShowOnboarding")`.

4. Use the **`+` button** in the sidebar toolbar to create a new Request, Folder, or Environment.

5. Select a request, enter a URL, choose a method, and press **Send** (`⌘↵`).

6. Press **`⌘K`** to open the Command Palette for quick navigation and request creation.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘↵` | Send request |
| `⌘K` | Open Command Palette |
| `⌘I` | Toggle AI Insights panel |
| `⌘S` | Save request |

---

## Configuration

### Environment Variables
Create environments from the sidebar `+` menu. Add key/value pairs in the `EnvironmentEditor` sheet. Reference them anywhere in your request using `{{variableName}}` syntax. Sensitive values should be stored via `KeychainHelper` to avoid plain-text persistence.

### Resetting All Data
Call `PersistenceController.shared.clearAllData()` to wipe all requests and environments from the SwiftData store. This is intended for a "Reset App" settings action.

### Apple Intelligence
Apple Intelligence features are gated on `SystemLanguageModel.default.isAvailable`. If the model is still downloading or the device is unsupported, the AI panel will display an informational message instead of an analysis result.
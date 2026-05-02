# api-play

A native macOS API client built with SwiftUI, designed for speed, clarity, and deep platform integration. `api-play` supports REST and GraphQL requests, on-device AI response analysis via Apple Intelligence, WebSocket connections, and a clean multi-panel workspace — all without leaving the Apple ecosystem.

## 🚀 Features

- **REST & GraphQL Support**: Full HTTP method support, body editors, and live GraphQL schema introspection.
- **Environments & Secrets**: Dynamic variables with `{{placeholder}}` interpolation. Sensitive keys are stored securely in the macOS Keychain.
- **Advanced Response Inspection**: View JSON Trees, Raw text, Headers, and a **Rich Preview** (renders HTML, images, PDFs, and videos natively).
- **Apple Intelligence**: On-device AI payload analysis and Vision-powered OCR for UI context interpretation.
- **Code Generation**: Export ready-to-use snippets for cURL, Swift, Python, and JavaScript.
- **Workspace & Navigation**: Resizable multi-panel layout, Command Palette (`⌘K`), folder collections, and multi-window support.
- **100% Native**: Built entirely with Swift, SwiftUI, SwiftData, and Apple frameworks. Zero third-party dependencies.

## 💻 Requirements

- **OS**: macOS 26.4+ (Apple Silicon recommended for Neural Engine AI features)
- **Environment**: Xcode 26.0+
- **Core Frameworks**: SwiftUI, SwiftData, WebKit, Vision, FoundationModels, Security

## 🛠 Getting Started

1. Clone the repository.
2. Open `api-play.xcodeproj` in Xcode.
3. Build and run. (No package managers or external dependencies required!)

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘↵` | Send Request |
| `⌘K` | Open Command Palette |
| `⌘I` | Toggle AI Insights Panel |
| `⌘S` | Save Request |

## 🏛 Architecture Overview

`api-play` utilizes a modern, feature-based architecture powered by **SwiftData** for local persistence and **Observation** for reactive state.
- **NetworkManager**: An actor-isolated engine handling asynchronous requests, binary handling, and environment interpolation.
- **PersistenceController**: A streamlined SwiftData model container manager.
- **AICoordinator**: Bridges local Language Models and Vision frameworks to explain complex API payloads and visual elements without requiring cloud processing.

---
*Built for the Apple ecosystem.*
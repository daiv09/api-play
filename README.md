# api-play

<p align="center">
  <em>A high-performance, native API workbench built with SwiftUI and SwiftData.</em>
</p>

---

## 1. Introduction & Architecture

**api-play** is an elegant, lightning-fast native macOS application designed to simplify API development, testing, and debugging. Unlike electron-based behemoths that consume vast amounts of memory, `api-play` is built entirely on native Apple frameworks: **SwiftUI** for a butter-smooth, responsive user interface and **SwiftData** for secure, local-first state management.

### The Native Experience
We designed `api-play` to feel right at home on your Mac:
- **Native Split-Views:** An organized, resizable, and collapsible sidebar architecture for managing your workspaces.
- **Unified Pill-Shaped Toolbar:** Modern, unobtrusive window controls that keep the focus on your data.
- **Dynamic Inspector Panels:** Beautifully animated sliding panels and contextual sheets for code generation, environment management, and AI insights.
- **Zero-Latency Interactions:** Thanks to SwiftData and native rendering, switching between complex JSON trees, raw payloads, and historical commits is instantaneous.

---

## 2. Core Functional Features

### FEATURE 1: Resource Management (Requests, Folders, & Environments)
Managing a sprawling collection of API endpoints can be chaotic. `api-play` introduces a seamless, native sidebar structure:
- **Collections & Folders:** Group related endpoints logically. Create hierarchical folders to manage entire service architectures.
- **Drag-and-Drop:** Easily reorganize your workspace by dragging requests between folders or reordering them natively.
- **Workspaces:** Keep your data cleanly segmented without relying on cloud synchronization.

### FEATURE 2: Multi-Protocol Request Engine (REST, GraphQL, Local Webhooks)
Test any service directly within the app. Below are interactive sandboxes and examples you can copy-paste directly into your client.

#### REST API Testing Sandbox
* **Methods Supported:** `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`.
* **Data Layouts:** Comprehensive interfaces for Query Params, Headers, Authentication, and dynamic Body Payloads (`RAW`, `JSON`, `XML`, `PLAIN`).
* **Live Testing Links:**
  * *GET / User Fetch:* `https://jsonplaceholder.typicode.com/users` (Great for inspecting JSON tree structures and headers).
  * *POST / Mutation Mimic:* `https://httpbin.org/post` (Perfect for validating multi-type body payloads).
  * *Auth Validation:* `https://httpbin.org/basic-auth/user/passwd` (Validate HTTP Basic authentication base64 encoding).

#### GraphQL API Testing Sandbox
* **Endpoint 1 (Rick and Morty API):**
  * URL: `https://rickandmortyapi.com/graphql` | Method: `POST`
  * *Request A (Simple Character Query):*
    ```graphql
    query GetCharacters {
      characters(page: 1) {
        results {
          id
          name
          status
          species
        }
      }
    }
    ```
  * *Request B (Filter with Variables/Params):*
    ```graphql
    query FilterCharacters($name: String!,$status: String!) {
      characters(filter: { name: $name, status:$status }) {
        results {
          name
          gender
          origin {
            name
          }
        }
      }
    }
    ```
  * *Variables (JSON Parameters):*
    ```json
    {
      "name": "Morty",
      "status": "Alive"
    }
    ```
* **Endpoint 2 (Countries API):**
  * URL: `https://countries.trevorblades.com/` | Method: `POST`
  * *Request A (Continents & Languages):*
    ```graphql
    query GetContinents {
      continents {
        code
        name
        countries {
          name
          capital
        }
      }
    }
    ```

#### Local Webhook Integration
`api-play` features a built-in HTTP server to catch incoming payloads from third-party services like Stripe or GitHub.
* **Default Loopback Target:** `http://localhost:8080`
* **Workflow:** Toggle the receiver on from the sidebar. You can route local microservice traffic to this port, read structural headers in real-time, intercept JSON payloads, and test your local pipeline offline with absolute security.

### FEATURE 3: OCR & Smart Image Drag-and-Drop
Stop manually typing out endpoints from screenshots or documentation graphics. 
- **Vision Mechanics:** Simply drag an image containing an API link, cURL command, or text snippet directly into the Sidebar.
- **Instant Generation:** `api-play` leverages Apple's on-device Vision framework to parse the layout text and instantly spin it up into an organized, functional API request.

### FEATURE 4: Multi-Dimensional Response Inspector
Analyzing API responses has never been this flexible. The Response Context view area adapts to your data:
- **Raw:** Unformatted, lightning-fast text output for massive payloads.
- **Headers:** Complete metadata key-value parsing matrices to inspect rate limits, content types, and server tags.
- **JSON:** Beautifully colorized, expandable, and interactive JSON tree structures. Navigate complex nested arrays with ease.
- **Preview:** An embedded native WebKit rendering frame showing a live preview of targeted web pages and HTML responses.

### FEATURE 5: Time-Travel Version Control (State Commits)
Never lose a working request configuration. `api-play` offers native tracking of request mutations.
- **Historical Snapshots:** Every significant change can be captured as a state commit.
- **Diff Logs:** View explicit side-by-side diff logs comparing your current draft with historical snapshots (endpoints, headers, parameters, or payloads).
- **Rollbacks:** Gracefully roll back and restore to any historical request snapshot instantly.

### FEATURE 6: AI Client Agent
`api-play` integrates a powerful natural language engine to automate API construction.
- Simply open the Command Palette (`Cmd+K`) or the AI Inspector and prompt the built-in assistant.
- **Examples:** Ask the agent to *"Create an authenticated POST request for checkout"*, *"Update the header keys to accept bearer tokens"*, or *"Generate mock JSON data for a user profile"*. The agent executes the operations seamlessly on your workspace.

### FEATURE 7: Dynamic Environment Variables
Switching between `Development`, `Staging`, and `Production` is effortless.
- **Setup Variable Dictionaries:** Define global keys like `{{baseUrl}}` or `{{token}}` inside active configuration states.
- **Automatic Injection:** The client automatically injects these values during request compilations based on the globally chosen environment bubble. Change environments, and all your requests instantly point to the new targets.

### FEATURE 8: Native Apple Intelligence Integration
Pushing boundaries with macOS native AI frameworks, `api-play` leverages native OS intent engines for:
- Writing adjustments and query refinement.
- Intelligent response summarizations (explaining complex JSON errors).
- Data parsing and contextual schema building entirely on-device.

### FEATURE 9: Universal Code Snippet Generator
Once your API request is perfected, share it anywhere.
- **Export Formats:** Instantly export your curated requests into copy-paste code snippets for cross-platform integration.
- **Supported Languages:** Generates ready-to-use code for Swift (`URLSession`), cURL, Python (`requests`), JavaScript (`fetch`), Node.js, and more. 

### FEATURE 10: WebSocket Client Integration
Modern APIs go beyond static HTTP calls. `api-play` includes native WebSocket support:
- **Live Connections:** Connect to `ws://` or `wss://` endpoints seamlessly.
- **Real-Time Logs:** Monitor incoming and outgoing message streams with native rendering.

### FEATURE 11: Quick Request MenuBar Mini-App
Need to fire off a fast request without breaking your flow?
- **Global Accessibility:** Access `api-play` directly from the macOS MenuBar.
- **Rapid Testing:** The Quick Request mini-app allows you to dispatch REST calls and inspect payloads in a compact floating window while you code in Xcode or VS Code.

### FEATURE 12: HAR (HTTP Archive) Parsing
Migrate your network logs effortlessly.
- **Import/Export:** Support for parsing `.har` files.
- **Network Analysis:** Drag in a HAR file exported from your browser's developer tools to automatically reconstruct the API calls natively inside `api-play`.

---

<p align="center">
  <em>Designed for developers, powered by native performance, secured by local-first architecture.</em>
</p>
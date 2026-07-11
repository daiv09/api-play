# Privacy Policy for api-play

**Last Updated: July 2026**

At `api-play`, we believe that your development configurations, security credentials, and application payloads belong exclusively to you. This application has been engineered from the ground up to operate under a strict **local-first paradigm**. This document serves as our binding commitment to data locality, absolute zero-telemetry, and the preservation of digital privacy during programmatic testing.

---

## 1. Architectural Blueprint & Data Locality

`api-play` executes all runtime operations, data updates, and persistent state management locally within your physical machine's isolated application sandbox. The software does not communicate with any external proprietary cloud storage, synchronization servers, or backend databases managed by `api-play` or its creators.

| Data Category | Storage Mechanism | Storage Location | Data Retention Policy |
| :--- | :--- | :--- | :--- |
| **API Requests & Collections** | SwiftData / CoreData Engine | Local Application Sandbox | Permanent until deleted by user |
| **Auth Tokens & Private Keys** | Encrypted Sandbox Storage | On-Device Key Containers | Permanent until deleted by user |
| **Active Environment Variables** | SwiftData Core Records | On-Device Key Containers | Permanent until deleted by user |
| **Time-Travel Diff States** | Relational Graph Entries | Local Application Sandbox | User-configurable history limits |

### Remote Synchronization Boundaries
Your application data is bound to your physical disk. Cloud backup routines occur only if:
1. You explicitly choose to utilize native operating system backup suites (e.g., Apple Time Machine).
2. You manually enable iCloud Drive container state replication within your system level preferences.

---

## 2. Absolute Zero-Telemetry Protocol

We maintain a complete firewall against tracking software, analytics frameworks, and marketing surveillance metrics.

* **No Third-Party Analytics SDKs:** The application binary entirely excludes structural collection SDKs from tracking aggregators, including but not limited to Firebase, Mixpanel, Segment, or Google Analytics.
* **No Behavioral Event Tracking:** We do not record, intercept, or map out interface execution metrics. Your layout adaptations, window states, execution triggers, and operational patterns are strictly confidential to your local display engine.
* **Anonymized System Crash Reporting:** Diagnostic crash debugging is strictly passive. `api-play` does not silently dispatch independent diagnostic logs. System crash captures are funneled solely through Apple’s system-level, opt-in macOS Analytics pipeline.

---

## 3. Intelligent Processing & AI Privacy Firewalls

`api-play` includes powerful natural language processing mechanisms, automation triggers, and multi-modal ingestion systems designed to accelerate modern API engineering. These components are strictly insulated to maintain a strict data boundary:

### On-Device Vision Engine (OCR Link Extraction)
When an image containing text, links, or cURL instructions is dragged and dropped directly into the sidebar, processing is handled natively by Apple’s secure **Vision Framework**. The image arrays are broken down using your machine's local Neural Engine. This data remains completely offline and is discarded from memory immediately after structural request conversion.

### AI Client Agent & Natural Language Adjustments
* **Direct Handshake Routing:** Commands passed to the integrated AI Assistant interface to alter headers, append variables, or generate requests are sent directly to your user-configured API endpoints.
* **Zero Model Training Exposure:** We do not intercept, collect, cache, or scan your textual prompts, schema properties, or generated code snippets. Your engineering telemetry is never used for external artificial intelligence model training, reinforcement learning, or human review.

---

## 4. Network Isolation & Operational Security

The application limits its network footprint exclusively to outbound debugging pipelines initiated directly by user interaction.

### Outbound Client Dispatches
When executing a REST, GraphQL, or raw HTTP/HTTPS protocol request, traffic is routed cleanly from your workspace directly to the designated remote server. We do not use intermediary reverse-proxies, custom cloud gateways, or corporate log relays. Your data packets remain untampered and unmonitored.

### Local Webhook Interceptor Sandbox
The integrated webhook testing utility binds natively and uniquely to your internal loopback adapter:
```http
http://localhost:8080
```

This listener operates purely as an internal local loopback server. It is entirely unexposed to external internet discovery, public port-forwarding networks, or local area network configurations unless explicitly exposed by the developer using third-party tunneling software.

## 5. Administration, Compliance, & Disclosures
Because `api-play` enforces an authentic local-first framework, we do not register user accounts, manage cloud profiles, or maintain databases containing personal, identifiable, or transactional developer information.
Consequently, we have no mechanism to store, modify, or delete your user parameters upon request. You hold absolute, autonomous authority over your data profile. For core structural inquiries regarding code safety or to file an architectural ticket, please interface directly with our official technical team via the repository's GitHub Issues tracker.
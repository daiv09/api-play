# Privacy Policy for api-play

**Effective Date:** 13-06-2026 <br>
**App Name:** api-play <br>
**Platform:** macOS

---

## 1. Our Privacy Philosophy

Privacy is not an afterthought in api-play — it is a foundational design
principle. api-play is a native macOS developer tool for configuring,
sending, and organizing REST, GraphQL, and WebSocket network requests.

We believe that the requests you build, the credentials you use, and the
configurations you create are exclusively yours. api-play is designed so
that this information remains entirely under your control, on your own
device, at all times. The developer of api-play has no access to, and does
not want access to, any of your data, requests, or settings.

---

## 2. Zero Data Collection & Analytics

api-play does **not** collect any personal data, usage data, or diagnostic
information from you or your device.

Specifically, api-play does **not** include or use:

- Third-party analytics SDKs or trackers
- Crash reporting or diagnostics frameworks
- Remote telemetry of any kind
- Advertising identifiers or advertising networks
- Any mechanism that transmits usage metrics, behavioral data, or device
  information to the developer or to any third party

No information about how you use api-play — including which requests you
run, which APIs you connect to, or how the app is configured — is ever
collected, logged remotely, or transmitted anywhere. Your activity within
the app is known only to you and to your Mac.

---

## 3. Local-Only Storage

All data created, imported, or managed within api-play is stored
**exclusively on your local Mac storage volume**, using Apple's SwiftData
framework within the app's sandboxed container.

This includes, without limitation:

- Request collections, folders, and individual requests (REST, GraphQL,
  and WebSocket configurations)
- Environment definitions and environment variables
- Request history, version snapshots, and commit diffs
- Application preferences and configuration settings
- Imported data, such as HAR files you choose to bring into the app

None of this information is synced to, backed up to, or transmitted to any
server operated by the developer. api-play does not operate any backend
infrastructure, and there is no "account" or "cloud sync" system of any
kind. If you delete api-play or its application data, this information is
permanently removed from your device.

---

## 4. Security of Sensitive Data

api-play takes additional precautions with data that is sensitive in
nature:

- **OAuth tokens:** Where api-play's automatic authentication-refresh
  feature is used, access and refresh tokens are stored using the macOS
  **Keychain**, Apple's secure, system-level credential storage,
  rather than in the application's general data store.
- **Authorization headers, API keys, and other credentials you enter:**
  These values are stored locally within api-play's sandboxed application
  container on your Mac. They are never transmitted to the developer, and
  they remain isolated from other applications by macOS App Sandbox
  protections. Values you mark as sensitive are masked in the user
  interface by default.

In all cases, this information stays on your device and is used solely to
construct the network requests you explicitly choose to send.

---

## 5. Third-Party Network Interaction

api-play does not communicate with any servers operated by the developer,
and does not route your traffic through any third-party intermediary.

The **only** network connections api-play makes are the ones **you
explicitly initiate** — for example, by pressing "Send" on a REST request,
executing a GraphQL operation, or opening a WebSocket connection.

In each case:

- The connection is made directly between your Mac and the specific host
  or endpoint **you have defined** within your request configuration.
- No request data, response data, headers, or payloads are copied,
  logged, or transmitted to the developer or to any analytics or
  monitoring service.
- The app's local webhook receiver, when enabled, listens only for
  incoming connections that you choose to direct to it (e.g., from your
  own testing tools), and does not expose any data beyond your local
  network configuration.

Any data that is sent to or received from third-party API providers as a
result of requests you build is governed by **that provider's own privacy
policy**, not by api-play.

---

## 6. Changes to This Policy

We may update this Privacy Policy from time to time to reflect changes to
the application or for other operational, legal, or regulatory reasons.
Any changes will be reflected by an updated "Effective Date" at the top of
this document. We encourage you to review this policy periodically.

## 7. Contact Us

If you have any questions, concerns, or feedback regarding this Privacy
Policy or api-play's data practices, please contact:

**Developer:** Daiwiik Harihar <br>
**Email:** daiwiikharihar17147@gmail.com <br>
**Repository:** [daiv09/api-play](https://github.com/daiv09/api-play)

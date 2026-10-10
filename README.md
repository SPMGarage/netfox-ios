<p align="center">
  <img src="netfox-logo.svg" alt="netfox" />
</p>

<p align="center">
<img alt="Version" src="https://img.shields.io/badge/version-4.0.0-green.svg?style=flat-square" />
<img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2017%2B-blue.svg?style=flat-square" />
<img alt="Swift" src="https://img.shields.io/badge/swift-6.2%2B-orange.svg?style=flat-square" />
<img alt="SPM" src="https://img.shields.io/badge/SPM-compatible-brightgreen.svg?style=flat-square" />
<a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat-square" /></a>
</p>

# netfox-ios

An in-app network inspector for iOS. netfox captures every HTTP(S) request your app makes — your own code, `URLSession.shared`, Alamofire and any other library built on `URLSession` — and shows it in an inspector you open by shaking the device.

<!-- GIF placeholder: assets/overview.gif (hero recording) -->

**Maintained by [Azimjon Abdurasulov](https://azimjondev.uz)** — a fork of [kasketis/netfox](https://github.com/kasketis/netfox), rebuilt for Swift 6 and modern SwiftUI.

## Quick start

1. Add the package `https://github.com/azimxxm/netfox-ios` (version 4.0.0 or later).
2. Start netfox at launch, in debug builds only:

   ```swift
   import netfox

   #if DEBUG
   NFX.shared.start()
   #endif
   ```

3. Run the app, make some requests and shake the device. In the Simulator use **Device ▸ Shake** or ⌃⌘Z.

You don't need any other setup. netfox captures requests from `URLSession.shared`, your own sessions and libraries such as Alamofire.

## What's new in 4.0

- **Swift 6 language mode** with strict concurrency checking, built with zero warnings.
- **Modern SwiftUI on iOS 17+**: Observation (`@Observable`), `NavigationSplitView` (list and detail side by side on iPad, a stack on iPhone), `ContentUnavailableView`, `ShareLink` and Swift Charts. The inspector picks up Liquid Glass automatically on iOS 26 and later.
- **Rewritten capture engine.** All captured requests now go through one shared internal `URLSession`, so connections are reused. Captured requests are stored as immutable, thread-safe records.
- **Request timeline.** Each request shows DNS, connect, TLS, send, wait and receive timings, taken from `URLSessionTaskMetrics`.
- **TLS certificate details:** subject, issuer, validity dates, key type and chain length.
- **Body handling.**
  - Bodies are stored as raw bytes, so binary responses are kept instead of disappearing.
  - JSON is pretty-printed in the original key order and without `\/` escapes.
  - Large bodies open in a scrolling text view with Find. JSON over 200 KB is shown without colors to keep it responsive.
- **Each redirect step is its own entry** (`302 → 302 → 200`), with no empty placeholder rows.
- **HAR export** follows HAR 1.2. The tests check every field Chrome DevTools requires when importing.
- **"Copy as cURL"** produces commands you can paste straight into a terminal, including JSON bodies.
- **Public WebSocket logging API**, safe to call from any thread.
- **Fixes:**
  - requests with streamed bodies no longer hang;
  - `start()` no longer deletes files from your app's Documents folder;
  - the inspector can always be reopened.
- **Tests:** a Swift Testing suite (runs on macOS and the iOS Simulator), plus a demo app with a UI walkthrough test.

## Requirements

|       |                                                                         |
| ----- | ----------------------------------------------------------------------- |
| iOS   | 17.0+ (macOS 14+: request capture only, no inspector UI)                |
| Xcode | 26 or later                                                             |
| Swift | 6.2+ (tools version) — your app can still use the Swift 5 language mode |

### Older iOS versions

Older releases keep working. Pick the one that matches your app's minimum deployment target:

| netfox | Minimum iOS | Swift Package Manager |
|---|---|---|
| **4.x** | iOS 17 | `.package(url: "https://github.com/azimxxm/netfox-ios", from: "4.0.0")` |
| 3.0.0 | iOS 15 | `.package(url: "https://github.com/azimxxm/netfox-ios", .upToNextMajor(from: "3.0.0"))` |
| 2.1.0 | iOS 12 | `.package(url: "https://github.com/azimxxm/netfox-ios", .upToNextMajor(from: "2.0.0"))` |

`from: "3.0.0"` means 3.0.0 up to (but not including) 4.0.0, so existing apps are never moved to 4.x automatically.

## Installation

### Swift Package Manager

In Xcode: **File ▸ Add Package Dependencies…** and enter:

```
https://github.com/azimxxm/netfox-ios
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/azimxxm/netfox-ios", from: "4.0.0")
]
```

## Setup

Start netfox as early as possible, and only in debug builds.

### SwiftUI

```swift
import SwiftUI
import netfox

@main
struct YourApp: App {
    init() {
        #if DEBUG
        NFX.shared.start()
        #endif
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}
```

### UIKit

```swift
import UIKit
import netfox

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    #if DEBUG
    NFX.shared.start()
    #endif
    return true
}
```

**That's it.** Shake the device to open the inspector (in the Simulator: **Device ▸ Shake**, or ⌃⌘Z), and shake again to close it.

> Keep netfox behind `#if DEBUG`. It intercepts every request your app sends and stores the bodies on disk. Xcode defines `DEBUG` for the Debug configuration of new projects, so no build setting is needed.

## Usage

### Open and close the inspector yourself

```swift
NFX.shared.setGesture(.custom)   // turn off the shake gesture

NFX.shared.show()
NFX.shared.hide()
NFX.shared.toggle()

NFX.shared.show(on: someViewController)   // present from a specific view controller
```

All `NFX` methods are thread-safe. `show()`, `hide()` and `toggle()` hop to the main thread when they need to.

### Ignore URLs

```swift
NFX.shared.ignoreURL("https://analytics.example.com")
NFX.shared.ignoreURLs(["https://logs.example.com", "https://metrics.example.com"])
NFX.shared.ignoreURLsWithRegex(#".*\.analytics\..*"#)   // an invalid pattern is logged and skipped
```

### Log WebSocket messages

`URLProtocol` can't see WebSocket frames, so log them yourself from your receive loop, from any thread:

```swift
NFX.shared.logWebSocketText(message, direction: .received, url: socketURL)
NFX.shared.logWebSocketData(data, direction: .sent, url: socketURL)
NFX.shared.logWebSocketPing(direction: .sent, url: socketURL)
```

### Session log, cache policy, stop

```swift
let log: Data? = NFX.shared.getSessionLog()          // plain-text log of this session
NFX.shared.setCachePolicy(.allowedInMemoryOnly)      // default: .notAllowed
NFX.shared.stop()                                    // stops capturing and clears the data
```

## Features

<!-- GIF: assets/search-filter.gif, assets/detail-body.gif, assets/share-export.gif, assets/statistics.gif, assets/ipad-split.gif -->

- **Request list.**
  - Each row shows a status dot, the method, the URL, duration, content type and size, with a dot on requests that are new since your last visit.
  - Search by URL, method or type.
  - Pin important requests (swipe right).
  - Compare two requests (swipe left).
  - Group requests by host.
- **Filters** by status code (2xx/3xx/4xx/5xx) and by response type (JSON, XML, HTML, image, other).
- **Request details.**
  - **Info:** URL, method, status, dates, duration, timeout and cache policy, plus the timing timeline and the TLS certificate.
  - **Request / Response:** headers (long-press to copy), query parameters and the body.
- **Body viewer.**
  - JSON syntax highlighting, with a Pretty / Raw switch and Find.
  - Image preview.
  - Binary bodies show their size and type and can be shared.
- **Actions:**
  - Copy as cURL.
  - Replay a request.
  - Share a single request's log.
  - Share the whole session log.
  - Export the session as a HAR file.
- **Statistics:** charts by status class and content type, the duration distribution, and totals and averages.
- **Device info:** app and OS versions, device model, screen. The public IP is looked up only when you tap the button.
- **Settings:**
  - turn capture on or off;
  - console logging (each request in Xcode's console via `os.Logger`);
  - TLS certificate capture;
  - haptic feedback on each new request;
  - split view on iPad.
- **Dark mode and Dynamic Type.**

## Demo app

`Example/NetfoxDemo.xcodeproj` is a small SwiftUI app with sample requests: JSON, POST and PATCH, images, HTML and XML, 404 and 500 responses, redirects, a slow request, an ephemeral session, a ~1 MB JSON file, a binary file and WebSocket messages.

1. Open it and run the **NetfoxDemo** scheme.
2. Tap **Send all requests**.
3. Shake the device.

Launch arguments:

| Argument        | What it does                                  |
| --------------- | --------------------------------------------- |
| `--send-all`    | Sends every sample request on launch          |
| `--open-netfox` | Opens the inspector after the requests finish |

`NetfoxDemoUITests` walks through every screen and attaches a screenshot of each one to the test result.

## How it works

netfox registers a `URLProtocol` subclass and swizzles `URLSessionConfiguration`, so every `URLSession`, including the ones created before `start()`, routes its requests through netfox.

netfox re-sends each request on one shared internal session and passes every callback back to your app unchanged: the response, data, redirects and authentication challenges. Captured requests become immutable `Sendable` records. Their bodies are written to the app's temporary directory.

The package has two targets:

- **`NetfoxCore`** is the capture engine. It has no UI and does no work on the main thread.
- **`netfox`** contains the public `NFX` API, the observable stores and the SwiftUI inspector.

## Known limitations

- **HTTP authentication.** Basic, Digest and NTLM challenges for intercepted requests get the system's default handling: your app gets the 401, and credentials in the URL still work. Forwarding these challenges to the app's own delegate makes the request hang on current iOS versions, so netfox doesn't. Server-trust (certificate pinning) and client-certificate challenges do reach your delegate.
- **Cookies.** Cookies set on requests from an ephemeral session, or a session with its own cookie storage, end up in `HTTPCookieStorage.shared` while netfox is running.
- **Refused redirects.** If your session delegate refuses a redirect, the task fails with error 3072 instead of returning the 3xx response.
- **WebSocket and background sessions.** `URLProtocol` doesn't see WebSocket frames (log them with the WebSocket API above) or background `URLSession` transfers.

## Migrating from 3.x

- **Minimum versions:** iOS 17, and Xcode 26 / Swift tools 6.2.
- **`NFX` is now `final` and thread-safe.**
  - `NFX.shared` is new.
  - `NFX.sharedInstance()` still works.
  - Every other 3.x method keeps its name.
- **No longer public:** `NFXProtocol`, `NFXHTTPModel` and `HTTPModelShortType` were internal details.
- **macOS:** the old window UI, which was never shipped through SwiftPM, is gone. On macOS, netfox captures requests and `getSessionLog()` works.

## Development

```bash
swift test                                   # unit and interception tests on macOS
xcodebuild test -scheme netfox \
  -destination 'platform=iOS Simulator,name=iPhone 17'              # the same tests on iOS
xcodebuild test -project Example/NetfoxDemo.xcodeproj -scheme NetfoxDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17'              # UI walkthrough
```

## Author

**Azimjon Abdurasulov** — iOS Developer

- Website: [azimjondev.uz](https://azimjondev.uz)
- GitHub: [@azimxxm](https://github.com/azimxxm)

## Credits

The original library is [kasketis/netfox](https://github.com/kasketis/netfox). Thanks to [tbaranes](https://github.com/tbaranes) and [vincedev](https://github.com/vincedev) for their earlier macOS contributions.

## License

MIT. See [LICENSE](LICENSE).

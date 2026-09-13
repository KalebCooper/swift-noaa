# swift-nws

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Swift package for the [National Weather Service API](https://www.weather.gov/documentation/services-web-API):
`Codable` models and endpoint descriptions you can send through any networking stack, and an SDK that
sends them for you through [swifty-networking](https://github.com/KalebCooper/swifty-networking).

## Status

In early development and not yet usable against the API. The package layout, both products, and their
test targets are in place; no endpoint, response model, or client exists yet. There is no release.

## Products

| Product | What it is | Depends on |
|---|---|---|
| `SwiftNWSModels` | Models and endpoint descriptions for the API, usable on any data layer. Today it carries `MediaType`. | Nothing. |
| `SwiftNWS` | The SDK that sends `SwiftNWSModels` endpoints. Today it carries `NWSConfiguration`, which holds the `User-Agent` the API requires. | `SwiftNWSModels`, swifty-networking. |

A consumer with its own networking stack adds only `SwiftNWSModels` and fetches no dependency at all.

## Requirements

- Swift 6.2 or later.
- iOS, macOS, tvOS, visionOS, and watchOS 26 or later, Linux, or Android.
- `SwiftNWS` depends on [swifty-networking](https://github.com/KalebCooper/swifty-networking) 1.0.0 or
  later. On Apple platforms it sends through `URLSession`. On Linux and Android, enable the
  off-by-default `HTTPPortable` trait, which pulls in AsyncHTTPClient and SwiftNIO; a consumer who
  leaves it off never fetches or builds either.

## Installation

```swift
.package(url: "https://github.com/KalebCooper/swift-nws.git", branch: "main")
```

On Linux or Android, enable the trait on the dependency:

```swift
.package(url: "https://github.com/KalebCooper/swift-nws.git", branch: "main",
         traits: ["HTTPPortable"])
```

Every change is recorded in [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE).

# swift-nws

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Swift package for the [National Weather Service API](https://www.weather.gov/documentation/services-web-API):
`Codable` models and endpoint descriptions you can send through any networking stack, and an SDK that
sends them for you through [swifty-networking](https://github.com/KalebCooper/swifty-networking).

## Status

In early development, with no release yet. What works today is the current-conditions lookup: the
point for a location, the observation stations near it, and a station's latest observation. Forecasts,
alerts, zones, and the rest of the API are not covered yet.

## Usage

```swift
import SwiftNWS

let client = NWSClient(
  configuration: NWSConfiguration(userAgent: "(myweatherapp.com, contact@myweatherapp.com)")
)

let observation = try await client.latestObservation(latitude: 30.2672, longitude: -97.7431)
print(observation.textDescription ?? "", observation.temperature?.value ?? .nan)
```

The API has no key, but it rejects requests without a `User-Agent` naming your application and a way
to contact you, so the configuration requires one.

Every request is also available as a plain value. Send it yourself, or through the client:

```swift
import SwiftNWSModels

let endpoint = Endpoint.point(latitude: 30.2672, longitude: -97.7431)
// GET https://api.weather.gov/points/30.2672,-97.7431, Accept: application/geo+json
let point = try await client.send(endpoint).properties
```

## Example

[`Examples/SwiftNWSDemo`](Examples/SwiftNWSDemo) is a small iOS app that shows the latest observation
for an address, geocoded with MapKit because the API has no geocoding, or for the device's location.
It references this package by local path. Open `Examples/SwiftNWSDemo/SwiftNWSDemo.xcodeproj` with the
package itself closed in Xcode, since Xcode lets a local package be open in only one window.

## Products

| Product | What it is | Depends on |
|---|---|---|
| `SwiftNWSModels` | `Endpoint` descriptions and the models their responses decode into: `Point`, `ObservationStation`, `WeatherObservation`, `QuantitativeValue`, `ProblemDetail`, and the GeoJSON `Feature` and `FeatureCollection` wrappers. Usable on any data layer. | Nothing. |
| `SwiftNWS` | `NWSClient`, which sends endpoints and follows the links between responses, with `NWSConfiguration` and one typed error, `NWSError`. It re-exports swifty-networking's `HTTPCore`, so `Transport` and `TransportError` need no import of their own. | `SwiftNWSModels`, swifty-networking, swift-http-types. |

A consumer with its own networking stack adds only `SwiftNWSModels` and fetches no dependency at all.

## Requirements

- Swift 6.2 or later.
- iOS, macOS, tvOS, visionOS, and watchOS 26 or later, Linux, or Android.
- `SwiftNWS` depends on [swifty-networking](https://github.com/KalebCooper/swifty-networking) 1.0.0 or
  later and [swift-http-types](https://github.com/apple/swift-http-types) 1.6.0 or later. On Apple
  platforms it sends through `URLSession`. On Linux and Android, enable the off-by-default
  `HTTPPortable` trait, which pulls in AsyncHTTPClient and SwiftNIO, and pass swifty-networking's
  `AsyncHTTPClientTransport` to `NWSClient(configuration:transport:)`; a consumer who leaves the trait
  off never fetches or builds either.

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

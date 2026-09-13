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
import SwiftNWSModels

let weather = NWSClient(userAgent: "(myweatherapp.com, contact@myweatherapp.com)")
let home = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)

let observation = try await weather.latestObservation(from: .nearest(to: home))
print(observation.textDescription ?? "", observation.temperature?.value ?? .nan)

// An explicit station needs just one HTTP request.
let stationObservation = try await weather.latestObservation(from: .station("KATT"))
```

The API has no key, but it requires a `User-Agent` naming your application and a way to contact you.
The short initializer uses the shared URL session on Apple platforms. The existing
`NWSClient(configuration:session:)` and `NWSClient(configuration:transport:)` initializers remain
available for custom sessions and transports.

Coordinates reject nonfinite values and values outside latitude -90...90 and longitude -180...180,
then round to four decimal places. The initializer throws `WeatherCoordinate.ValidationError`.

`.nearest(to:)` follows the point's station-list link and uses the first station on the returned
page. This preserves the service's ordering; it does not calculate distances, and the API does not
guarantee that the first station is geographically closest. The lookup takes three HTTP requests.
It does not filter stale observations, try a fallback station, cache points, or fetch additional pages.
Use the result's `stationId` and `timestamp` to assess its source and freshness.

### Reusable requests

The everyday method delegates to the same execution path as this request:

```swift
let request = WeatherRequest.latestObservation(from: .nearest(to: home))
let observation = try await weather.value(for: request)

// Contextual dot syntax also infers the response type.
let stationObservation = try await weather.value(
  for: .latestObservation(from: .station("KATT"))
)
```

Creating and storing a request performs no networking. Extend it with your own vocabulary:

```swift
extension WeatherRequest where Response == WeatherObservation {
  static var homeConditions: Self {
    .latestObservation(from: .station("KATT"))
  }
}

let observation = try await weather.value(for: .homeConditions)
```

Custom single-HTTP requests can supply their own endpoint and response model. For example, an app
can decode just the station identity from the existing observation endpoint:

```swift
struct StationIdentity: Decodable, Sendable {
  let stationId: String
}

let identityRequest = WeatherRequest(
  endpoint: Endpoint<Feature<StationIdentity>>(path: "/stations/KATT/observations/latest")
)
let identity = try await weather.value(for: identityRequest)
print(identity.properties.stationId)
```

The same initializer supports additional NWS endpoints when you supply their paths and response
models. Arbitrary custom multi-step workflows belong in your own async functions.

### Direct endpoints and other networking stacks

```swift
let endpoint = Endpoint.point(for: home)
// GET https://api.weather.gov/points/30.2672,-97.7431
// Accept: application/geo+json
let point = try await weather.send(endpoint)
print(point.id as Any, point.properties.gridId)
```

A consumer with its own networking stack needs only `SwiftNWSModels`. Send a GET to
`https://api.weather.gov` plus `endpoint.path`, set `Accept` to `endpoint.accept.rawValue`, supply
your own `User-Agent`, and decode the body as the endpoint's response type. Use
`Endpoint(accept:link:)` to validate service-provided links before following them.

`WeatherRequest.resolution` is also public and transport-independent: `.endpoint` describes one
HTTP call; `.latestObservation` describes an `ObservationSource`. A custom executor can interpret
the source using the lookup rules above. Requests contain no SDK or transport closures.

Direct endpoints preserve the existing GeoJSON wrappers, including `Feature.id` and
`Feature.properties`. Everyday observation methods return `WeatherObservation` directly.
Measurements can be absent or have a null value; unknown unit and quality codes remain strings.

### Errors and migration

The client throws `NWSError`: NWS problem details, transport or decoding failures, invalid
service links, empty station identifiers, or a station list with no stations. Cancellation is
`NWSError.transport(.cancelled)`, with a cancellation check before each HTTP call.

The unreleased coordinate overloads have been replaced:

- `latestObservation(latitude:longitude:)` becomes
  `latestObservation(from: .nearest(to: coordinate))`.
- `Endpoint.point(latitude:longitude:)` becomes `Endpoint.point(for: coordinate)`.
- Create the coordinate with `try WeatherCoordinate(latitude:longitude:)`.

## Example

[`Examples/SwiftNWSDemo`](Examples/SwiftNWSDemo) is a small iOS app that shows the latest observation
for an address, geocoded with MapKit because the API has no geocoding, or for the device's location.
It references this package by local path. Open `Examples/SwiftNWSDemo/SwiftNWSDemo.xcodeproj` with the
package itself closed in Xcode, since Xcode lets a local package be open in only one window.

## Products

| Product | What it is | Depends on |
|---|---|---|
| `SwiftNWSModels` | `WeatherCoordinate`, `ObservationSource`, `WeatherRequest`, `Endpoint`, and portable response models: `Point`, `ObservationStation`, `WeatherObservation`, `QuantitativeValue`, `ProblemDetail`, and the GeoJSON `Feature` and `FeatureCollection` wrappers. Usable on any data layer. | Nothing. |
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

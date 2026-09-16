# Using reusable requests

Store a weather lookup, add application vocabulary, or execute a custom endpoint.

## Overview

Constructing a request performs no I/O. The response is inferred from its factory:

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(myweatherapp.com, contact@myweatherapp.com)")
let request = WeatherRequest.latestObservation(from: .station("KATT"))
let observation = try await weather.value(for: request)
```

The equivalent everyday call is `weather.latestObservation(from: .station("KATT"))`.
Both calls share link checks, request sequencing, headers, cancellation, decoding, and errors.

Single-response conveniences delegate through `value(for:)`, whose executor sends endpoints through
`send(_:)`. Paginated conveniences instead delegate to request-based page and item sequence executors
so sequence creation remains lazy. See <doc:PaginatingCollections>.

Add a reusable name by extending the request for a concrete response:

```swift
extension WeatherRequest where Response == WeatherObservation {
  static var homeConditions: Self {
    .latestObservation(from: .station("KATT"))
  }
}

let observation = try await weather.value(for: .homeConditions)
```

## Define a single-HTTP request

Supply a typed endpoint to decode a consumer-defined response. This example reads just a station
identifier from an existing observation response:

```swift
struct StationIdentity: Decodable, Sendable {
  let stationId: String
}

let request = WeatherRequest(
  endpoint: Endpoint<Feature<StationIdentity>>(path: "/stations/KATT/observations/latest")
)
let result = try await weather.value(for: request)
print(result.properties.stationId)
```

For an additional NWS endpoint, supply its path and a model matching its response. The SDK
sends the endpoint with its declared Accept media type and the configured User-Agent.
Custom multi-step workflows can be ordinary async functions that call the client.

## Inspect results and failures

Everyday observations retain station identity and timestamp, allowing your application to choose
a freshness policy. Measurements may be absent or contain a null value. WMO unit identifiers stay
open strings; enumerated quality codes use open `QualityControlCode` values.

For the existing GeoJSON envelope, use `send(Endpoint.latestObservation(stationIdentifier:))`
or wrap that endpoint in a request. The result retains `Feature.id` and `Feature.properties`;
geometry and other unmodeled metadata are not retained.

``NWSError`` distinguishes problem details, transport and decoding failures, invalid links,
invalid or excessive redirects, empty station or alert identifiers, and empty station lists. Cancellation is
`NWSError.transport(.cancelled)`; it is checked before each HTTP call. No new retry policy
is applied by the weather lookup.

## Migrate raw coordinates

Create a coordinate with `try WeatherCoordinate(latitude:longitude:)`, then call
`latestObservation(from: .nearest(to: coordinate))` or `Endpoint.point(for: coordinate)`.
The initializer validates ranges before rounding to four decimal places and throws
`WeatherCoordinate.ValidationError` for invalid input.

The old raw-coordinate overloads have been removed. Configuration-based client initializers,
direct endpoints, and `send(_:)` remain available.

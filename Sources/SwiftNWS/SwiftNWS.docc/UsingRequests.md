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

if let endpoint = Endpoint<Feature<StationIdentity>>(path: "/stations/KATT/observations/latest") {
  let request = WeatherRequest(endpoint: endpoint)
  let result = try await weather.value(for: request)
  print(result.properties.stationId)
}
```

For an additional NWS endpoint, supply its path and a model matching its response. The SDK
sends the endpoint with its declared Accept media type and the configured User-Agent.
Raw-path initializers are failable. Paths must start with one slash and may include an encoded
query. Absolute or authority URLs, fragments, raw whitespace and controls, malformed escapes,
backslashes, and dot path segments are rejected, including encoded path equivalents. Accepted paths
and queries retain their exact spelling; query values are not treated as path segments, and query
names such as `api_key` are allowed. `path` is immutable; `accept` and `featureFlags` remain configurable.

Custom multi-step workflows can be ordinary async functions that call the client.

## Inspect results and failures

Everyday observations retain station identity and timestamp, allowing your application to choose
a freshness policy. Measurements may be absent or contain a null value. WMO unit identifiers stay
open strings; enumerated quality codes use open `QualityControlCode` values.

For the existing GeoJSON envelope, unwrap `Endpoint.latestObservation(stationIdentifier:)`, then
pass the endpoint to `send(_:)` or wrap it in a request. The result retains `Feature.id` and `Feature.properties`;
geometry and other unmodeled metadata are not retained.

``NWSError`` distinguishes problem details, transport and decoding failures, invalid links,
invalid or excessive redirects, invalid station or alert identifiers and alert locations, and empty station lists. Cancellation is
`NWSError.transport(.cancelled)`; it is checked before each HTTP call. Each request is sent once
unless the client was created with a retry policy; see
<doc:UsingRequests#Retrying-transient-failures>.

## Retrying transient failures

The service documents a rate limit whose answer may be retried once it clears, typically within five
seconds, and its change log records `500` and `503` answers from forecast routes. A client sends
each request once by default. Pass `RetryPolicy.nwsTransientFailures` to send a request again
when the transport times out or the service answers `429`, `500`, `502`, `503`, or `504`:

```swift
let weather = NWSClient(
  configuration: NWSConfiguration(userAgent: "(myweatherapp.com, contact@myweatherapp.com)"),
  retryPolicy: .nwsTransientFailures
)
```

The policy makes at most three attempts, waiting one second and then five. A numeric `Retry-After`
on the failed response replaces the scheduled wait. The waits run on the client's `clock`, which
defaults to a continuous clock; inject another to control time in tests. The point cache keeps its
own clock.

The budget covers one HTTP request. Each step of a multi-request lookup, each redirect hop, and each
page of a sequence has its own, so a request that follows the maximum of five redirects can send up
to eighteen requests. Other `4xx` answers, decoding failures, and cancellation are never retried, and
cancellation during a wait ends the call with `NWSError.transport(.cancelled)` without sending again.
When the last attempt fails, the error is what it would have been without retrying:
``NWSError/problem(_:)`` for a problem-details body, otherwise ``NWSError/transport(_:)``.

There is no per-request policy. To send some requests with a different policy, create a second
client on the same transport; the client is a value, so this is cheap. Any `RetryPolicy` works,
including one you build from swifty-networking's `BackoffSchedule` and a predicate of your own.

## HTTP caching

The service sends `Cache-Control` with a `max-age` from five seconds to a day, and weak ETags. The
SDK performs no HTTP caching of its own beyond ``PointCache``: it sends no conditional requests and
does not read those headers. On Apple platforms, the `URLSession` you pass applies its own
`URLCache` and request cache policy to them; the shared session uses the shared cache and the
protocol's default policy. The portable AsyncHTTPClient transport has no cache. To cache responses
off Apple platforms, add caching at the transport.

## Migrate raw coordinates

Create a coordinate with `try WeatherCoordinate(latitude:longitude:)`, then call
`latestObservation(from: .nearest(to: coordinate))` or `Endpoint.point(for: coordinate)`.
The initializer validates ranges before rounding to four decimal places and throws
`WeatherCoordinate.ValidationError` for invalid input.

The old raw-coordinate overloads have been removed. Configuration-based client initializers,
direct endpoints, and `send(_:)` remain available.

# Executing requests with your own networking stack

Interpret endpoints and weather lookups without depending on the SDK.

## Overview

An ``Endpoint`` describes one HTTP GET operation:

```swift
import SwiftNWSModels

let location = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
let endpoint = Endpoint.point(for: location)
print(endpoint.path)            // /points/30.2672,-97.7431
print(endpoint.accept.rawValue) // application/geo+json
```

Send a GET to `https://api.weather.gov` plus the endpoint's path, set the Accept header to
its media type, and provide a User-Agent identifying your application and a contact.
Decode the successful response as `Feature<Point>` for this endpoint. Your networking stack
owns status handling, cancellation, and decoding.

Use `Endpoint(accept:link:)` for links returned by the API. It accepts only HTTPS on
`api.weather.gov`, with no credentials or fragment and either no explicit port or port 443.
It retains the encoded path and query. A disallowed link returns nil and must not be followed.
The path-based initializer is a low-level escape hatch; callers supply the path and response
type that match their intended operation.

## Interpret a weather request

``WeatherRequest/resolution`` exposes a read-only description.
Constructing or inspecting it sends nothing.

- An endpoint resolution contains `Endpoint<Response>`. Decode the complete body as
  `Response`, without adding or removing a GeoJSON wrapper.
- A latest-observation resolution contains ``ObservationSource`` and is only created for
  ``WeatherObservation`` responses. For an explicit station, reject an empty identifier,
  send `Endpoint.latestObservation(stationIdentifier:)`, and return the feature's properties.
- For a coordinate source, send `Endpoint.point(for:)`, then validate and follow
  `point.properties.observationStations` using `Endpoint.observationStations(near:)`.
  Select the first station from the returned page; an empty list is an error. Retrieve its
  latest observation as above. Preserve the observation's station ID and timestamp.

The coordinate lookup uses service ordering rather than calculating distance. Do not assume
the first listed station is geographically closest. To match the SDK, do not add freshness
filtering, fallback stations, or automatic pagination, and check cancellation before
each HTTP call.

## Extend the vocabulary

Constrained extensions can return existing request factories. A custom single-HTTP operation can
use `WeatherRequest(endpoint:)` with a consumer-defined response type. There is no public
initializer for assigning arbitrary built-in resolutions to unrelated response types.
Custom multi-step workflows remain the consumer's own functions.

The existing GeoJSON models retain `Feature.id`, `Feature.properties`, and the collection's
features. They do not preserve arbitrary metadata or geometry. Unknown unit and quality codes
remain strings; null measurements remain nil.

## Point cache policy

The SDK remembers up to 128 point mappings for 24 hours with least-recently-used eviction.
Expiry uses a monotonic clock. Client copies share the cache, which callers can clear or disable.
Only successful coordinate resolutions populate it; direct endpoint requests bypass it.
This is SDK policy rather than part of request construction. A custom executor chooses its own
cache policy. Forecast and observation responses are not cached by the point cache.

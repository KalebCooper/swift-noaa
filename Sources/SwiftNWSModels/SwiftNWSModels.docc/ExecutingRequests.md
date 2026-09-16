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
its media type, and provide a User-Agent identifying your application and a contact. When
`endpoint.featureFlags` is nonempty, join each value's `rawValue` with commas for the
Feature-Flags header.
Decode the successful response as `Feature<Point>` for this endpoint. Your networking stack
owns status handling, cancellation, and decoding.

Use `Endpoint(accept:featureFlags:link:)` for links returned by the API. It accepts only HTTPS on
`api.weather.gov`, with no credentials or fragment and either no explicit port or port 443.
It retains the encoded path and query. A disallowed link returns nil and must not be followed.
The path-based initializer is a low-level escape hatch; callers supply the path and response
type that match their intended operation.

## Interpret a weather request

``WeatherRequest/resolution`` exposes a read-only description.
Constructing or inspecting it sends nothing.

- An endpoint resolution contains `Endpoint<Response>`. Decode the complete body as
  `Response`, without adding or removing a GeoJSON wrapper.
- Forecast resolutions contain a coordinate and options. Resolve the point, validate its forecast
  or hourly link using the corresponding endpoint factory, then return the feature's properties.
  Preserve the endpoint's units query and feature flags.
- An alert resolution contains an identifier. Reject an empty identifier, send `Endpoint.alert(identifier:)`,
  and return the feature's properties. Active-alert factories use an endpoint resolution and retain
  the returned collection. Follow canonical redirects only after validating their origin.
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

## Traverse station-directory pages

```swift
let query = try ObservationStationQuery(limit: 100, states: [.texas])
let request = WeatherRequest.observationStations(query: query)
let endpoint = Endpoint.observationStations(query: query)

// After your networking stack decodes a FeatureCollection<ObservationStation>:
if let pagination = page.pagination {
  let next = try pagination.nextEndpoint(after: endpoint)
  print(next.path)
}
```

The station-query resolution supports one-page execution and opt-in continuation. A custom endpoint
resolution remains one HTTP operation. Queries validate limits from 1 through 500 and preserve an
initial cursor. Empty identifier and state arrays omit their filters.

``PaginationInfo/nextEndpoint(after:)`` preserves encoded continuation paths, queries, Accept, and
Feature-Flags. It throws ``NWSPaginationError`` for missing or disallowed next links; absent collection
pagination is terminal. Empty pages can still continue. An executor matching the SDK also detects
repeated and cyclic endpoint paths before yielding their page, checks cancellation on every read,
and ends its iterator after any failure. Do not reconstruct later links from the original query.

## Extend the vocabulary

Constrained extensions can return existing request factories. A custom single-HTTP operation can
use `WeatherRequest(endpoint:)` with a consumer-defined response type. There is no public
initializer for assigning arbitrary built-in resolutions to unrelated response types.
Custom multi-step workflows remain the consumer's own functions. Area factories at the endpoint,
request, and client levels accept either `AreaCode` or a consumer-defined String-backed enum.

The existing GeoJSON models retain `Feature.id`, `Feature.properties`, and the collection's
features. They do not preserve arbitrary metadata or geometry. WMO unit identifiers remain
strings. Enumerated forecast and quality codes use open values whose `rawValue` preserves unknown
provider values; null measurements remain nil.

## Point cache policy

The SDK remembers up to 128 point mappings for 24 hours with least-recently-used eviction.
Expiry uses a monotonic clock. Client copies share the cache, which callers can clear or disable.
Only successful coordinate resolutions populate it; direct endpoint requests bypass it.
This is SDK policy rather than part of request construction. A custom executor chooses its own
cache policy. Forecast and observation responses are not cached by the point cache.

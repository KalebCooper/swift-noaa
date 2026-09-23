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
Decode the successful response as `Feature<WeatherPoint>` for this endpoint. Your networking stack
owns status handling, cancellation, and decoding.

`/points/{latitude},{longitude}/radio` is not supported. It answers only `application/ssml+xml`,
a speech synthesis document, and this package decodes typed JSON with no portable XML path. The
point's `nwr` object is not decoded, and the radio routes (`/radio`, `/radio/{callSign}`,
`/radio/{callSign}/broadcast`, and `/zones/county/{zoneId}/radio`) are out of scope. The CAP XML
representation of one alert (`application/cap+xml` at `/alerts/{id}`) and the Atom representation
of the alert lists (`application/atom+xml` at `/alerts`, `/alerts/active`, and the active zone,
area, and region routes) are not supported. Every alert endpoint asks for `application/geo+json`,
except the count and types routes, which ask for `application/ld+json`. The JSON representation
carries the same CAP fields, and `WeatherAlert` decodes them. A consumer who needs the CAP or Atom
document sends the endpoint's `path` with its own transport and `Accept` header; the Atom feed
carries its own `.atom` continuation link, which this package does not follow.

Use `Endpoint(accept:featureFlags:link:)` for links returned by the API. It accepts only HTTPS on
`api.weather.gov`, with no credentials or fragment and either no explicit port or port 443.
It retains the encoded path and query. A disallowed link returns nil and must not be followed.
Raw-path initializers are failable. Paths must start with one slash and may include an encoded
query. Absolute or authority URLs, fragments, raw whitespace and controls, malformed escapes,
backslashes, and dot path segments are rejected, including encoded path equivalents. Accepted paths
and queries retain their exact spelling; query values are not treated as path segments, and query
names such as `api_key` are allowed. `path` is immutable; `accept` and `featureFlags` remain configurable.

```swift
if let endpoint = Endpoint<Feature<ObservationStation>>(path: "/stations/KATT") {
  print(endpoint.path)
  let request = WeatherRequest(endpoint: endpoint)
}
```

Named factories taking station or alert identifiers, areas, regions, or zones also return nil when
the resulting path is invalid or the identifier is empty. The active-alert area, region, and zone
request factories are failable for the same reason. Check the optional before execution. Other
identifier request factories defer validation to execution; unwrap their endpoint factory and report
failure before sending. The zone directory, detail, forecast, and forecast-zone station request
factories work that way: they always return a request, and executing it reports an unusable type or
identifier. `Endpoint.zones(matching:types:)` is not failable, because its path carries no type
segment, and `Endpoint.observations(inForecastZone:)` is not failable because its query validated
the zone identifier. Observation and zone-observation queries validate their station and zone paths
during construction.

Validate a redirect's original encoded path before resolving a relative URL, because resolution
can remove dot segments. Then apply the same endpoint origin and path checks to the resolved URL.

## Interpret a weather request

``WeatherRequest/resolution`` exposes a read-only description.
Constructing or inspecting it sends nothing.

- An endpoint resolution contains `Endpoint<Response>`. Decode the complete body as
  `Response`, without adding or removing a GeoJSON wrapper. `WeatherRequest.activeAlertCount`,
  `WeatherRequest.alertTypes`, `WeatherRequest.glossary`, `WeatherRequest.productLocations`,
  `WeatherRequest.products(matching:)`, and
  `WeatherRequest.productTypes` use this resolution with endpoints that
  ask for ``MediaType/jsonLD``, and `WeatherRequest.observations(inForecastZone:)` uses it with an
  endpoint whose ``ZoneObservationQuery`` already validated the zone and limit.
  `Endpoint.products(matching:)` is not failable because its ``ProductQuery`` validated its own
  limit, so send its path as written, including the comma-separated filter values. The two product
  catalogs that take no argument are plain endpoint properties, so their requests add no resolution
  case of their own.
- Forecast resolutions contain a coordinate and options. Resolve the point, validate its forecast
  or hourly link using the corresponding endpoint factory, then return the feature's properties.
  Preserve the endpoint's units query and feature flags.
- A `forecastGrid` resolution contains a coordinate and is only created for ``ForecastGrid``
  responses. Resolve the point, validate its grid data link with `Endpoint.forecastGrid(for:)`,
  send it without a units query or feature flags, and return the feature's properties. A disallowed
  link is a failure; do not rebuild the path.
- An alert resolution contains an identifier. Unwrap the endpoint factory, reject invalid identifiers, send `Endpoint.alert(identifier:)`,
  and return the feature's properties.
- Active-alert factories use an `activeAlerts` resolution containing the typed initial endpoint.
  One-page execution retains the returned collection. Sequence execution follows validated pagination
  links. Follow canonical redirects only after validating their origin.
- An `alerts` resolution contains an ``AlertQuery``. Send `Endpoint.alerts(matching:)` for one page,
  and apply the same continuation and redirect rules as active alerts for a sequence.
- An `observations` resolution contains an ``ObservationQuery``. Send
  `Endpoint.observations(matching:)` for one page, decode `FeatureCollection<WeatherObservation>`,
  and apply the continuation rules below for a sequence.
- A latest-observation resolution contains ``ObservationSource`` and is only created for
  ``WeatherObservation`` responses. For an explicit station, reject invalid identifiers,
  unwrap and send `Endpoint.latestObservation(stationIdentifier:)`, and return the feature's properties.
- An `observation` resolution contains a station identifier and a timestamp and is only created for
  ``WeatherObservation`` responses. Unwrap the endpoint factory, reject invalid identifiers, send
  `Endpoint.observation(stationIdentifier:timestamp:)`, and return the feature's properties. The
  service answers an instant that matches no observation with `404` problem details; do not substitute
  the nearest observation.
- An `observationStation` resolution contains a station identifier and is only created for
  ``ObservationStation`` responses. Unwrap the endpoint factory, reject invalid identifiers, send
  `Endpoint.observationStation(identifier:)`, and return the feature's properties.
- An `office` resolution contains an office identifier and is only created for ``WeatherOffice``
  responses. It exists so an empty or unusable identifier is rejected before any request: unwrap
  `Endpoint.office(identifier:)`, report a nil result as an unusable office identifier, send it, and
  decode the whole JSON-LD body as ``WeatherOffice``. There is no GeoJSON wrapper to unwrap, and
  none of the office's links is followed.
- An `officeBriefing` resolution contains an office identifier and is only created for optional
  ``OfficeBriefing`` responses. Unwrap `Endpoint.officeBriefing(officeIdentifier:)`, report a nil
  result as an unusable office identifier before sending, send it once, decode the body as
  ``OfficeBriefingResponse``, and return its ``OfficeBriefingResponse/briefing``. A `null` briefing
  is nil, an answer rather than a failure: do not retry or fall back to another route. A `404` for
  an unknown office stays a failure. Do not request the briefing's ``OfficeBriefing/download``.
- An `officeHeadline` resolution contains a headline identifier and an office identifier and is
  only created for ``OfficeHeadline`` responses. Check the office identifier first, so the failure
  names which argument was unusable, then unwrap `Endpoint.officeHeadline(identifier:officeIdentifier:)`,
  report a nil result as an unusable headline identifier, send it, and decode the whole body. Do not
  request the headline's editorial ``OfficeHeadline/link``.
- An `officeHeadlines` resolution contains an office identifier and is only created for
  ``OfficeHeadlines`` responses. Unwrap `Endpoint.officeHeadlines(officeIdentifier:)`, reject an
  empty or unusable identifier before sending, and return that one response. The route documents no
  page size or cursor, so send neither and synthesize no continuation.
- A `latestProduct` resolution contains a location identifier and a ``ProductCode`` and is only
  created for ``TextProduct`` responses. Check the code first, so the failure names which argument
  was unusable, then unwrap `Endpoint.latestProduct(at:ofType:)`, report a nil result as an
  unusable product location before sending, and decode the whole JSON-LD body. This is one request:
  the service selects the product, so do not list products, sort them, or fetch a detail after a
  first entry.
- A `product` resolution contains a product identifier and is only created for ``TextProduct``
  responses. Unwrap `Endpoint.product(identifier:)`, report a nil result as an unusable product
  identifier before sending, send it once, and decode the whole JSON-LD body. Keep
  ``TextProduct/productText`` exactly as sent, with no trimming, normalization, or re-encoding.
- A `productLocations` resolution contains a ``ProductCode`` and is only created for
  ``ProductLocations`` responses. Unwrap `Endpoint.productLocations(for:)`, report a nil result as
  an unusable product code before sending, send it once, and decode the whole JSON-LD body. The
  code is encoded as one path segment and is not upper-cased or otherwise normalized, and a code
  the service does not catalog is sent rather than rejected. The route documents no page size or
  cursor, so send neither and synthesize no continuation. Keep every location the service listed
  without a description.
- A `productsOfType` resolution contains a ``ProductCode`` and an optional location identifier and
  is only created for ``TextProducts`` responses. A nil location selects
  `Endpoint.products(ofType:)` and a location selects `Endpoint.products(at:ofType:)`, which is a
  bounded choice inside one operation rather than dispatch over arbitrary resources. Check the code
  first, report a nil endpoint as an unusable code or location before sending, and decode the whole
  JSON-LD body, keeping the order the service listed the products in. Neither route accepts query
  options, so send none, and never rewrite either as a `/products` query: their filters and
  retention can differ. Every entry's ``TextProduct/productText`` is nil, which is the shape of a
  list; do not substitute an empty string or fetch a detail to fill it in.
- A `productTypes` resolution contains a location identifier and is only created for
  ``ProductTypes`` responses. Unwrap `Endpoint.productTypes(at:)`, report a nil result as an
  unusable product location before sending, send it once, and decode the whole JSON-LD body,
  keeping the order the service listed the types in. The identifier is encoded as one path segment
  and is not upper-cased or otherwise normalized. The route documents no page size or cursor, so
  send neither and synthesize no continuation.
- A `nearbyObservationStations` resolution contains a coordinate and is only created for
  `FeatureCollection<ObservationStation>` responses. Resolve the point, validate its
  observation-stations link with `Endpoint.observationStations(near:)`, and return that one page.
  Do not follow its `pagination.next`, in one-page or sequence execution: for this list the link
  names every station for the grid again at a later offset and leads only to empty pages.
- A `forecastZoneStations` resolution contains a forecast zone identifier and is only created for
  `FeatureCollection<ObservationStation>` responses. Unwrap
  `Endpoint.observationStations(inForecastZone:)`, reject an empty or unusable identifier, and
  return that one page. Do not follow its `pagination.next`, in one-page or sequence execution: the
  link names the zone's stations again at a later offset and leads only to empty pages. The route's
  declared limit and cursor had no effect on the recorded responses, so this resolution sends
  neither.
- A `zone` resolution contains an identifier, a ``ZoneType``, and an optional effective instant, and
  is only created for ``WeatherZone`` responses. Reject an empty or unusable type before the
  identifier, so the failure names which argument was unusable, then send
  `Endpoint.zone(identifier:type:effective:)` and return the feature's properties. The feature's
  geometry is reachable only through the endpoint, not through this resolution's result.
- A `zoneForecast` resolution contains an identifier and a ``ZoneType``, and is only created for
  ``ZoneForecast`` responses. Reject an empty or unusable type before the identifier, as the `zone`
  resolution does, then send `Endpoint.zoneForecast(identifier:type:)` and return the feature's
  properties. The route takes no units query and no feature flags, and the feature's geometry is
  reachable only through the endpoint.
- A `zonesOfType` resolution contains a ``ZoneQuery`` and a ``ZoneType``, and is only created for
  `FeatureCollection<WeatherZone>` responses. Reject an empty or unusable type, send
  `Endpoint.zones(matching:ofType:)`, and return that one response. The root directory uses an
  endpoint resolution instead, because its path needs no type. Neither directory declares a cursor,
  and neither recorded response carries a continuation, so do not synthesize one.
- For a coordinate source, send `Endpoint.point(for:)`, then validate and follow
  `point.properties.observationStations` using `Endpoint.observationStations(near:)`.
  Select the first station from the returned page; an empty list is an error. Retrieve its
  latest observation as above. Preserve the observation's station ID and timestamp.

The coordinate lookup uses service ordering rather than calculating distance. Do not assume
the first listed station is geographically closest. To match the SDK, do not add freshness
filtering, fallback stations, or automatic pagination, and check cancellation before
each HTTP call.

## Traverse collection pages

```swift
let query = try ObservationStationQuery(limit: 100, states: [.texas])
let request = WeatherRequest.observationStations(matching: query)
let endpoint = Endpoint.observationStations(matching: query)

// After your networking stack decodes a FeatureCollection<ObservationStation>:
if let pagination = page.pagination {
  let next = try pagination.nextEndpoint(after: endpoint)
  print(next.path)
}
```

The station-query, active-alert, alert-history, and observation-history resolutions support
one-page execution and opt-in continuation. The nearby-station and forecast-zone-station resolutions
are always one page. A custom endpoint resolution remains one HTTP operation, which is what a
forecast zone's observations use.
Queries validate limits from 1 through 500 and preserve an initial cursor; an observation query
omits the limit when none is given and rejects an empty station identifier or invalid encoded path. Empty identifier and
state arrays omit their filters, and window bounds are sent as whole-second ISO 8601 instants.

For active alerts, `WeatherRequest.activeAlerts(matching:)`, coordinate, area, marine region, and zone factories
retain their existing initial endpoints inside the `activeAlerts` resolution. Decode each response as
`FeatureCollection<WeatherAlert>` and apply the same continuation validation below. A custom
`WeatherRequest(endpoint:)` never opts into continuation, even if pagination metadata is present.

``PaginationInfo/nextEndpoint(after:)`` preserves encoded continuation paths, queries, Accept, and
Feature-Flags. It throws ``NWSPaginationError`` for missing or disallowed next links; absent collection
pagination is terminal. Empty pages can still continue. An executor matching the SDK also detects
repeated and cyclic endpoint paths before yielding their page, checks cancellation on every read,
and ends its iterator after any failure. Earlier values are partial results, not a complete result
set. Do not reconstruct later links from the original query, deduplicate values, or assume the
provider returns a stable snapshot.

## Extend the vocabulary

Constrained extensions can return existing request factories. A custom single-HTTP operation can
use `WeatherRequest(endpoint:)` with a consumer-defined response type. There is no public
initializer for assigning arbitrary built-in resolutions to unrelated response types.
Custom multi-step workflows remain the consumer's own functions. Area factories at the endpoint,
request, and client levels accept either `AreaCode` or a consumer-defined String-backed enum.

The existing GeoJSON models retain `Feature.id`, `Feature.properties`, the collection's features,
and `Feature.geometry`, which keeps the provider's geometry as raw ``JSONValue`` when the service
sends one and is nil when it sends `null` or none. The package does not validate, interpret, or
compute over that geometry, and it does not preserve other arbitrary metadata. WMO unit identifiers
remain strings. Enumerated forecast and quality codes use open values whose `rawValue` preserves unknown
provider values; null measurements remain nil.

## Point cache policy

The SDK remembers up to 128 point mappings for 24 hours with least-recently-used eviction.
Expiry uses a monotonic clock. Client copies share the cache, which callers can clear or disable.
Only successful coordinate resolutions populate it; direct endpoint requests bypass it.
This is SDK policy rather than part of request construction. A custom executor chooses its own
cache policy. Forecast, grid, and observation responses are not cached by the point cache.

## Transient failures and HTTP caching

Every endpoint is a `GET`, so an executor can send one again safely. The service documents a rate
limit whose answer may be retried once it clears, typically within five seconds, and its change log
records `500` and `503` answers from forecast routes. The SDK retries only when its client is created
with a retry policy: its package policy covers timeouts and `429`, `500`, `502`, `503`, and `504`,
with at most three attempts per HTTP request. A custom executor chooses its own retry policy.

The service sends `Cache-Control` with a `max-age` from five seconds to a day, and weak ETags. The SDK
does not read them and sends no conditional requests; any HTTP caching belongs to the transport.

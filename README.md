# swift-noaa

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Swift integrations for NOAA services, starting with the National Weather Service.

The package currently provides `Codable` models and endpoint descriptions for the
[National Weather Service API](https://www.weather.gov/documentation/services-web-API) that you can
send through any networking stack, plus an SDK that sends them for you through
[swifty-networking](https://github.com/KalebCooper/swifty-networking).

## Status

The 0.1.0 release candidate implements current observations, twelve-hour and hourly forecasts,
point caching, active alerts by coordinate, area, marine region, zone, and CAP filters, active alert
counts, the recognized alert event types, alert history with a time
window, a station's observation history, and lazy station-directory, active-alert, alert-history,
and observation-history pagination. WMO readings can be converted with Foundation. The release is
not tagged yet.

Raw grid data, general zone and office endpoints, and retries are outside this release.

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
`NWSClient(configuration:pointCache:session:)` and `NWSClient(configuration:pointCache:transport:)` initializers remain
available for custom sessions and transports.

Coordinates reject nonfinite values and values outside latitude -90...90 and longitude -180...180,
then round to four decimal places. The initializer throws `WeatherCoordinate.ValidationError`.

`.nearest(to:)` follows the point's station-list link and uses the first station on the returned
page. This preserves the service's ordering; it does not calculate distances, and the API does not
guarantee that the first station is geographically closest. An uncached lookup takes three HTTP requests.
It does not filter stale observations, try a fallback station, or fetch additional pages.
Use the result's `stationId` and `timestamp` to assess its source and freshness.

### Forecasts

```swift
let forecast = try await weather.forecast(for: home)
let hourly = try await weather.hourlyForecast(
  for: home,
  options: .init(featureFlags: [.temperatureQuantity, .windSpeedQuantity], units: .si)
)
let request = WeatherRequest.forecast(for: home)

// Your app's String-backed enums work without a conversion layer.
enum AppUnits: String { case metric = "si" }
let appOptions = ForecastOptions(units: AppUnits.metric)
```

Both methods follow the point's service links. `WeatherForecast` retains periods in service order,
ISO 8601 dates, and the original validity interval. Temperature and wind retain either their legacy
values or quantitative objects, including ranges and missing measurements. No conversion or period
filtering is implicit. Direct `Endpoint.forecast(for:options:)` and
`Endpoint.hourlyForecast(for:options:)` factories accept a decoded point. Forecast units,
feature flags, temperature units and trends, wind directions, and measurement quality flags are
typed open values: known schema codes have named static members, while `rawValue` retains additions.

### Active alerts

```swift
let alerts = try await weather.activeAlerts(for: home)
let texas = try await weather.activeAlerts(inArea: .texas)
let filtered = try await weather.value(
  for: .activeAlerts(matching: .init(location: .zones(["TXZ192"]), severity: [.severe]))
)
if let identifier = alerts.features.first?.properties.id {
  let alert = try await weather.alert(identifier: identifier)
  print(alert.headline ?? alert.event, alert.instruction ?? "")
}
```

Awaited active queries return one `FeatureCollection<WeatherAlert>`; single-alert methods unwrap
`WeatherAlert`. Follow pages or features explicitly when needed:

```swift
let filter = ActiveAlertFilter(location: .areas([.texas]), severity: [.severe])
let firstPage = try await weather.activeAlerts(matching: filter)
for try await alert in weather.activeAlerts(matching: filter) {
  print(alert.id as Any, alert.properties.headline ?? alert.properties.event)
  break
}
for try await page in weather.activeAlertPages(for: .activeAlerts(inZone: "TXZ192")) {
  print(page.features.count)
  break
}
```

`ActiveAlertPageSequence` returns whole collections; `ActiveAlertSequence` returns
`Feature<WeatherAlert>` values. Both are lazy, independently iterable, and do not prefetch. An empty
page can continue. Missing, invalid, or repeated continuation links throw `NWSError.pagination`
before yielding their page, and any failure ends that iterator. Values already yielded are partial
results, not a complete result set. Stop when you have enough; the service does not guarantee finite
traversal or a stable snapshot, and the client does not deduplicate values. Custom
`WeatherRequest(endpoint:)` requests remain one page even when their response contains pagination
metadata.

Filters cover the live spec, with one geographic choice preventing incompatible combinations.
`AreaCode`, `MarineRegionCode`, and CAP fields expose known values without rejecting future
`rawValue`s. Zone identifiers, event names, and event codes remain open strings.

A String-backed app enum works directly at all three access levels:

```swift
enum AppArea: String { case home = "TX" }
let everyday = try await weather.activeAlerts(inArea: AppArea.home)
let reusable = WeatherRequest.activeAlerts(inArea: AppArea.home)
let endpoint = Endpoint<FeatureCollection<WeatherAlert>>.activeAlerts(inArea: AppArea.home)
```

Marine regions have their own path, and a String-backed region enum works the same way:

```swift
let gulf = try await weather.activeAlerts(inRegion: .gulfOfMexico)
for try await page in weather.activeAlertPages(for: .activeAlerts(inRegion: .atlantic)) {
  print(page.features.count)
}
```

`activeAlertCount()` returns `ActiveAlertCount`: the total, land and marine counts, and breakdowns
keyed by `AreaCode`, `MarineRegionCode`, and zone identifier. The breakdowns overlap, since one
alert counts once in every area and zone it affects, and list only codes with an active alert.
`alertTypes()` returns the event names the service recognizes, in service order, for use in the
`event` filter:

```swift
let count = try await weather.activeAlertCount()
print(count.total, count.areas[.texas] ?? 0, count.regions[.gulfOfMexico] ?? 0)
let types = try await weather.alertTypes()
print(types.eventTypes.contains("Heat Advisory"))
```

Both are one request each, with matching `WeatherRequest.activeAlertCount` and
`WeatherRequest.alertTypes` values and `Endpoint.activeAlertCount` and `Endpoint.alertTypes`
endpoints. The service offers them only as JSON-LD, so those endpoints ask for `MediaType.jsonLD`.
Alert collections are GeoJSON only; awaited lists are not automatically paginated.
The client follows at most five redirects within the HTTPS API origin and rejects loops and unsafe links.

### Alert history

```swift
let query = try AlertQuery(
  end: end, filter: .init(location: .areas([.texas]), status: [.actual]), limit: 100,
  start: start)
let firstPage = try await weather.alerts(matching: query)
for try await alert in weather.alerts(matching: query) {
  print(alert.properties.sent, alert.properties.event)
  break
}
for try await page in weather.alertPages(for: .alerts(matching: query)) {
  print(page.features.count)
  break
}
```

`AlertQuery` combines an `ActiveAlertFilter` with an optional `start` and `end`, a page size from 1
through 500, and an optional initial cursor. Window bounds are sent as whole-second ISO 8601 instants
in UTC; the service decides which alerts a window matches and how it orders them, and an absent bound
is left open. `AlertPageSequence` and `AlertSequence` follow the same lazy, single-traversal contract
as the active-alert sequences, and either alert executor accepts both active-alert and alert-history
requests. `Endpoint.alerts(matching:)` describes one page for another networking stack.

### Observation stations

```swift
let query = try ObservationStationQuery(limit: 100, states: [.texas])
let request = WeatherRequest.observationStations(query: query)

// Read a single page at either access level.
let page = try await weather.value(for: request)
let direct = try await weather.send(.observationStations(query: query))

// Or follow pages on demand, retaining each station's GeoJSON metadata.
for try await station in weather.observationStations(query: query) {
  print(station.id as Any, station.properties.stationIdentifier)
  break
}
for try await page in weather.observationStationPages(for: request) {
  print(page.features.count)
  break
}
```

Queries accept an initial opaque cursor, station identifiers, a limit from 1 through 500 (default 500),
and state or territory codes. Empty arrays omit filters. Page and item sequences perform no I/O until
read, do not prefetch, and start independently for each iterator. Items are
`Feature<ObservationStation>`; pages are `FeatureCollection<ObservationStation>`.

The station directory is the package's canonical page and item implementation. Continuation links
retain the service's exact encoded path and query. Missing or invalid next values, and repeated or
cyclic links, throw `NWSError.pagination` before that page is yielded. Any error ends the iterator;
values already yielded are partial results, and cancellation is checked even while items are
buffered. An empty page with a next link continues. The service does not guarantee finite traversal
or a stable snapshot, and the client does not deduplicate values, so stop when you have enough.

`observationStationPages(for:)` and `observationStations(for:)` follow links only for the library's
station-query resolution. A custom `WeatherRequest(endpoint:)` remains one page. Single-page
`value(for:)`, direct `send`, and nearest-observation lookups retain their existing scope.

### Point caching

Coordinate forecasts and observations share a `PointCache`: up to 128 mappings for 24 hours, with
least-recently-used eviction and monotonic expiry. Client copies share it. Forecast and observation
responses are fetched each time; direct `send` calls bypass the point cache. Concurrent misses may
make independent requests.

```swift
weather.pointCache?.removeAll()
let uncached = NWSClient(configuration: .init(userAgent: "(example.com, contact@example.com)"), pointCache: nil)
let cache = PointCache(capacity: 64, lifetime: .seconds(3_600))
```

A custom `Clock` can be injected into `PointCache` for deterministic expiry. Clearing prevents earlier
in-flight point lookups from repopulating the cache. Failures and cancelled lookups are not stored.

### WMO units

Import `SwiftNWS` to convert the WMO codes found in the recorded responses using Foundation:

```swift
let fahrenheit = observation.temperature?.measurement(in: UnitTemperature.fahrenheit)
let milesPerHour = observation.windSpeed?.measurement(in: UnitSpeed.milesPerHour)
let humidityFraction = observation.relativeHumidity?.fraction
// On Apple platforms:
let temperatureText = fahrenheit?.formatted(.measurement(width: .abbreviated, usage: .asProvided))
```

The adapter covers temperature, speed, pressure, length, and angle readings. Percentages become
fractions for `.percent` formatting. Unknown units, incompatible dimensions, and null values return
nil. No conversion occurs during decoding, and range bounds and quality codes remain on the original
quantity. `SwiftNWSModels` remains independent of full Foundation; the optional SDK adapter uses
Foundation's conversion facilities on all supported platforms.

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

### Observation history

```swift
let query = try ObservationQuery(limit: 24, start: start, stationIdentifier: "KATT")
let firstPage = try await weather.observations(query: query)
for try await observation in weather.observations(query: query) {
  print(observation.properties.timestamp, observation.properties.temperature?.value ?? .nan)
  break
}
for try await page in weather.observationPages(for: .observations(query: query)) {
  print(page.features.count)
  break
}
```

`ObservationQuery` names a station, an optional `start` and `end`, an optional page size from 1
through 500, and an optional initial cursor. A nil limit omits the parameter so the service applies
its own page size, and an empty station identifier is rejected at construction. The service decides
which observations a window matches and how it orders them; recorded responses list the newest
first, but that is not a documented guarantee. `ObservationPageSequence` and `ObservationSequence`
follow the same lazy, single-traversal contract as the station sequences, and each feature's
properties are the same `WeatherObservation` that `latestObservation(from:)` returns.
`Endpoint.observations(query:)` describes one page for another networking stack.

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
your own `User-Agent`, set `Feature-Flags` from `endpoint.featureFlags.map(\.rawValue)` when nonempty, and decode the body
as the endpoint's response type. Use
`Endpoint(accept:featureFlags:link:)` to validate service-provided links before following them.

`WeatherRequest.resolution` is also public and transport-independent: `.endpoint` describes one
HTTP call; `.latestObservation` describes an `ObservationSource`; forecast cases describe a coordinate
and options; `.alert` describes an identifier. `.activeAlerts` contains its initial typed endpoint,
`.alerts` contains an alert-history query, `.observationStations` contains a station query, and
`.observations` contains an observation-history query; all four support opt-in sequence traversal. A custom executor can interpret the source using the lookup
rules above. Requests contain no SDK or transport closures.

Direct endpoints preserve the existing GeoJSON wrappers, including `Feature.id` and
`Feature.properties`. Everyday observation methods return `WeatherObservation` directly.
Measurements can be absent or have a null value. WMO unit identifiers remain strings; enumerated
quality codes are typed open values that preserve unknown `rawValue`s.

### Errors and migration

The client throws `NWSError`: NWS problem details, transport or decoding failures, invalid
service links or redirects, excess redirect hops, invalid pagination, empty station or alert identifiers,
or a station list with no stations. Cancellation is
`NWSError.transport(.cancelled)`, with a cancellation check before each HTTP call.

The unreleased coordinate overloads have been replaced:

- `latestObservation(latitude:longitude:)` becomes
  `latestObservation(from: .nearest(to: coordinate))`.
- `Endpoint.point(latitude:longitude:)` becomes `Endpoint.point(for: coordinate)`.
- Create the coordinate with `try WeatherCoordinate(latitude:longitude:)`.

## Example

[`Examples/SwiftNWSDemo`](Examples/SwiftNWSDemo) is a small iOS app that shows the latest observation
forecasts, and active alerts
for an address, geocoded with MapKit because the API has no geocoding, or for the device's location.
It references this package by local path. Open `Examples/SwiftNWSDemo/SwiftNWSDemo.xcodeproj` with the
package itself closed in Xcode, since Xcode lets a local package be open in only one window.

## Products

| Product | What it is | Depends on |
|---|---|---|
| `SwiftNWSModels` | `WeatherCoordinate`, `ObservationSource`, `AlertQuery`, `ObservationQuery`, `ObservationStationQuery`, `WeatherRequest`, `Endpoint`, and portable response models: `Point`, `ObservationStation`, `WeatherObservation`, `WeatherForecast`, `WeatherAlert`, `QuantitativeValue`, `ProblemDetail`, and the GeoJSON `Feature` and `FeatureCollection` wrappers. Usable on any data layer. | Nothing. |
| `SwiftNWS` | `NWSClient`, which sends endpoints and follows the links between responses, with `NWSConfiguration` and one typed error, `NWSError`. It re-exports swifty-networking's `HTTPCore`, so `Transport` and `TransportError` need no import of their own. | `SwiftNWSModels`, swifty-networking, swift-http-types. |

A consumer with its own networking stack adds only `SwiftNWSModels` and fetches no dependency at all.

## Requirements

- Swift 6.2 or later.
- iOS, macOS, tvOS, visionOS, and watchOS 26 or later, Linux, or Android.
- `SwiftNWS` depends on [swifty-networking](https://github.com/KalebCooper/swifty-networking) 1.1.0 or
  later and [swift-http-types](https://github.com/apple/swift-http-types) 1.6.0 or later. On Apple
  platforms it sends through `URLSession`. On Linux and Android, enable the off-by-default
  `HTTPPortable` trait, which pulls in AsyncHTTPClient and SwiftNIO, and pass swifty-networking's
  `AsyncHTTPClientTransport` to `NWSClient(configuration:pointCache:transport:)`; a consumer who leaves the trait
  off never fetches or builds either.

## Installation

```swift
.package(url: "https://github.com/KalebCooper/swift-noaa.git", branch: "main")
```

On Linux or Android, enable the trait on the dependency:

```swift
.package(url: "https://github.com/KalebCooper/swift-noaa.git", branch: "main",
         traits: ["HTTPPortable"])
```

Every change is recorded in [CHANGELOG.md](CHANGELOG.md).

## Documentation and verification

Both products have DocC catalogs. The [documentation site](https://kalebcooper.github.io/swift-noaa/documentation/)
is published from `main`; Swift Package Index is configured to build both products.
See [CONTRIBUTING.md](CONTRIBUTING.md) for the local checks and CI matrix.

## License

MIT. See [LICENSE](LICENSE).

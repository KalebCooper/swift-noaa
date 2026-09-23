# swift-noaa

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Swift integrations for NOAA services, starting with the National Weather Service.

`SwiftNWSModels` describes every supported
[National Weather Service API](https://www.weather.gov/documentation/services-web-API) request as a
plain value and decodes every response, so any networking stack can send them. `SwiftNWS` sends them
for you through [swifty-networking](https://github.com/KalebCooper/swifty-networking), following the
links between responses, paging collections on demand, and mapping failures into one typed error.
Both run on Apple platforms, Linux, and Android.

The full reference, with an article per feature, is the
[documentation site](https://kalebcooper.github.io/swift-noaa/documentation/).

## Status

The current release is 0.2.0. The public API may still change before 1.0.0; every change is
recorded in [CHANGELOG.md](CHANGELOG.md).

| Feature | Service routes | Client methods | Paged |
|---|---|---|---|
| Current conditions | `/points`, `/stations/{id}/observations/latest` | `latestObservation(from:)` | No |
| Forecasts | `/gridpoints/{wfo}/{x},{y}/forecast`, `/forecast/hourly` | `forecast(for:)`, `hourlyForecast(for:)` | No |
| Raw forecast grids | `/gridpoints/{wfo}/{x},{y}` | `forecastGrid(for:)` | No |
| Active alerts | `/alerts/active` and its area, region, and zone routes, `/alerts/{id}` | `activeAlerts(...)`, `alert(identifier:)` | Yes |
| Alert counts and types | `/alerts/active/count`, `/alerts/types` | `activeAlertCount()`, `alertTypes()` | No |
| Alert history | `/alerts` | `alerts(matching:)` | Yes |
| Stations | `/stations`, `/stations/{id}`, `/gridpoints/{wfo}/{x},{y}/stations` | `observationStations(...)`, `observationStation(identifier:)` | Directory only |
| Observation history | `/stations/{id}/observations`, `/observations/{time}` | `observations(matching:)`, `observation(stationIdentifier:timestamp:)` | Yes |
| Zones | `/zones`, `/zones/{type}`, `/zones/{type}/{id}`, its forecast, a forecast zone's observations and stations | `zones(...)`, `zone(...)`, `zoneForecast(...)` | No |
| Offices | `/offices/{id}`, its headlines, one headline, its briefing metadata | `office(identifier:)`, `officeHeadlines(...)`, `officeBriefing(...)` | No |
| Products | all nine `/products` routes | `products(...)`, `product(identifier:)`, `latestProduct(at:ofType:)`, `productTypes(...)`, `productLocations(...)` | No |
| Glossary | `/glossary` | `glossary()` | No |

Also built: a shared point cache, opt-in retries for transient failures, Foundation measurement
conversion for WMO units, and validated following of every link and redirect the service returns.

Not yet built: aviation (`/aviation`), radar (`/radar`), and terminal aerodrome forecasts
(`/stations/{id}/tafs`).

Not supported, by design:

- `/points/{latitude},{longitude}/stations`, which the service deprecated. It redirects to the grid
  station list that `observationStations(near:)` already reads.
- XML and plain-text representations: CAP XML and Atom alerts, speech synthesis radio documents
  (`/points/.../radio`, `/radio`, and the zone radio route), and `text/plain` products. The package
  decodes typed JSON; the JSON alert representation carries the same CAP fields.
- Downloads: office briefing PDFs, weather story images, and the deprecated `/icons` and
  `/thumbnails` routes.

What the package does not guarantee, because the service does not:

- **Order.** Lists keep the service's order. A coordinate's first listed station is not guaranteed to
  be the closest, and history pages are not guaranteed newest first.
- **Freshness.** No observation is rejected as stale and no fallback station is tried.
  `stationId` and `timestamp` tell you what you got.
- **Completeness.** A page sequence is not a stable snapshot and is not deduplicated. Values yielded
  before an error are partial results.
- **Conversion.** Readings keep their WMO unit codes, `null` values stay `nil`, and unknown codes
  stay in `rawValue`. Converting is explicit.
- **Caching.** Apart from the point cache, the SDK caches no responses and sends no conditional
  requests. On Apple platforms, your `URLSession`'s own `URLCache` applies.

## Usage

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(myweatherapp.com, contact@myweatherapp.com)")
let home = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)

let observation = try await weather.latestObservation(from: .nearest(to: home))
print(observation.textDescription ?? "", observation.temperature?.value ?? .nan)

// An explicit station needs just one HTTP request.
let atAirport = try await weather.latestObservation(from: .station("KATT"))
```

The API has no key, but it rejects a request without a `User-Agent` naming your application and a way
to contact you, so the client requires one and has no default. On Apple platforms, `userAgent:`
sends through the shared URL session. For a custom session, transport, point cache, retry policy,
or clock, use `NWSClient(clock:configuration:pointCache:retryPolicy:session:)` or its `transport:`
counterpart.

`WeatherCoordinate` rejects nonfinite and out-of-range values, then rounds to the four decimal places
the service accepts. `.nearest(to:)` resolves the point, reads its station list, and uses the first
listed station: three requests on a cold cache, with no distance calculation.

Every operation is available at three levels, and all three share one executor:

```swift
let everyday = try await weather.forecast(for: home)                // the domain value
let reusable = try await weather.value(for: .forecast(for: home))   // a stored, inspectable request
let direct = try await weather.send(.point(for: home))              // one HTTP operation
```

### Observations

A `WeatherObservation` carries every field of the service's observation schema, including the raw
METAR message, 24-hour extremes, precipitation totals, present weather, and cloud layers. Fields a
station did not report stay `nil`.

```swift
for phenomenon in observation.presentWeather ?? [] {
  print(phenomenon.rawString, phenomenon.intensity?.rawValue ?? "", phenomenon.weather.rawValue)
}

let query = try ObservationQuery(limit: 24, start: start, stationIdentifier: "KATT")
for try await reading in weather.observations(matching: query) {
  print(reading.properties.timestamp, reading.properties.temperature?.value ?? .nan)
}

let exact = try await weather.observation(stationIdentifier: "KATT", timestamp: timestamp)
```

`observation(stationIdentifier:timestamp:)` answers only an exact instant; any other instant is the
service's `404`, with no nearest match. See
[Observation history](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/observationhistory).

### Forecasts

```swift
let forecast = try await weather.forecast(for: home)
let hourly = try await weather.hourlyForecast(
  for: home,
  options: .init(featureFlags: [.temperatureQuantity, .windSpeedQuantity], units: .si)
)
```

Both follow the point's links. Periods keep service order, and temperature and wind decode either
their scalar or quantitative shape. A quantity feature flag answers in WMO SI units whatever `units`
says, and the service ignores a flag it does not know. See
[Forecasts](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/forecasts).

### Forecast grids

```swift
let grid = try await weather.forecastGrid(for: home)
for entry in grid[.temperature]?.values ?? [] {
  print(entry.validTime.start, entry.validTime.duration.rawValue, entry.value ?? .nan)
}
let hazards = grid.hazards?.values.flatMap(\.value) ?? []
```

Every quantitative layer is keyed by an open `ForecastGridLayerName`, so a layer the service adds
later is kept. Each `validTime` is a parsed `ValidTimeInterval`. The grid is never cached. See
[Forecast grids](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/forecastgrids).

### Alerts

```swift
let nearby = try await weather.activeAlerts(for: home)
let texas = try await weather.activeAlerts(inArea: .texas)
let gulf = try await weather.activeAlerts(inRegion: .gulfOfMexico)
let severe = try await weather.activeAlerts(
  matching: .init(location: .zones(["TXZ192"]), severity: [.severe]))

let count = try await weather.activeAlertCount()
print(count.total, count.areas[.texas] ?? 0)

let history = try AlertQuery(
  end: end, filter: .init(location: .areas([.texas]), status: [.actual]), limit: 100,
  start: start)
for try await alert in weather.alerts(matching: history) {
  print(alert.properties.sent, alert.properties.event)
}
```

Awaited methods return one page. The synchronous `alerts(matching:)` and `activeAlerts(matching:)`
overloads return lazy sequences that follow the service's continuation links. Area, region, and CAP
codes are open values, and a String-backed enum of your own works at every level. See
[Active alerts](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/activealerts) and
[Alert history](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/alerthistory).

### Stations

```swift
let station = try await weather.observationStation(identifier: "KATT")
let nearHome = try await weather.observationStations(near: home)

let query = try ObservationStationQuery(limit: 100, states: [.texas])
for try await station in weather.observationStations(matching: query) {
  print(station.properties.stationIdentifier)
}
```

The station directory pages; the stations near a coordinate are always one page, because that
list's continuation link does not continue it. See
[Observation stations](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/observationstations).

### Zones

```swift
let zone = try await weather.zone(identifier: "TXZ192", type: .forecast)
let zoneForecast = try await weather.zoneForecast(identifier: "TXZ192", type: .forecast)
let forecastZones = try await weather.zones(matching: try ZoneQuery(areas: [.texas]), ofType: .forecast)
let readings = try await weather.observations(
  inForecastZone: try ZoneObservationQuery(limit: 10, zoneIdentifier: "TXZ192"))
```

Every zone route answers one response. A zone's polygon stays available as raw GeoJSON in
`Feature.geometry`. The type in the route and the type a zone reports can differ: the `forecast`
route answers zones reported as `public`. See
[Zones](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/zones).

### Offices

```swift
let office = try await weather.office(identifier: "EWX")
let headlines = try await weather.officeHeadlines(officeIdentifier: "EWX")
if let briefing = try await weather.officeBriefing(officeIdentifier: "LWX") {
  print(briefing.title ?? "Untitled briefing")
}
```

Headline content is unrendered HTML, kept as sent. `officeBriefing(officeIdentifier:)` returns nil
when the office has no current briefing; its `download` link is never requested. See
[Offices](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/offices).

### Products

```swift
let discussions = try await weather.products(at: "EWX", ofType: .areaForecastDiscussion)
let latest = try await weather.latestProduct(at: "EWX", ofType: .areaForecastDiscussion)
print(latest.productText ?? "")  // the bulletin, exactly as the service sent it

let query = try ProductQuery(limit: 2, locations: ["EWX"], types: [.areaForecastDiscussion])
let listed = try await weather.products(matching: query)

let types = try await weather.productTypes()
let locations = try await weather.productLocations(for: .areaForecastDiscussion)
```

List entries carry no text, so `productText` is nil for them; fetch one with `product(identifier:)`.
A product's `issuingOffice`, such as `KEWX`, is a different vocabulary from a product location such
as `EWX`. See [Products](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/products).

### Glossary

```swift
let glossary = try await weather.glossary()
let agl = glossary.entries.filter { $0.term == "AGL" }
```

Entries are an array in service order because the service repeats terms. Definitions keep their HTML
and line endings. See [Glossary](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/glossary).

### Paging

Collections that the service continues through `pagination.next` offer page and item sequences:
active alerts, alert history, the station directory, and observation history.

```swift
for try await page in weather.observationStationPages(matching: query) {
  print(page.features.count)
}
```

Sequences are lazy, never prefetch, and start over for each iterator. A missing, invalid, or repeated
continuation link throws `NWSError.pagination` before its page is yielded. Stop when you have enough;
the service does not promise a finite traversal. See
[Paginating collections](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/paginatingcollections).

### Reusable requests

Creating a request performs no I/O. Name your own:

```swift
extension WeatherRequest where Response == WeatherObservation {
  static var homeConditions: Self { .latestObservation(from: .station("KATT")) }
}

let conditions = try await weather.value(for: .homeConditions)
```

`WeatherRequest(endpoint:)` wraps a single request with a response model of your own, for an
endpoint this package does not build. See
[Using requests](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/usingrequests).

### Caching and retries

Coordinate lookups share a `PointCache`: up to 128 point mappings for 24 hours, shared by client
copies. Pass `pointCache: nil` to disable it. Forecasts, grids, and observations are fetched each
time.

Each request is sent once unless you opt into a retry policy:

```swift
let weather = NWSClient(
  configuration: NWSConfiguration(userAgent: "(myweatherapp.com, contact@myweatherapp.com)"),
  retryPolicy: .nwsTransientFailures
)
```

`nwsTransientFailures` retries timeouts and `429`, `500`, `502`, `503`, and `504` answers, up to three
attempts per HTTP request, waiting one second and then five, or the service's numeric `Retry-After`.

### Units

`SwiftNWS` converts WMO unit codes with Foundation, on every supported platform:

```swift
let fahrenheit = observation.temperature?.measurement(in: UnitTemperature.fahrenheit)
let humidity = observation.relativeHumidity?.fraction
```

Temperature, speed, pressure, length, and angle are covered. An unknown unit, an incompatible
dimension, or a null value returns nil. See
[Units](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/units).

### Other networking stacks

A consumer with its own networking stack needs only `SwiftNWSModels`:

```swift
let endpoint = Endpoint.point(for: home)
// GET https://api.weather.gov/points/30.2672,-97.7431
// Accept: application/geo+json
```

Send a GET to `https://api.weather.gov` plus `endpoint.path`, set `Accept` to
`endpoint.accept.rawValue`, set your own `User-Agent`, set `Feature-Flags` from
`endpoint.featureFlags` when it is not empty, and decode the endpoint's response type. Validate a
service-provided link with `Endpoint(accept:featureFlags:link:)` before following it. Multi-step
requests expose a public `resolution` describing their steps. See
[Executing requests](https://kalebcooper.github.io/swift-noaa/documentation/swiftnwsmodels/executingrequests).

### Errors

Every client method throws `NWSError`: the service's problem details, a transport or decoding
failure, an invalid link, redirect, or continuation, too many redirects, an input rejected before
sending (station, alert, zone, office, headline, or product identifiers, zone types, product codes,
and alert or product locations), or a coordinate with no stations. Cancellation is
`NWSError.transport(.cancelled)`, checked before every HTTP request. When the service rejects a
parameter, `ProblemDetail.parameterErrors` names it and the values it accepts.

## Example

[`Examples/SwiftNWSDemo`](Examples/SwiftNWSDemo) is a small iOS app that shows the latest
observation, the forecast, the next 24 hours, and active alerts for an address or the device's
location. The API has no geocoding, so addresses are geocoded with MapKit. The app references this
package by local path; open `Examples/SwiftNWSDemo/SwiftNWSDemo.xcodeproj` with the package itself
closed in Xcode, since Xcode opens a local package in only one window.

## Products

| Product | What it is | Depends on |
|---|---|---|
| `SwiftNWSModels` | `Codable` models for every supported response, typed `Endpoint` and `WeatherRequest` values, validated queries and coordinates, and open code values. Usable with any networking stack. | Nothing. |
| `SwiftNWS` | `NWSClient`, `NWSConfiguration`, `NWSError`, `PointCache`, the page and item sequences, the retry policy, and WMO unit conversion. Re-exports swifty-networking's `HTTPCore`, so `Transport` and `TransportError` need no import of their own. | `SwiftNWSModels`, swifty-networking, swift-http-types. |

A consumer with its own networking stack adds only `SwiftNWSModels` and fetches no dependency at all.

## Requirements

- Swift 6.2 or later.
- iOS, macOS, tvOS, visionOS, and watchOS 26 or later, Linux, or Android.
- `SwiftNWS` depends on [swifty-networking](https://github.com/KalebCooper/swifty-networking) 1.1.0 or
  later and [swift-http-types](https://github.com/apple/swift-http-types) 1.6.0 or later. On Apple
  platforms it sends through `URLSession`. On Linux and Android, enable the off-by-default
  `HTTPPortable` trait, which pulls in AsyncHTTPClient and SwiftNIO, and pass swifty-networking's
  `AsyncHTTPClientTransport` to `NWSClient(configuration:transport:)`. A consumer who leaves the
  trait off never fetches or builds either.

## Installation

```swift
.package(url: "https://github.com/KalebCooper/swift-noaa.git", .upToNextMinor(from: "0.2.0"))
```

On Linux or Android, enable the trait on the dependency:

```swift
.package(
  url: "https://github.com/KalebCooper/swift-noaa.git", .upToNextMinor(from: "0.2.0"),
  traits: ["HTTPPortable"])
```

Until 1.0.0, a minor release can change the public API, so pin to the minor version. Then add
`SwiftNWS`, or only `SwiftNWSModels`, to your target's dependencies. See
[CONTRIBUTING.md](CONTRIBUTING.md) to build and test the package locally.

## License

MIT. See [LICENSE](LICENSE).

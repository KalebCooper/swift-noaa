# swift-noaa

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Swift integrations for NOAA services, starting with the National Weather Service.

The package currently provides `Codable` models and endpoint descriptions for the
[National Weather Service API](https://www.weather.gov/documentation/services-web-API) that you can
send through any networking stack, plus an SDK that sends them for you through
[swifty-networking](https://github.com/KalebCooper/swifty-networking).

## Status

The 0.1.0 release implements current observations, twelve-hour and hourly forecasts,
raw forecast grid data with every layer and parsed valid times, the stations near a coordinate,
point caching, active alerts by coordinate, area, marine region, zone, and CAP filters, active alert
counts, the recognized alert event types, alert history with a time
window, a station's observation history, one station's metadata, the observation a station made at
an exact instant, and lazy station-directory, active-alert, alert-history,
and observation-history pagination. WMO readings can be converted with Foundation.

Since 0.1.0, the zone endpoints are built: the directory at `/zones` and `/zones/{type}`, one zone
at `/zones/{type}/{zoneId}`, a zone's text forecast, and a forecast zone's observations and
stations, with a feature's GeoJSON geometry retained as raw JSON. Every zone route answers one
response: the directory declares no cursor, and the observation and station routes return
continuation links that lead somewhere other than the rest of the list, so the client does not
follow them.

The glossary at `/glossary` is built as well. It answers in one response, with the entries in
service order and each definition exactly as the service wrote it, markup and all.

Office metadata and headlines are built: `/offices/{officeId}`, the headline list at
`/offices/{officeId}/headlines`, and one headline. The headline list is one response in service
order, and a headline's content is unrendered HTML returned as sent. Office briefings are not yet
built, weather stories (`/offices/{officeId}/weatherstories` and its image download) are not
supported, and no PDF or image is ever downloaded.

Product endpoints and retries are not built.

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

A `WeatherObservation` carries every field the service's observation schema defines, including
the raw METAR message, 24-hour temperature extremes, precipitation totals, the decoded present
weather, and cloud layers. Readings keep the service's unit, fields the station did not report stay
`nil`, and weather and sky coverage codes keep unknown values in `rawValue`.

```swift
for phenomenon in observation.presentWeather ?? [] {
  print(phenomenon.rawString, phenomenon.intensity?.rawValue ?? "", phenomenon.weather.rawValue)
}
for layer in observation.cloudLayers ?? [] {
  print(layer.amount.rawValue, layer.base.value ?? .nan, layer.base.unitCode)
}
```

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
ISO 8601 dates, and its validity interval as a `ValidTimeInterval`. Temperature and wind retain either their legacy
values or quantitative objects, including ranges and missing measurements. No conversion or period
filtering is implicit. Direct `Endpoint.forecast(for:options:)` and
`Endpoint.hourlyForecast(for:options:)` factories accept a decoded point. Forecast units,
feature flags, temperature units and trends, wind directions, and measurement quality flags are
typed open values: known schema codes have named static members, while `rawValue` retains additions.

### Forecast grids

```swift
let grid = try await weather.forecastGrid(for: home)
for entry in grid[.temperature]?.values ?? [] {
  print(entry.validTime.start, entry.validTime.duration.hours, entry.value ?? .nan)
}
print(grid[.temperature]?.unitCode ?? "")  // "wmoUnit:degC"

// Weather and hazards have their own types.
for entry in grid.weather?.values ?? [] {
  for weather in entry.value where weather.phenomenon != nil {
    print(weather.coverage?.rawValue ?? "", weather.phenomenon?.rawValue ?? "")
  }
}
let watches = grid.hazards?.values.flatMap(\.value) ?? []

// The same lookup as a reusable request, or as one HTTP operation from a decoded point.
let request = WeatherRequest.forecastGrid(for: home)
let point = try await weather.send(.point(for: home)).properties
if let endpoint = Endpoint.forecastGrid(for: point) {
  let feature = try await weather.send(endpoint)  // Feature<ForecastGrid>
}
```

`forecastGrid(for:)` follows the point's `forecastGridData` link to `/gridpoints/{wfo}/{x},{y}`.
Every quantitative layer is keyed by an open `ForecastGridLayerName`: the named members cover the
service's schema, and a layer the service adds later is kept under its own name. A layer the service
omits has no entry, while a layer it sends with no values is present and empty. Values keep the
service's order, intervals, and `null`s, and each layer keeps its WMO unit code, or `nil` when the
service names none. Nothing is converted, sorted, or resampled; `quantity(unitCode:)` pairs a value
with its unit for the WMO measurement adapter.

Each `validTime` is a `ValidTimeInterval`: a start instant and an `ISO8601Duration` whose `end` is
available when the duration has no years or months. The service takes no `units` query or feature
flags for grid data, answers in the units each layer names, and updates the grid through the day;
the client never caches it, and `updateTime` says when it last changed. Only GeoJSON is supported.

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
if let request = WeatherRequest.activeAlerts(inZone: "TXZ192") {
  for try await page in weather.activeAlertPages(for: request) {
    print(page.features.count)
    break
  }
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

The area, region, and zone endpoint and request factories return nil for empty codes or invalid
encoded paths. The everyday client methods throw `NWSError.invalidAlertLocation` before sending.
Unknown codes with valid paths remain usable.

Marine regions have their own path, and a String-backed region enum works the same way:

```swift
let gulf = try await weather.activeAlerts(inRegion: .gulfOfMexico)
if let request = WeatherRequest.activeAlerts(inRegion: .atlantic) {
  for try await page in weather.activeAlertPages(for: request) {
    print(page.features.count)
  }
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

The stations the service lists for a coordinate's grid cell come from the point's station link:

```swift
let nearby = try await weather.observationStations(near: home)
let reusable = WeatherRequest.observationStations(near: home)
for try await station in weather.observationStations(for: reusable) {
  print(station.properties.stationIdentifier)
}
```

This list is always one page, in the service's order, which does not guarantee distance order. Its
continuation link names every station for the grid again at a later offset and leads only to empty
pages, so neither the one-page methods nor the sequences follow it. The point comes from the point
cache.

One station's metadata comes from `/stations/{stationId}` in one request:

```swift
let station = try await weather.observationStation(identifier: "KATT")
print(station.name, station.provider ?? "", station.forecast as Any)
```

`ObservationStation` carries the name, identifier, elevation, time zone, provider and sub-provider,
and links to the forecast, county, and fire weather zones containing the station, each present only
when the service sends it; list responses relative to a location add a distance and bearing. The
matching `WeatherRequest.observationStation(identifier:)` returns the same properties, and
`Endpoint.observationStation(identifier:)` keeps the GeoJSON envelope. An empty identifier or invalid encoded path throws
`NWSError.invalidStationIdentifier` before any request; an unknown station is the service's `404`
problem.

### Point caching

Coordinate forecasts, forecast grids, nearby station lists, and observations share a `PointCache`:
up to 128 mappings for 24 hours, with least-recently-used eviction and monotonic expiry. Client
copies share it. Forecast, grid, and observation responses are fetched each time; direct `send`
calls bypass the point cache. Concurrent misses may make independent requests.

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

if let endpoint = Endpoint<Feature<StationIdentity>>(path: "/stations/KATT/observations/latest") {
  let identityRequest = WeatherRequest(endpoint: endpoint)
  let identity = try await weather.value(for: identityRequest)
  print(identity.properties.stationId)
}
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
its own page size, and an empty station identifier or invalid encoded path is rejected at construction. The service decides
which observations a window matches and how it orders them; recorded responses list the newest
first, but that is not a documented guarantee. `ObservationPageSequence` and `ObservationSequence`
follow the same lazy, single-traversal contract as the station sequences, and each feature's
properties are the same `WeatherObservation` that `latestObservation(from:)` returns.
`Endpoint.observations(query:)` describes one page for another networking stack.

To read one observation again, pass its exact timestamp:

```swift
if let timestamp = firstPage.features.first?.properties.timestamp {
  let observation = try await weather.observation(stationIdentifier: "KATT", timestamp: timestamp)
  print(observation.temperature?.value ?? .nan)
}
```

`observation(stationIdentifier:timestamp:)` sends one request to
`/stations/{stationId}/observations/{time}`, with the instant in ISO 8601 form in UTC at
whole-second precision. The service returns an observation only when the instant matches one
exactly; any other instant, including one between two observations, is the service's `404` problem,
and the client does not look for the nearest observation. `WeatherRequest.observation(stationIdentifier:timestamp:)`
and `Endpoint.observation(stationIdentifier:timestamp:)` describe the same lookup.

### Zones

```swift
let zone = try await weather.zone(identifier: "TXZ192", type: .forecast)
print(zone.name, zone.type.rawValue, zone.radarStation ?? "")

let query = try ZoneQuery(areas: [.texas], limit: 10)
let forecastZones = try await weather.zones(matching: query, ofType: .forecast)
let countiesAndFireZones = try await weather.zones(matching: query, types: [.county, .fire])
```

`zone(effective:identifier:type:)` reads `/zones/{type}/{zoneId}` and returns the feature's
`WeatherZone` properties: the identifier, name, reported type, office fields, effective and
expiration dates, observation station links, radar station, state, and time zones, each present only
when the service sends it. The type in the route and the type a zone reports are different values.
The `forecast` route answers zones reported as `public`, the `marine` route answers `coastal` and
`offshore` zones, and the URL the service returns does not mirror the route asked on. An effective
instant selects the definition in effect at that instant and is sent in ISO 8601 UTC at whole-second
precision. `WeatherRequest.zone(effective:identifier:type:)` returns the same properties, and
`Endpoint.zone(effective:identifier:type:)` keeps the GeoJSON envelope, so a zone's polygon stays
available in `Feature.geometry`. An empty or unusable type throws `NWSError.invalidZoneType` and an
unusable identifier throws `NWSError.invalidZoneIdentifier`, both before any request.

`zones(matching:ofType:)` reads `/zones/{type}`, and `zones(matching:types:)` reads `/zones`, where
the types are a query filter and an empty array asks for every type. `ZoneQuery` carries areas, an
effective instant, identifiers, a geometry option, a limit, a point, and regions, and takes no
arguments by default, so an unfiltered directory is `try ZoneQuery()`. The service declares no page
size or cursor for the directory and the recorded responses carry no continuation, so each list is
one request and one response capped by its limit; there are no zone sequences. The recorded lists
also send `"geometry": null` for every zone, so the geometry option states what the request asks for
rather than what comes back.

```swift
let forecast = try await weather.zoneForecast(identifier: "TXZ192", type: .forecast)
for period in forecast.periods {
  print(period.number, period.name, period.detailedForecast)
}

let readings = try await weather.observations(
  inForecastZone: try ZoneObservationQuery(limit: 10, zoneIdentifier: "TXZ192"))
let stations = try await weather.observationStations(inForecastZone: "TXZ192")
```

`zoneForecast(identifier:type:)` reads `/zones/{type}/{zoneId}/forecast` and returns the feature's
`ZoneForecast` properties: when the service last updated the forecast, a link to the zone, and the
periods in service order. A period carries a number, a name, and one paragraph of forecast text, and
nothing else. The route accepts no units query and no feature flags, so there are no times,
temperatures, or wind values to read, and the client does not renumber or reorder the periods.

`observations(inForecastZone:)` reads `/zones/forecast/{zoneId}/observations` and returns the
readings of the stations the service associates with the zone, so one response can carry several
stations. `ZoneObservationQuery` validates the zone identifier and an optional limit from 1 through
500 at construction and sends window bounds as whole-second ISO 8601 instants in UTC.
`observationStations(inForecastZone:)` reads `/zones/forecast/{zoneId}/stations` and returns that
one page in service order.

Both of those lists are one response, and neither continues. The observation response links to a
single station's history, which drops the zone's other stations, and the station response links to
the same stations again at a later offset before leading to empty pages. The client never follows
either link. The station route's declared limit and cursor made no difference to the recorded
responses, so the named factory sends neither; a custom `Endpoint(path:)` can still send them.
Passing a forecast-zone station request to `observationStationPages(for:)` or
`observationStations(for:)` yields that single page and finishes.

Zone request factories always return a request, and execution reports an unusable type or
identifier. Every level also accepts a `String`-backed type of your own in place of `ZoneType`.

### Glossary

```swift
let glossary = try await weather.glossary()
let matches = glossary.entries.filter { $0.term == "AGL" }

let stored = WeatherRequest.glossary
let reusable = try await weather.value(for: stored)
let direct = try await weather.send(.glossary)
```

`glossary()` reads `/glossary` in one request and returns `WeatherGlossary`. The service offers this
resource only as JSON-LD, so the endpoint asks for `MediaType.jsonLD`, and it sends no query items
and no feature flags because the service documents no page size or cursor for the glossary. There
are no glossary sequences to follow, which describes the request rather than the size of the answer.

`WeatherGlossary.entries` is an array in service order, not a dictionary, because the service repeats
terms: one recorded response held two `AGL` entries whose definitions differed only in trailing
whitespace, so a term is a filter rather than a key. Each `GlossaryEntry` carries a required `term`
and `definition`, and a body without the `glossary` array fails to decode rather than yielding an
empty glossary.

A definition is the service's text unchanged, including HTML tags such as `<br>`, character entities
such as `&frac12;` and `&deg;`, and carriage return line endings. Nothing renders, escapes, strips,
or normalizes it, and nothing builds an attributed string, so converting a definition for display is
your app's work. The client adds no search index, term matching, or caching, and it does not follow
links found inside a definition.

### Offices

```swift
let office = try await weather.office(identifier: "EWX")
print(office.name)  // "Austin/San Antonio, TX"

let headlines = try await weather.officeHeadlines(officeIdentifier: "EWX")
for headline in headlines.headlines {
  print(headline.title, headline.issuanceTime as Any)
}

let request = WeatherRequest.officeHeadline(
  identifier: "ab45482ca5f57ff412eb1320721d5ac9", officeIdentifier: "EWX")
let headline = try await weather.value(for: request)
```

`office(identifier:)`, `officeHeadlines(officeIdentifier:)`, and
`officeHeadline(identifier:officeIdentifier:)` each send one request for the JSON-LD body the
service offers and return `WeatherOffice`, `OfficeHeadlines`, or `OfficeHeadline`. Each is also a
`WeatherRequest` factory and an `Endpoint`. The request factories always return a request; executing
one rejects an unusable identifier before sending with `NWSError.invalidOfficeIdentifier` or
`NWSError.invalidHeadlineIdentifier`, checking the office identifier first.

Optional fields are nil only when the service omits them or sends `null`. A value it does send is
kept, so an office whose fax number is an empty string reports `""`. The office's zone, station, and
parent office fields are API links the client does not follow; turn one into an `Endpoint` to read it.

A headline's `url`, from its `@id`, is its identity in the API and can become a validated endpoint.
Its `link` is editorial content that may point off the API origin, and the client never follows it.
`content` is HTML exactly as sent: nothing renders, escapes, or strips it. The headline list is one
response in service order. The route documents no page size or cursor, so none is sent, which
describes the request rather than how many headlines come back. Headlines are not sorted or filtered
by importance or issuance time.

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

Raw-path initializers are failable. Paths must start with one slash and may include an encoded
query. Absolute or authority URLs, fragments, raw whitespace and controls, malformed escapes,
backslashes, and dot path segments are rejected, including encoded path equivalents. Accepted paths
and queries retain their exact spelling; query values are not treated as path segments, and query
names such as `api_key` are allowed. `path` is immutable; `accept` and `featureFlags` remain configurable.

`WeatherRequest.resolution` is also public and transport-independent: `.endpoint` describes one
HTTP call; `.latestObservation` describes an `ObservationSource`; forecast cases describe a coordinate
and options; `.alert` describes an identifier; `.observationStation` describes a station identifier;
`.observation` describes a station identifier and an exact timestamp. `.activeAlerts` contains its initial typed endpoint,
`.alerts` contains an alert-history query, `.observationStations` contains a station query, and
`.observations` contains an observation-history query; all four support opt-in sequence traversal. A custom executor can interpret the source using the lookup
rules above. Requests contain no SDK or transport closures.

Direct endpoints preserve the existing GeoJSON wrappers, including `Feature.id` and
`Feature.properties`. Everyday observation methods return `WeatherObservation` directly, and the
station lookup returns `ObservationStation`.
Measurements can be absent or have a null value. WMO unit identifiers remain strings; enumerated
quality codes are typed open values that preserve unknown `rawValue`s.

### Errors and migration

The client throws `NWSError`: NWS problem details, transport or decoding failures, invalid
service links or redirects, excess redirect hops, invalid pagination, invalid station, alert, zone,
office, or headline identifiers, zone types, and alert locations, or a station list with no stations. Cancellation is
`NWSError.transport(.cancelled)`, with a cancellation check before each HTTP call.
When the service rejects a request parameter, such as an unknown marine region, the thrown
`ProblemDetail` lists each rejection in `parameterErrors`, including the values it accepts.

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
| `SwiftNWSModels` | `WeatherCoordinate`, `ObservationSource`, `AlertQuery`, `ObservationQuery`, `ObservationStationQuery`, `WeatherRequest`, `Endpoint`, and portable response models: `Point`, `ObservationStation`, `WeatherObservation` with its `WeatherPhenomenon` and `CloudLayer` values, `WeatherForecast`, `WeatherAlert`, `QuantitativeValue`, `ProblemDetail`, and the GeoJSON `Feature` and `FeatureCollection` wrappers. Usable on any data layer. | Nothing. |
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

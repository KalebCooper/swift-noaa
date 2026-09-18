# Reading observation stations

Look up one station, list the stations near a coordinate, or traverse the station directory one
page or one feature at a time.

## Look up one station

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(example.com, contact@example.com)")
let station = try await weather.observationStation(identifier: "KATT")
print(station.name, station.provider ?? "", station.forecast as Any)

let reusable = try await weather.value(for: .observationStation(identifier: "KATT"))
let direct = try await weather.send(.observationStation(identifier: "KATT"))
```

``NWSClient/observationStation(identifier:)`` sends one request to `/stations/{stationId}` and
returns the feature's `ObservationStation` properties: the name, identifier, elevation, time zone,
provider and sub-provider, and links to the forecast, county, and fire weather zones containing the
station, each present only when the service sends it. The direct endpoint keeps the GeoJSON envelope.
An empty identifier throws ``NWSError/invalidStationIdentifier(_:)`` before any request, and an
identifier the service does not recognize throws ``NWSError/problem(_:)`` with its `404` details. The
identifier is encoded as one path segment and otherwise passed to the service unchanged.

## List stations near a coordinate

```swift
let nearby = try await weather.observationStations(near: home)
for station in nearby.features {
  print(station.properties.stationIdentifier, station.properties.distance?.value ?? .nan)
}

let reusable = try await weather.value(for: .observationStations(near: home))
for try await station in weather.observationStations(for: .observationStations(near: home)) {
  print(station.properties.name)
}
```

``NWSClient/observationStations(near:)`` resolves the coordinate's point, through ``PointCache``,
and follows its validated `observationStations` link to `/gridpoints/{wfo}/{x},{y}/stations`. The
result is one page in the service's order, which does not guarantee distance order. The direct
endpoint is `Endpoint.observationStations(near:)`, which follows the link from a decoded point.

The list is always one page. The page carries a continuation link, but that link does not continue
the list: it names every station for the grid again at a later offset, and following it yields only
empty pages, each with another link. The client therefore never follows it. Page and feature
sequences built from `WeatherRequest.observationStations(near:)` resolve the point on the first read,
yield that one page, and finish.

## Traverse the directory

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(example.com, contact@example.com)")
let query = try ObservationStationQuery(limit: 100, states: [.texas])
let request = WeatherRequest.observationStations(query: query)

let firstPage = try await weather.value(for: request)
let direct = try await weather.send(.observationStations(query: query))

for try await station in weather.observationStations(for: request) {
  print(station.id as Any, station.properties.stationIdentifier)
  break
}
```

``NWSClient/observationStations(query:)`` returns ``ObservationStationSequence``, whose elements
are `Feature<ObservationStation>`, preserving the modeled GeoJSON metadata. For complete pages,
use ``NWSClient/observationStationPages(query:)``. Both delegate to their reusable-request
counterparts. Single-page `value(for:)` and `send` return one collection.

This is the package's canonical collection implementation. See <doc:PaginatingCollections> for the
shared execution, cancellation, partial-result, and changing-data semantics.

Queries accept an optional initial cursor, identifiers, state or territory codes, and a limit from
1 through 500, defaulting to 500. The service validates identifier and area vocabulary; empty arrays
omit filters. Continuations follow the exact validated provider path and query, without rebuilding
filters or cursors.

## Demand and completion

Sequence creation and iterator creation perform no I/O. Every iterator starts independently. Pages
are fetched only on demand, and features use the current page before fetching the next one. Breaking
iteration never prefetches. An empty page with pagination can continue; there is no promised finite
number of pages. Stop reading when you have enough. The traversal is not a stable snapshot and does
not deduplicate features returned by the service.

Absent pagination ends traversal. Missing, invalid, repeated, or cyclic next links throw
``NWSError/pagination(_:)`` before their page is yielded. Any failure ends the iterator, and later
reads return nil. Earlier values are partial results rather than a complete collection. Cancellation
is checked before requests and before returning buffered features.

Each page retains the same bounded redirects, User-Agent, representation headers, problem-detail
mapping, and transport behavior as direct endpoint requests.

## Custom endpoints and coordinate observations

A `WeatherRequest(endpoint:)` passed to the station sequence executors yields only that endpoint's
page, even if it contains pagination. Only the library-owned station-query resolution opts into
continuation. Nearest-observation lookups still use the first station on their returned page, without
additional pages, distance ordering, freshness filtering, or fallback. A station's past observations
are read through <doc:ObservationHistory>.

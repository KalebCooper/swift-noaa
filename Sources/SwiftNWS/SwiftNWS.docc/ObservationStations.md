# Reading observation stations

Traverse the station directory one page or one feature at a time.

## Overview

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

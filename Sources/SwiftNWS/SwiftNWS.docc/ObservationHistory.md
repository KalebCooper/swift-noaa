# Observation history

Read a station's past observations one page or one feature at a time.

## Query a station

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(example.com, contact@example.com)")
let query = try ObservationQuery(limit: 24, start: start, stationIdentifier: "KATT")
let request = WeatherRequest.observations(query: query)

let firstPage = try await weather.observations(query: query)
let direct = try await weather.send(.observations(query: query))

for try await observation in weather.observations(for: request) {
  print(observation.properties.timestamp, observation.properties.temperature?.value ?? .nan)
  break
}
```

`ObservationQuery` names a station, an optional `start` and `end`, an optional page size from 1
through 500, and an optional initial cursor. Window bounds are sent as ISO 8601 instants in UTC
with whole-second precision, and an absent bound is left open. A nil limit omits the parameter so
the service applies its own page size. An empty station identifier or invalid encoded path is rejected at construction.
The service decides which observations a window matches and how it orders them; recorded responses
list the newest observation first, but that order is not a documented guarantee.

Awaiting `observations(query:)` retrieves one page. Iterating its synchronous overload returns
``ObservationSequence``, whose elements are `Feature<WeatherObservation>`. For complete pages, use
``NWSClient/observationPages(query:)``. Both delegate to their reusable-request counterparts,
``NWSClient/observations(for:)`` and ``NWSClient/observationPages(for:)``. Single-page `value(for:)`
and `send` return one collection. Each feature's properties are the same `WeatherObservation` that
``NWSClient/latestObservation(from:)`` returns.

## Demand and completion

Sequence creation and iterator creation perform no I/O. Every iterator starts independently. Pages
are fetched only on demand, and features use the current page before fetching the next one. Breaking
iteration never prefetches. An empty page with pagination can continue; there is no promised finite
number of pages. Stop reading when you have enough. The traversal is not a stable snapshot and does
not deduplicate observations returned by the service.

Absent pagination ends traversal. Missing, invalid, repeated, or cyclic next links throw
``NWSError/pagination(_:)`` before their page is yielded. Any failure ends the iterator, and later
reads return nil. Earlier values are partial results rather than a complete collection. Cancellation
is checked before requests and before returning buffered features. Later paths and queries come from
validated service links rather than the original query. See <doc:PaginatingCollections> for the
shared sequence contract.

## Read one observation by its timestamp

```swift
let timestamp = firstPage.features[0].properties.timestamp
let observation = try await weather.observation(stationIdentifier: "KATT", timestamp: timestamp)
let reusable = WeatherRequest.observation(stationIdentifier: "KATT", timestamp: timestamp)
if let endpoint = Endpoint.observation(stationIdentifier: "KATT", timestamp: timestamp) {
  let direct = try await weather.send(endpoint)
}
```

``NWSClient/observation(stationIdentifier:timestamp:)`` sends one request to
`/stations/{stationId}/observations/{time}` and returns the feature's `WeatherObservation`
properties. The instant is sent in ISO 8601 form in UTC with whole-second precision. The service
returns an observation only when the instant matches an observation's timestamp exactly, so take it
from observation history or from an earlier observation. Any other instant, including one between two
observations or older than the service keeps, throws ``NWSError/problem(_:)`` with `404` details; the
client does not look for the nearest observation or try another instant. An empty station identifier or invalid encoded path
throws ``NWSError/invalidStationIdentifier(_:)`` before any request.

## Custom endpoints and latest observations

A `WeatherRequest(endpoint:)` passed to the observation sequence executors yields only that
endpoint's page, even if it contains pagination. Only the library-owned observation-query resolution
opts into continuation. ``NWSClient/latestObservation(from:)`` remains a single-response lookup and
does not read history.

# Paginating collections

Read a verified NWS collection one page or one feature at a time without eagerly loading every result.

## Choose an execution path

Observation stations are the package's canonical pagination implementation. The same request supports
single-page execution and both lazy sequence views:

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(example.com, contact@example.com)")
let query = try ObservationStationQuery(limit: 100, states: [.texas])
let request = WeatherRequest.observationStations(query: query)

let firstPage = try await weather.value(for: request)
let direct = try await weather.send(.observationStations(query: query))
let pages = weather.observationStationPages(for: request)
let stations = weather.observationStations(for: request)
```

Single-response conveniences delegate through ``NWSClient/value(for:)``, whose executor sends typed
endpoints through ``NWSClient/send(_:)``. Lazy conveniences delegate to their request-based sequence
executors, which use swifty-networking to fetch pages through the same configured client. Both paths
therefore share the User-Agent, representation headers, redirects, cancellation checks, problem
details, and transport errors.

`value(for:)` and `send(_:)` return one collection. They do not follow `pagination.next`. A custom
`WeatherRequest(endpoint:)` also remains one page when passed to a sequence executor because only a
library-owned resolution declares continuation semantics.

## Read pages or features

Use a page sequence when the collection envelope or page boundaries matter:

```swift
for try await page in weather.observationStationPages(query: query) {
  print(page.features.count)
  break
}
```

Use an item sequence for a flattened stream that still preserves each feature's GeoJSON metadata:

```swift
for try await station in weather.observationStations(query: query) {
  print(station.id as Any, station.properties.stationIdentifier)
  break
}
```

Both sequences send nothing until the iterator requests its first element. They fetch only on demand,
never prefetch, and each iterator starts an independent traversal. Item sequences consume the current
page before asking for another. Breaking either loop prevents the next request.

`next(isolation:)` defaults to the caller's isolation and forwards it through every iterator wrapper,
including redirected page fetches. Each iterator must be read serially; it is not Sendable and does
not support concurrent reads.

Active alerts offer the same two views through ``NWSClient/activeAlertPages(matching:)`` and the
synchronous `activeAlerts(matching:)` overload, alert history through
``NWSClient/alertPages(matching:)`` and the synchronous `alerts(matching:)` overload, and a
station's observation history through ``NWSClient/observationPages(query:)`` and the synchronous
`observations(query:)` overload. Await the other overload to retrieve one page.

## Handle cancellation and partial results

Cancel the task that owns iteration to stop traversal. Cancellation is checked before each request
and before returning an item already buffered from a page:

```swift
let traversal = Task {
  var stationIdentifiers: [String] = []
  do {
    for try await station in weather.observationStations(query: query) {
      stationIdentifiers.append(station.properties.stationIdentifier)
    }
  } catch {
    // stationIdentifiers contains only the partial results yielded before the failure.
  }
}

traversal.cancel()
```

Absent pagination ends traversal. An empty page can still continue when it has a next link. Missing,
invalid, repeated, or cyclic continuation links throw ``NWSError/pagination(_:)`` before the affected
page is yielded. Redirect, problem-detail, decoding, transport, and cancellation failures also end
that iterator; later reads return `nil`. Values yielded earlier remain usable, but they are not a
complete result set.

## Account for changing service data

The sequences preserve every returned item, page order, and feature metadata. They do not sort,
deduplicate, or buffer a complete result set. NWS does not promise that a traversal is a stable
snapshot, so records can change, appear, or repeat while later pages are being fetched. Apply any
application-specific identity or snapshot policy after retrieval.

Only station-directory, active-alert, alert-history, and observation-history collections currently
opt into continuation. Other endpoint groups remain single page until their provider continuation
behavior is implemented and documented. Every zone list is one of them, for a different reason each
time, and none of them has a zone page or feature sequence to read:

- The service declares no cursor for `/zones` or `/zones/{type}`, and the recorded directory
  responses carry no continuation at all.

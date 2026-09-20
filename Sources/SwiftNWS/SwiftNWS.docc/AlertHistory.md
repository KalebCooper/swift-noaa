# Alert history

Retrieve past and present CAP alerts from `/alerts` one page or one feature at a time.

## Query a window

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(example.com, contact@example.com)")
let query = try AlertQuery(
  end: end, filter: .init(location: .areas([.texas]), status: [.actual]), limit: 100,
  start: start)
let request = WeatherRequest.alerts(matching: query)

let firstPage = try await weather.alerts(matching: query)
let direct = try await weather.send(.alerts(matching: query))

for try await alert in weather.alerts(for: request) {
  print(alert.properties.headline ?? alert.properties.event)
  break
}
```

`AlertQuery` combines an `ActiveAlertFilter`, an optional `start` and `end`, a page size from 1
through 500 defaulting to 500, and an optional initial cursor. Window bounds are sent as ISO 8601
instants in UTC with whole-second precision. The service decides which alerts a window matches and
how it orders them. The query does not validate the window against the filter, and it leaves an
absent bound open.

Awaiting `alerts(matching:)` retrieves one page. Iterating its synchronous
overload returns ``AlertSequence``, whose elements are `Feature<WeatherAlert>`. For complete pages,
use ``NWSClient/alertPages(matching:)``. Both delegate to their reusable-request counterparts,
``NWSClient/alerts(for:)`` and ``NWSClient/alertPages(for:)``. Single-page `value(for:)` and `send`
return one collection.

## Demand and completion

Sequence creation and iterator creation perform no I/O. Every iterator starts independently. Pages
are fetched only on demand, and features use the current page before fetching the next one. Breaking
iteration never prefetches. An empty page with pagination can continue; there is no promised finite
number of pages. Stop reading when you have enough. The traversal is not a stable snapshot and does
not deduplicate alerts returned by the service.

Absent pagination ends traversal. Missing, invalid, repeated, or cyclic next links throw
``NWSError/pagination(_:)`` before their page is yielded. Any failure ends the iterator, and later
reads return nil. Earlier values are partial results rather than a complete collection. Cancellation
is checked before requests and before returning buffered features. Later paths and queries come from
validated service links rather than the original query. See <doc:PaginatingCollections> for the
shared sequence contract.

## Share the alert executors

Active-alert and alert-history requests describe the same alert collections, so either executor
accepts both. Unwrap `WeatherRequest.activeAlerts(inArea: .texas)` before passing it to
`alertPages(for:)`. It and `activeAlertPages(for: .alerts(matching: query))` start at the request's own endpoint and
follow its validated links. A `WeatherRequest(endpoint:)` yields only that endpoint's page through
either executor.

## Redirect policy

The `/alerts` query can answer with a canonical redirect. Each page retains the same bounded
same-origin redirects, User-Agent, representation headers, problem-detail mapping, and transport
behavior as direct endpoint requests. See <doc:ActiveAlerts> for the redirect rules.

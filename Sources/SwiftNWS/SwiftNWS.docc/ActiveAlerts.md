# Active alerts

Retrieve active CAP alerts as GeoJSON and preserve the service's values.

## Query a location

```swift
let alerts = try await weather.activeAlerts(for: home)
let texas = try await weather.activeAlerts(inArea: .texas)
for feature in alerts.features {
  let alert = feature.properties
  print(alert.headline ?? alert.event)
  print(alert.instruction ?? "")
}
```

`ActiveAlertFilter` supports certainty, code, event, message type, severity, status, and urgency.
Its optional location is one of areas, a point, regions, region type, or zones. This excludes the
geographic combinations the service rejects. Empty arrays omit a filter. `AreaCode` and
`MarineRegionCode` name the live schema values while retaining unknown raw values. Zone identifiers,
event names, and event codes remain open strings.

Use `activeAlerts(inArea:)` or `activeAlerts(inZone:)` for canonical area or zone paths.
The area overloads on `NWSClient`, `WeatherRequest`, and `Endpoint` also accept a consumer-defined
String-backed enum directly. `alert(identifier:)` retrieves an individual alert's properties. Equivalent `WeatherRequest`
factories perform no work until executed. `Endpoint` factories retain the GeoJSON envelopes.

## Traverse pages and features

Awaiting `activeAlerts(matching:)` retrieves one page. Iterating its synchronous overload follows
validated continuation links and returns `Feature<WeatherAlert>` values:

```swift
let filter = ActiveAlertFilter(location: .areas([.texas]), severity: [.severe])
let firstPage = try await weather.activeAlerts(matching: filter)
for try await alert in weather.activeAlerts(matching: filter) {
  print(alert.properties.headline ?? alert.properties.event)
  break
}
for try await page in weather.activeAlertPages(matching: filter) {
  print(page.features.count)
  break
}
```

Use `activeAlertPages(for:)` or synchronous `activeAlerts(for:)` with any library alert request,
including `.activeAlerts(for: home)`, `.activeAlerts(inArea: .texas)`, and
`.activeAlerts(inZone: "TXZ192")`. Their initial endpoint paths are unchanged.
`WeatherRequest(endpoint:)` remains a single-page operation even when its response contains pagination.

``ActiveAlertPageSequence`` and ``ActiveAlertSequence`` send nothing until read and start independently
for each iterator. Pages preserve service order; features preserve their GeoJSON metadata. The
iterator fetches another page only after the buffered features are consumed. Empty pages with a
continuation still advance, and no finite traversal is guaranteed. See <doc:PaginatingCollections>
for the shared sequence contract.

Absent pagination is terminal. Missing, invalid, repeated, or cyclic next links throw
`NWSError.pagination` before their page is yielded. Cancellation is checked on every read,
including buffered items, and any error ends the iterator. Earlier values are partial results rather
than a complete collection. Later paths and queries come from validated service links rather than the
original filter. The traversal is not a stable snapshot and does not deduplicate alerts returned by
the service.

## Preserve the source

Known CAP codes use typed open values with named constants, and unknown raw values round-trip.
Nullable dates,
instructions, and headlines remain optional. Parameters and event codes retain their JSON values.
Awaited queries retain service order and stop after one returned collection. Page and feature
sequences follow links only on demand. CAP XML, Atom, and alert history are outside this release.

## Redirect policy

Some queries return a canonical redirect. The client follows HTTP 301, 302, 303, 307, and 308 at
most five times, retaining request headers. Targets must remain on `https://api.weather.gov`
without credentials or fragments. Loops, invalid targets, and excess hops throw `NWSError`.
Cancellation is checked before every hop. HTTP failures without a redirect location use the
ordinary transport or problem-detail error path.

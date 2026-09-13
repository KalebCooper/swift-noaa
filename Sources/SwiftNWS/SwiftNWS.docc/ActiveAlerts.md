# Active alerts

Retrieve active CAP alerts as GeoJSON and preserve the service's values.

## Query a location

```swift
let alerts = try await weather.activeAlerts(for: home)
for feature in alerts.features {
  let alert = feature.properties
  print(alert.headline ?? alert.event)
  print(alert.instruction ?? "")
}
```

`ActiveAlertFilter` supports certainty, code, event, message type, severity, status, and urgency.
Its optional location is one of areas, a point, regions, region type, or zones. This excludes the
geographic combinations the service rejects. Empty arrays omit a filter. The service validates
provider codes; this package does not keep a second, potentially stale registry.

Use `activeAlerts(inArea:)` or `activeAlerts(inZone:)` for canonical area or zone paths.
`alert(identifier:)` retrieves an individual alert's properties. Equivalent `WeatherRequest`
factories perform no work until executed. `Endpoint` factories retain the GeoJSON envelopes.

## Preserve the source

Known CAP codes have named constants, and unknown strings round-trip unchanged. Nullable dates,
instructions, and headlines remain optional. Parameters and event codes retain their JSON values.
Lists retain service order and stop after one returned collection; CAP XML, Atom, history, and
automatic pagination are outside this release.

## Redirect policy

Some queries return a canonical redirect. The client follows HTTP 301, 302, 303, 307, and 308 at
most five times, retaining request headers. Targets must remain on `https://api.weather.gov`
without credentials or fragments. Loops, invalid targets, and excess hops throw `NWSError`.
Cancellation is checked before every hop. HTTP failures without a redirect location use the
ordinary transport or problem-detail error path.

# Reading zones

## Look up one zone

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(example.com, contact@example.com)")
let zone = try await weather.zone(identifier: "TXZ192", type: .forecast)
print(zone.name, zone.type.rawValue)  // "Travis public"

let reusable = try await weather.value(for: .zone(identifier: "TXZ192", type: .forecast))
if let endpoint = Endpoint.zone(identifier: "TXZ192", type: .forecast) {
  let feature = try await weather.send(endpoint)
  print(feature.geometry as Any)
}
```

`zone(effective:identifier:type:)` sends one request to `/zones/{type}/{zoneId}` and returns the
feature's `WeatherZone` properties: the identifier, name, reported type, responsible office
fields, effective and expiration dates, observation station links, radar station, state, and time
zones, each present only when the service sends it. The direct endpoint keeps the GeoJSON envelope,
so `Feature.geometry` and `Feature.id` stay available; the everyday method and the reusable
request return properties only.

The type in the route and the type a zone reports are different values. The `forecast` route answers
zones whose reported `WeatherZone.type` is `public`, and the `marine` route answers `coastal` and
`offshore` zones. The identifying URL the service returns does not mirror the route either: asking
`/zones/marine/GMZ330` answers a feature whose `id` is
`https://api.weather.gov/zones/forecast/GMZ330` with the reported type `coastal`. Read the reported
type and the returned URL as the service's own values rather than deriving a route from them.

An effective instant selects the definition of the zone in effect at that instant, and is sent as
ISO 8601 in UTC at whole-second precision:

```swift
let asOf = try await weather.zone(effective: lastYear, identifier: "TXZ192", type: .forecast)
```

An empty type, or one that cannot be a single path segment, throws ``NWSError/invalidZoneType(_:)``
before any request. An empty or unusable identifier throws ``NWSError/invalidZoneIdentifier(_:)``.
The type is checked first, so the thrown case names which argument was unusable. A type or
identifier the service simply does not recognize is sent, and the service's answer arrives as
``NWSError/problem(_:)`` with its details.

## List the directory

```swift
let query = try ZoneQuery(areas: [.texas], limit: 10)
let forecastZones = try await weather.zones(matching: query, ofType: .forecast)
let countiesAndFireZones = try await weather.zones(matching: query, types: [.county, .fire])
let everything = try await weather.zones(matching: try ZoneQuery())
```

Two routes list zones, and both answer `FeatureCollection<WeatherZone>`:

- `/zones/{type}`, through `zones(matching:ofType:)`. The type is a path segment, and it is never
  repeated as a query filter.
- `/zones`, through `zones(matching:types:)`. The types are sent as a `type` query filter, and an
  empty array asks for every type. The parameter defaults to an empty array.

`ZoneQuery` carries the filters both routes share. It takes no arguments by default, so an
unfiltered directory is `try ZoneQuery()`. Empty arrays and nil options omit their parameters, and
array filters are sent comma separated in the order supplied:

| Filter | Sent as | Meaning |
|---|---|---|
| `ZoneQuery.areas` | `area` | State, territory, and marine area codes. The service validates the vocabulary. |
| `ZoneQuery.effective` | `effective` | The instant the definitions must be effective at, in ISO 8601 UTC at whole-second precision. |
| `ZoneQuery.identifiers` | `id` | Zone identifiers, in the order supplied. |
| `ZoneQuery.includesGeometry` | `include_geometry` | Whether to ask for geometry. An explicit `false` is sent; nil omits the parameter. |
| `ZoneQuery.limit` | `limit` | The maximum number of zones for the response. Less than 1 throws `ZoneQuery.ValidationError.invalidLimit` at construction. |
| `ZoneQuery.point` | `point` | A coordinate the zones must contain, at the four decimal places the service accepts. |
| `ZoneQuery.regions` | `region` | Land and marine region codes, as `ZoneRegionCode` values. |

The zone directory supports no cursor. The service declares no page size, default, or cursor for it,
and the recorded responses carry no continuation, so a list is one request and one response, capped
by whatever limit the query names. There are no zone page or feature sequences. See
<doc:PaginatingCollections> for the collections that do continue.

`ZoneQuery.includesGeometry` states what the request asks for, not what comes back. The recorded
directory responses list every zone with a `null` geometry, so `Feature.geometry` is nil in a
directory result even when geometry was requested. The single-zone route carries the polygon.

## Choose an access level

Each operation has the same spelling at all three levels:

| Operation | Everyday method | Reusable request | Endpoint |
|---|---|---|---|
| One zone | `zone(effective:identifier:type:)` | `WeatherRequest.zone(effective:identifier:type:)` | `Endpoint.zone(effective:identifier:type:)` |
| One type's zones | `zones(matching:ofType:)` | `WeatherRequest.zones(matching:ofType:)` | `Endpoint.zones(matching:ofType:)` |
| Every type's zones | `zones(matching:types:)` | `WeatherRequest.zones(matching:types:)` | `Endpoint.zones(matching:types:)` |

Every level also accepts a String-backed type of your own in place of `ZoneType`:

```swift
enum AppZoneType: String {
  case county
  case forecast
}

let mine = try await weather.zones(matching: query, ofType: AppZoneType.forecast)
```

Each request asks for `application/geo+json` and sends no units query and no `Feature-Flags` header.
Identifiers and types are encoded as exactly one path segment each and are otherwise passed to the
service unchanged, including their case. Redirects, cancellation checks, problem-detail mapping, and
transport behavior are the same as every other endpoint request.

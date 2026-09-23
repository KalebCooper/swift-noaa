# Decoding zone data

Decode the forecast, county, fire weather, and marine zones the service describes, their text
forecasts, and a forecast zone's observations and stations, with any networking stack.

## Overview

A zone is a named area the service issues products for. `/zones/{type}/{zoneId}` describes one, and
`/zones` and `/zones/{type}` list them. Both shapes decode through ``WeatherZone``: the detail route
as `Feature<WeatherZone>`, the directory routes as `FeatureCollection<WeatherZone>`.

Three more routes hang off a zone. `/zones/{type}/{zoneId}/forecast` decodes as
`Feature<ZoneForecast>`, and a forecast zone's `/observations` and `/stations` decode as the same
`FeatureCollection<WeatherObservation>` and `FeatureCollection<ObservationStation>` the station
routes use.

```swift
import SwiftNWSModels

guard let endpoint = Endpoint.zone(identifier: "TXZ192", type: .forecast) else { return }
print(endpoint.path)             // "/zones/forecast/TXZ192"
print(endpoint.accept.rawValue)  // "application/geo+json"

// Send a GET to https://api.weather.gov plus endpoint.path with that Accept header and a
// User-Agent identifying your application, then:
let feature = try JSONDecoder().decode(Feature<WeatherZone>.self, from: body)
print(feature.properties.name, feature.geometry != nil)  // "Travis true"
```

Build a directory endpoint from a ``ZoneQuery``. The query takes no arguments by default, so
`try ZoneQuery()` asks for every zone the service is willing to return:

```swift
let query = try ZoneQuery(areas: [.texas], limit: 2)
let everyType = Endpoint.zones(matching: query, types: [.county])
let oneType = Endpoint.zones(matching: query, ofType: .forecast)
print(everyType.path)     // "/zones?area=TX&limit=2&type=county"
print(oneType?.path as Any)  // "/zones/forecast?area=TX&limit=2"
```

The root factory is not failable because its path carries no type segment. The typed factory and
`Endpoint.zone(identifier:type:effective:)` return nil for a type or identifier that cannot be one
path segment, such as an empty string or a value whose encoded form would change the route.

The directory declares no page size, default, or cursor, and the recorded responses carry no
`pagination`, so one request answers a query in full, capped by its limit. Do not synthesize a
continuation for it.

Follow a zone URL the service already gave you rather than rebuilding its path. An alert's
`affectedZones`, a station's zone links, and a zone's own `id` are absolute URLs:

```swift
guard let link = alert.properties.affectedZones.first,
  let endpoint = Endpoint<Feature<WeatherZone>>(link: link)
else { return }
print(endpoint.path)
```

The initializer accepts only HTTPS links on `api.weather.gov` without credentials or a fragment, and
returns nil otherwise. A link it rejects must not be followed. The same initializer handles any link
the service returns, at whatever response type that link answers. A zone's own office links are kept
as data for that reason: office resources have no models in this package yet, and holding a URL is
not permission to follow it blindly.

## Forecasts

`/zones/{type}/{zoneId}/forecast` answers a feature whose geometry is the zone's polygon and whose
properties decode as ``ZoneForecast``:

```swift
guard let endpoint = Endpoint.zoneForecast(identifier: "TXZ192", type: .forecast) else { return }
print(endpoint.path)  // "/zones/forecast/TXZ192/forecast"

let forecast = try JSONDecoder().decode(Feature<ZoneForecast>.self, from: body).properties
print(forecast.updated, forecast.periods.count)
```

| Property | Type | Notes |
|---|---|---|
| ``ZoneForecast/periods`` | `[ZoneForecastPeriod]` | The periods in service order. |
| ``ZoneForecast/updated`` | `Date` | When the service last updated the forecast. |
| ``ZoneForecast/zone`` | `URL` | A link to the zone the forecast covers. |
| ``ZoneForecastPeriod/detailedForecast`` | `String` | The period's forecast text. |
| ``ZoneForecastPeriod/name`` | `String` | The period's name, such as `This Afternoon`. |
| ``ZoneForecastPeriod/number`` | `Int` | The period's number, as the service assigned it. |

All six values are required, and a response missing one fails to decode. A period carries no start
or end time, temperature, wind, or probability of precipitation, because the route accepts no units
query and no feature flags and the service sends none of them. Do not derive a twelve-hour period
from a name or renumber the periods; ``ZoneForecast/updated`` decodes as ISO 8601 regardless of the
decoder's date strategy, as the zone dates do.

## Observations and stations

A forecast zone's observations and stations are separate single-response routes:

```swift
let query = try ZoneObservationQuery(limit: 2, zoneIdentifier: "TXZ192")
print(Endpoint.observations(inForecastZone: query).path)
// "/zones/forecast/TXZ192/observations?limit=2"
print(Endpoint.observationStations(inForecastZone: "TXZ192")?.path as Any)
// "/zones/forecast/TXZ192/stations"

let readings = try JSONDecoder().decode(FeatureCollection<WeatherObservation>.self, from: body)
```

``ZoneObservationQuery`` validates its zone identifier and a limit from 1 through 500 at
construction, sends window bounds as whole-second ISO 8601 instants in UTC, and omits the limit when
none is given. The observations come from the stations the service associates with the zone, so one
response can carry several stations, and the service decides which readings a window matches and in
what order they arrive. The station route declares a limit and a cursor that the recorded responses
ignored, so the named factory sends neither.

Neither route continues. The observations response links to one station's observation history, which
drops the rest of the zone, and the stations response links to the same stations again at a later
offset and then to empty pages. Read both links as provider metadata: do not follow them, do not
synthesize a cursor, and do not rebuild a zone's list out of individual station histories.

## Fields

The identifier, name, and reported type are always present. Every other field is optional, because
the service omits or nulls some of them for some zones.

| Property | Type | Notes |
|---|---|---|
| ``WeatherZone/awipsLocationIdentifier`` | `String?` | The AWIPS location identifier of the responsible office, such as `EWX`. |
| ``WeatherZone/cwa`` | `[String]?` | County warning area identifiers. The service has deprecated the field and still sends it. |
| ``WeatherZone/effectiveDate`` | `Date?` | When this definition took effect. |
| ``WeatherZone/expirationDate`` | `Date?` | When this definition expires. A current definition carries a far-future date, such as the year 2200. |
| ``WeatherZone/forecastOffice`` | `URL?` | A link to the responsible forecast office. |
| ``WeatherZone/forecastOffices`` | `[URL]?` | Links to the responsible offices. Deprecated by the service and still sent. |
| ``WeatherZone/gridIdentifier`` | `String?` | The forecast grid identifier of the responsible office. |
| ``WeatherZone/id`` | `String` | The zone's identifier, such as `TXZ192`. |
| ``WeatherZone/name`` | `String` | The zone's name, such as `Travis`. |
| ``WeatherZone/observationStations`` | `[URL]?` | Station links in the order the service listed them. |
| ``WeatherZone/radarStation`` | `String?` | The radar station covering the zone. |
| ``WeatherZone/state`` | `AreaCode?` | The state or territory the zone is in. |
| ``WeatherZone/timeZone`` | `[String]?` | The IANA time zone identifiers the zone spans. |
| ``WeatherZone/type`` | ``ZoneType`` | The zone's reported type, which can differ from the route it was requested through. |

Values are kept as the service sends them, and absence and emptiness stay distinct:

- A recorded county zone sends `observationStations: []` and `radarStation: null`. The first decodes
  as an empty array and the second as nil. An empty list of stations is not the same answer as no
  radar station at all.
- A recorded marine zone sends no `state`, so ``WeatherZone/state`` is nil. An empty string is also
  a value the service sends, and it is preserved as `AreaCode(rawValue: "")` rather than collapsed
  into nil.
- Dates decode as ISO 8601 regardless of the decoder's date strategy, and re-encode as ISO 8601.
- Unknown zone types, region codes, and state codes survive a round trip in their `rawValue`.

## Geometry

``Feature/geometry`` retains the feature's GeoJSON geometry as ``JSONValue``, exactly as the service
sent it. Nothing validates or interprets it: there are no coordinate, ring, or polygon types, and no
spatial computation.

```swift
if case .object(let geometry) = feature.geometry, case .string(let kind) = geometry["type"] {
  print(kind)  // "Polygon"
}
```

A zone detail response carries a polygon. A directory response does not: the recorded lists send
`"geometry": null` for every zone, so ``Feature/geometry`` is nil there even when
``ZoneQuery/includesGeometry`` asked for geometry. Read the option as what the request states, never
as a promise about the answer. A missing or JSON-null geometry is nil in both cases.

## Extensible codes

``ZoneType`` and ``ZoneRegionCode`` are open String-backed codes. Their static members match the live
schema, and an unrecognized value the service adds later is kept in `rawValue` rather than failing to
decode. Both accept a String-backed value of your own through `init(_:)`.

``ZoneType`` names the eight values the schema lists, including the route types `forecast` and
`marine` and the reported types `county`, `coastal`, `fire`, `land`, `offshore`, and `public`. The
member for the last of those is spelled with backticks in a declaration, and reads as `.public` at a
call site.

``ZoneRegionCode`` covers both halves of the directory's `region` filter. The six marine members
share their names and codes with ``MarineRegionCode``, which it converts from directly, and the six
land members name the NWS regional headquarters and end in `Region`:

```swift
let query = try ZoneQuery(regions: [.easternRegion, .gulfOfMexico])
let marine = ZoneRegionCode(MarineRegionCode.atlantic)
```

## Topics

### Zones

- ``WeatherZone``
- ``ZoneForecast``
- ``ZoneForecastPeriod``
- ``ZoneObservationQuery``
- ``ZoneQuery``
- ``ZoneRegionCode``
- ``ZoneType``

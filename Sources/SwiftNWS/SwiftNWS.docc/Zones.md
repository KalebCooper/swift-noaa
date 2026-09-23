# Reading zones

Look up one zone or its text forecast, list the zone directory, and read the observations and
stations of a forecast zone.

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

## Read a zone's forecast

```swift
let forecast = try await weather.zoneForecast(identifier: "TXZ192", type: .forecast)
print(forecast.updated, forecast.zone)
for period in forecast.periods {
  print(period.number, period.name, period.detailedForecast)
}

let reusable = try await weather.value(for: .zoneForecast(identifier: "TXZ192", type: .forecast))
if let endpoint = Endpoint.zoneForecast(identifier: "TXZ192", type: .forecast) {
  let feature = try await weather.send(endpoint)
  print(feature.geometry as Any)
}
```

`zoneForecast(identifier:type:)` sends one request to `/zones/{type}/{zoneId}/forecast` and returns
the feature's `ZoneForecast` properties: when the service last updated the forecast, a link to the
zone it covers, and the periods in the order the service listed them. The direct endpoint keeps the
GeoJSON envelope, so the zone's polygon stays available in `Feature.geometry`.

A zone forecast period is text. It carries a number, a name such as `This Afternoon`, and one
detailed forecast paragraph, and nothing else. There are no start or end times, no temperature, no
wind, and no twelve-hour duration to read out of the name. The route accepts neither a units query
nor a `Feature-Flags` header, so the wording and the units inside the text are the service's own.
Period numbers are the service's too: the client does not renumber, reorder, or fill a gap in them.
For typed forecast values, read a coordinate's forecast instead, through <doc:Forecasts> or
<doc:ForecastGrids>.

Type and identifier validation is the same as the single-zone lookup, including the String-backed
type overload and the order the two errors are reported in.

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

## Read a forecast zone's observations

```swift
let query = try ZoneObservationQuery(limit: 10, zoneIdentifier: "TXZ192")
let readings = try await weather.observations(inForecastZone: query)
for reading in readings.features {
  print(reading.properties.station, reading.properties.timestamp)
}

let direct = try await weather.send(.observations(inForecastZone: query))
```

`observations(inForecastZone:)` sends one request to `/zones/forecast/{zoneId}/observations` and
returns the `FeatureCollection<WeatherObservation>` unchanged. The readings come from the stations
the service associates with the zone, so one response can carry several stations, and each feature's
properties are the same `WeatherObservation` every other observation method returns.

`ZoneObservationQuery` names the zone and carries an optional `start`, an optional `end`, and an
optional limit from 1 through 500. Window bounds are sent as ISO 8601 instants in UTC at
whole-second precision, and an absent bound leaves that side of the window open. A nil limit omits
the parameter, so the service applies its own size. A limit outside 1 through 500, or an empty or
unusable zone identifier, throws `ZoneObservationQuery.ValidationError` at construction, before
anything is sent. The service decides which stations and observations a window matches and in what
order it returns them.

This list is one response. The recorded response carries a continuation link, but that link does not
continue the zone's list: it names one station's observation history, which drops every other
station in the zone. The client never follows it, and the route accepts no cursor to send in its
place. Reading more of one station's history is <doc:ObservationHistory>, a separate collection whose
continuation is verified.

## List a forecast zone's stations

```swift
let stations = try await weather.observationStations(inForecastZone: "TXZ192")
for station in stations.features {
  print(station.properties.stationIdentifier, station.properties.name)
}

let request = WeatherRequest.observationStations(inForecastZone: "TXZ192")
for try await station in weather.observationStations(for: request) {
  print(station.properties.stationIdentifier)
}
```

`observationStations(inForecastZone:)` sends one request to `/zones/forecast/{zoneId}/stations` and
returns the `FeatureCollection<ObservationStation>` in the service's order. An empty or unusable
identifier throws ``NWSError/invalidZoneIdentifier(_:)`` before any request.

This list is one response too. The service declares a limit from 1 through 500 and a cursor for the
route, but the recorded responses returned the same stations whether a limit, a cursor, or neither
was sent, so neither control is offered in the named factory. The page's continuation link names
every station again at a later offset and leads only to empty pages, each carrying another link, so
the client never follows it. Passing the request to ``NWSClient/observationStationPages(for:)`` or
``NWSClient/observationStations(for:)`` resolves the identifier on the first read, yields that one
page, and finishes: the sequences are an adapter over a single response here, not pagination. To
send the declared parameters anyway, build the path with `Endpoint(path:)` and wrap it in
`WeatherRequest(endpoint:)`, which also reads as one response.

## Choose an access level

Each operation has the same spelling at all three levels:

| Operation | Everyday method | Reusable request | Endpoint |
|---|---|---|---|
| One zone | `zone(effective:identifier:type:)` | `WeatherRequest.zone(effective:identifier:type:)` | `Endpoint.zone(effective:identifier:type:)` |
| One type's zones | `zones(matching:ofType:)` | `WeatherRequest.zones(matching:ofType:)` | `Endpoint.zones(matching:ofType:)` |
| Every type's zones | `zones(matching:types:)` | `WeatherRequest.zones(matching:types:)` | `Endpoint.zones(matching:types:)` |
| A zone's forecast | `zoneForecast(identifier:type:)` | `WeatherRequest.zoneForecast(identifier:type:)` | `Endpoint.zoneForecast(identifier:type:)` |
| A forecast zone's observations | `observations(inForecastZone:)` | `WeatherRequest.observations(inForecastZone:)` | `Endpoint.observations(inForecastZone:)` |
| A forecast zone's stations | `observationStations(inForecastZone:)` | `WeatherRequest.observationStations(inForecastZone:)` | `Endpoint.observationStations(inForecastZone:)` |

The request factories always return a request. An unusable type or identifier is reported when the
request executes, not when it is created, so a stored request is a plain value in every case. The
endpoint factories differ: `Endpoint.zones(matching:types:)` is not failable because its path has no
type segment, and `Endpoint.observations(inForecastZone:)` is not failable because its query
validated the zone identifier at construction, while `Endpoint.zones(matching:ofType:)`,
`Endpoint.zone(effective:identifier:type:)`, `Endpoint.zoneForecast(identifier:type:)`, and
`Endpoint.observationStations(inForecastZone:)` return nil for a type or identifier that cannot be
one path segment.

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

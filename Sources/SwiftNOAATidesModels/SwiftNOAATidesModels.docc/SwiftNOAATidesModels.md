# ``SwiftNOAATidesModels``

Portable CO-OPS station and tide models with request descriptions, without networking dependencies.

## Overview

Use ``CoastalStationQuery`` to select a station directory and ``CoastalStationIdentifier`` to
select a station explicitly. ``TidesEndpoint`` describes a single JSON request, and
``TidesRequest`` describes the useful result. Both are immutable, Hashable, Sendable values.

```swift
let query = try CoastalStationQuery(type: .tidePredictions)
let request = TidesRequest.stations(matching: query)
let identifier = try CoastalStationIdentifier("9414290")
let detail = TidesRequest.station(identifier: identifier)
```

Directory and detail endpoints both decode ``CoastalStations`` using an ordinary JSONDecoder.
A useful detail request unwraps exactly one matching station; missing, plural, mismatched, or
malformed responses are errors. Names, provider order, empty strings, unknown kinds, capability
indicators, and optional resource links retain the provider representation. No resource is fetched
automatically. Time zone labels and offsets are metadata, not IANA zones.

## Predicted high and low tides

```swift
let range = try TidesDateRange(
  begin: TidesTimestamp("2026-09-26 00:00").date,
  end: TidesTimestamp("2026-09-27 23:59").date
)
let query = try HighLowTideQuery(
  datum: .meanLowerLowWater, range: range,
  stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric
)
let request = TidesRequest.highLowTides(matching: query)
```

The useful result keeps events with `requestedQuery`. This context is requested, not echoed by
NOAA. Direct endpoint responses decode independently with an ordinary JSONDecoder and no userInfo.
Timestamps are strict GMT minutes; custom date-decoding strategies do not change their interpretation.
Both range bounds are inclusive. The high/low window is limited to ten Gregorian calendar years,
including leap-day handling; no date rounding, splitting, interpolation, or extrema calculation occurs.
Metric heights are meters and English heights are feet, relative to the explicitly requested datum.
Numeric strings retain their exact spelling; missing or malformed required values fail decoding.

Subordinate tide stations require MLLW and support high/low predictions only. The client performs no
capability preflight or station substitution. A provider refusal for no data remains an error,
including at HTTP 200, and differs from a successfully decoded empty event array.

## Topics

### Stations

- ``CoastalStation``
- ``CoastalStationIdentifier``
- ``CoastalStationKind``
- ``CoastalStationQuery``
- ``CoastalStations``
- ``CoastalStationType``
- ``CoastalResource``

### Requests and errors

- ``TidesEndpoint``
- ``TidesProviderError``
- ``TidesQueryError``
- ``TidesRequest``

### High and low tides

- ``HighLowTide``
- ``HighLowTideQuery``
- ``HighLowTideResponse``
- ``HighLowTides``
- ``TideDatum``
- ``TideEventKind``
- ``TidesDateRange``
- ``TidesNumericValue``
- ``TidesTimestamp``
- ``TidesUnits``

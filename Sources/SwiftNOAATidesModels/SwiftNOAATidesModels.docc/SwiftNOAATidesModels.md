# ``SwiftNOAATidesModels``

Portable CO-OPS station models and request descriptions, without networking dependencies.

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

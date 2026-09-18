# ``SwiftNWS``

Retrieve current conditions, forecasts, and active alerts through a typed National Weather Service client.

## Overview

Use ``NWSClient/latestObservation(from:)`` for an explicit station or for the first station
listed for a coordinate. The method delegates to ``NWSClient/value(for:)``, which executes a
portable request through the same ``NWSClient/send(_:)`` endpoint path.

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(myweatherapp.com, contact@myweatherapp.com)")
let home = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
let observation = try await weather.latestObservation(from: .nearest(to: home))
print(observation.stationId, observation.timestamp)
```

The short initializer uses the shared URL session on Apple platforms. For a custom session or
transport, use a configuration-based initializer. A User-Agent identifying your application and
a contact is required; there is no default identity.

Every observation method returns the full `WeatherObservation`, including present weather,
cloud layers, the raw METAR message, and precipitation totals, exactly as the service reported
them.

Coordinate lookups follow the point's station-list link, then fetch the first listed station's
latest observation. The service does not guarantee distance ordering. The client does not reject
old observations, try fallback stations, or fetch more station pages. Coordinate lookups share
``PointCache``; direct endpoint requests bypass it.

Twelve-hour and hourly forecasts follow the point's links. Active alerts support coordinates,
areas, marine regions, zones, and provider filters, with a national count and the list of
recognized event types, and alert history adds a time window, page size, and cursor. Observation history
reads a station's past observations over a window. ``NWSClient/observationStation(identifier:)`` reads
one station's metadata, and ``NWSClient/observation(stationIdentifier:timestamp:)`` reads the
observation a station made at an exact instant. Active-alert, alert-history, station-directory,
and observation-history page and feature sequences follow validated continuation links on demand.
The station directory is the canonical implementation. Existing single-page methods do not
automatically paginate.

## Topics

### Client and errors

- ``ActiveAlertPageSequence``
- ``ActiveAlertSequence``
- ``AlertPageSequence``
- ``AlertSequence``
- ``NWSClient``
- ``NWSConfiguration``
- ``NWSError``
- ``ObservationPageSequence``
- ``ObservationSequence``
- ``ObservationStationPageSequence``
- ``ObservationStationSequence``
- ``PointCache``

### Request execution

- <doc:ActiveAlerts>
- <doc:AlertHistory>
- <doc:Forecasts>
- <doc:ObservationHistory>
- <doc:ObservationStations>
- <doc:PaginatingCollections>
- <doc:Units>
- <doc:UsingRequests>

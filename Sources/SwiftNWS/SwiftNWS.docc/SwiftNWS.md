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

Twelve-hour and hourly forecasts follow the point's links, and
``NWSClient/forecastGrid(for:)`` follows its raw grid data link to every forecast layer. Active alerts support coordinates,
areas, marine regions, zones, and provider filters, with a national count and the list of
recognized event types, and alert history adds a time window, page size, and cursor. Observation history
reads a station's past observations over a window. ``NWSClient/observationStation(identifier:)`` reads
one station's metadata, ``NWSClient/observationStations(near:)`` lists the stations near a
coordinate as one page, and ``NWSClient/observation(stationIdentifier:timestamp:)`` reads the
observation a station made at an exact instant. Six zone routes read `/zones`, `/zones/{type}`,
`/zones/{type}/{zoneId}`, a zone's text forecast, and a forecast zone's observations and stations,
each as one response. ``NWSClient/glossary()`` reads the service's glossary of weather terms, whose
definitions arrive as the service wrote them, markup included. ``NWSClient/office(identifier:)``
reads a forecast office's metadata, and ``NWSClient/officeHeadlines(officeIdentifier:)`` and
``NWSClient/officeHeadline(identifier:officeIdentifier:)`` read the editorial headlines it publishes,
with their content left as unrendered HTML. ``NWSClient/officeBriefing(officeIdentifier:)`` reads
the metadata for an office's current briefing, or nil when there is none. Briefing documents
and weather stories are not supported, and no PDF or image is downloaded. Four product catalog
routes name what the service issues: ``NWSClient/productTypes()`` and
``NWSClient/productLocations()`` read the whole catalog of product codes and of location
identifiers, and ``NWSClient/productLocations(for:)-(ProductCode)`` and
``NWSClient/productTypes(at:)`` narrow each one by the other. A catalog names what exists; the
routes that return a product's text are not yet built. Active-alert,
alert-history, station-directory, and observation-history page and feature sequences follow validated
continuation links on demand.
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
- <doc:ForecastGrids>
- <doc:Forecasts>
- <doc:Glossary>
- <doc:ObservationHistory>
- <doc:ObservationStations>
- <doc:Offices>
- <doc:PaginatingCollections>
- <doc:Products>
- <doc:Units>
- <doc:UsingRequests>
- <doc:Zones>

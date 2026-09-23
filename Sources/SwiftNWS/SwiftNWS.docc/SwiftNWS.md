# ``SwiftNWS``

Retrieve observations, forecasts, alerts, and the rest of the National Weather Service API through
a typed client.

## Overview

``NWSClient`` sends the requests that `SwiftNWSModels` describes. It follows the links between
responses, pages collections on demand, validates every link and redirect before following it, and
maps each failure into one typed ``NWSError``.

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(myweatherapp.com, contact@myweatherapp.com)")
let home = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
let observation = try await weather.latestObservation(from: .nearest(to: home))
print(observation.stationId, observation.timestamp)
```

The service rejects a request without a User-Agent naming your application and a contact, so the
client requires one and has no default identity. The short initializer sends through the shared URL
session on Apple platforms. A configuration-based initializer takes a custom session or transport,
a ``PointCache``, an opt-in retry policy for the service's transient failures, and the clock that
times its waits.

Every operation is available at three levels that share one executor: an everyday method such as
``NWSClient/forecast(for:options:)``, a reusable `WeatherRequest` executed by
``NWSClient/value(for:)``, and the individual `Endpoint` values sent by ``NWSClient/send(_:)``.

### What the client does not do

The client keeps what the service sends. Lists keep service order, readings keep their WMO unit
codes, `null` values stay `nil`, and unknown codes stay in `rawValue`. It does not sort, filter,
deduplicate, or convert, and it infers no ordering, freshness, or completeness the service does not
promise: a coordinate's first listed station is not guaranteed to be the closest, and an old
observation is returned as it is. Apart from ``PointCache``, it caches no responses; see
<doc:UsingRequests#HTTP-caching>.

Aviation, radar, and terminal aerodrome forecast routes are not yet built. XML and plain-text
representations (CAP XML and Atom alerts, radio speech synthesis documents, and `text/plain`
products) are not supported, and no PDF or image is downloaded.

## Topics

### Essentials

- ``NWSClient``
- ``NWSConfiguration``
- ``NWSError``
- <doc:UsingRequests>

### Observations and stations

- <doc:ObservationStations>
- <doc:ObservationHistory>
- <doc:Units>

### Forecasts

- <doc:Forecasts>
- <doc:ForecastGrids>
- <doc:Zones>

### Alerts

- <doc:ActiveAlerts>
- <doc:AlertHistory>

### Offices, products, and the glossary

- <doc:Offices>
- <doc:Products>
- <doc:Glossary>

### Paging collections

- <doc:PaginatingCollections>
- ``ActiveAlertPageSequence``
- ``ActiveAlertSequence``
- ``AlertPageSequence``
- ``AlertSequence``
- ``ObservationPageSequence``
- ``ObservationSequence``
- ``ObservationStationPageSequence``
- ``ObservationStationSequence``

### Caching

- ``PointCache``

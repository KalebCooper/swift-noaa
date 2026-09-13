# ``SwiftNWS``

Retrieve current conditions and forecasts through a typed National Weather Service client.

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

Coordinate lookups follow the point's station-list link, then fetch the first listed station's
latest observation. The service does not guarantee distance ordering. The client does not reject
old observations, try fallback stations, cache points, or fetch more station pages.

Twelve-hour and hourly forecasts follow the point's links. Alerts, point caching, and
pagination are not yet built.

## Topics

### Client and errors

- ``NWSClient``
- ``NWSConfiguration``
- ``NWSError``

### Request execution

- <doc:Forecasts>
- <doc:UsingRequests>

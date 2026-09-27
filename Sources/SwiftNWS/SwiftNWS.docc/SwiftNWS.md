# ``SwiftNWS``

Fetch weather observations, forecasts, and alerts from the National Weather Service with Swift
and `async`/`await`.

## Overview

Start with ``NWSClient`` and a coordinate. The client handles the requests needed to find your
forecast, follows service links, and reports failures as ``NWSError``.

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(MyWeatherApp, contact@example.com)")
let location = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
let forecast = try await weather.forecast(for: location)

for period in forecast.periods {
  print(period.name ?? "Forecast", period.shortForecast)
}
```

No API key is needed. Set the User-Agent to your app's name and a contact. The initializer above
uses the shared URL session on Apple platforms; use a `transport:` initializer for other platforms
or a custom networking setup.

### Choose a guide

- Read current and past observations with <doc:ObservationHistory>, find stations with
  <doc:ObservationStations>, and convert measurements with <doc:Units>.
- Get daily and hourly forecasts with <doc:Forecasts>, or explore individual layers with
  <doc:ForecastGrids>.
- Find current warnings with <doc:ActiveAlerts> and earlier notices with <doc:AlertHistory>.
- Explore <doc:Zones>, <doc:Offices>, text bulletins in <doc:Products>, and the <doc:Glossary>.

For larger collections, see <doc:PaginatingCollections>. To store requests, customize networking,
or configure caching and retries, see <doc:UsingRequests>.

### Working with service data

Responses keep the service's order, unit codes, and unknown code values. Missing readings stay
`nil`. Observation lookups using `.nearest(to:)` select the first station NWS returns, without a
distance or freshness guarantee. Check the observation's station and timestamp when those matter
to your app.

The client supports JSON responses. Aviation and radar routes, XML representations, and PDF or
image downloads are not yet supported.

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

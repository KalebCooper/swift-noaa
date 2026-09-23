# ``SwiftNWSModels``

Describe weather requests and decode National Weather Service responses with any networking stack.

## Overview

This product has no SDK or third-party dependency and imports no networking module. It provides:

- ``Endpoint`` values, each one HTTP request: a validated path with its query, the media type to
  ask for, and any forecast feature flags, typed by the response it decodes.
- ``WeatherRequest`` values, each one operation. A request wraps an endpoint or describes a
  multi-step lookup in its public ``WeatherRequest/resolution``, such as resolving a coordinate's
  point before reading its forecast, so any executor can carry it out.
- Validated inputs, such as ``WeatherCoordinate``, ``AlertQuery``, and ``ProductQuery``, that reject
  a bad value when they are created rather than when a request is sent.
- `Codable` models for every supported response, including the GeoJSON ``Feature`` and
  ``FeatureCollection`` envelopes and the service's ``ProblemDetail`` errors.

```swift
let endpoint = Endpoint.point(for: try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431))
// GET https://api.weather.gov/points/30.2672,-97.7431
// Accept: application/geo+json
```

A consumer with its own networking stack sends the endpoint with a User-Agent of its own and decodes
the body as the endpoint's response type. <doc:ExecutingRequests> covers every resolution case,
continuation links, and the point cache policy. The `SwiftNWS` SDK does all of this for you.

### What the models keep

The models preserve what the service sends. Quantities keep their WMO unit code and nullable value
without conversion, and the `SwiftNWS` SDK adds Foundation measurement conversion. Provider codes
are open values: named static members cover the live schema, and `rawValue` keeps any code the
service adds later. A String-backed enum of your own can be passed wherever a code is accepted.
Lists keep service order, fields the service omits or sends as `null` stay `nil`, and text such as
glossary definitions, headline content, and product bulletins is kept exactly as sent, markup and
line endings included.

## Topics

### Essentials

- ``Endpoint``
- ``WeatherRequest``
- ``MediaType``
- ``Feature``
- ``FeatureCollection``
- ``ProblemDetail``
- ``JSONValue``
- <doc:ExecutingRequests>

### Locations and observations

- ``WeatherCoordinate``
- ``WeatherPoint``
- ``ObservationSource``
- ``WeatherObservation``
- ``WeatherPhenomenon``
- ``WeatherPhenomenonIntensity``
- ``WeatherPhenomenonKind``
- ``WeatherPhenomenonModifier``
- ``CloudLayer``
- ``CloudLayerAmount``
- ``ObservationQuery``

### Stations

- ``ObservationStation``
- ``ObservationStationQuery``

### Forecasts

- ``WeatherForecast``
- ``ForecastPeriod``
- ``ForecastOptions``
- ``ForecastUnits``
- ``ForecastFeatureFlag``
- ``ForecastTemperature``
- ``ForecastTemperatureTrend``
- ``ForecastTemperatureUnit``
- ``ForecastWind``
- ``ForecastWindDirection``

### Forecast grids

- <doc:ForecastGridData>
- ``ForecastGrid``
- ``ForecastGridLayer``
- ``ForecastGridLayerName``
- ``ForecastGridValue``
- ``ForecastHazard``
- ``ForecastWeather``
- ``ForecastWeatherAttribute``
- ``ForecastWeatherCoverage``
- ``ForecastWeatherIntensity``
- ``ForecastWeatherPhenomenon``

### Alerts

- ``WeatherAlert``
- ``ActiveAlertFilter``
- ``AlertQuery``
- ``ActiveAlertCount``
- ``AlertTypes``
- ``AlertReference``
- ``AreaCode``
- ``MarineRegionCode``
- ``AlertCategory``
- ``AlertCertainty``
- ``AlertMessageType``
- ``AlertResponse``
- ``AlertScope``
- ``AlertSeverity``
- ``AlertStatus``
- ``AlertUrgency``

### Zones

- <doc:ZoneData>
- ``WeatherZone``
- ``ZoneQuery``
- ``ZoneType``
- ``ZoneRegionCode``
- ``ZoneForecast``
- ``ZoneForecastPeriod``
- ``ZoneObservationQuery``

### Offices

- <doc:OfficeData>
- ``WeatherOffice``
- ``OfficeHeadlines``
- ``OfficeHeadline``
- ``OfficeBriefingResponse``
- ``OfficeBriefing``

### Products

- <doc:ProductData>
- ``TextProduct``
- ``TextProducts``
- ``ProductQuery``
- ``ProductCode``
- ``ProductTypes``
- ``ProductType``
- ``ProductLocations``

### Glossary

- <doc:GlossaryData>
- ``WeatherGlossary``
- ``GlossaryEntry``

### Quantities and time

- ``QuantitativeValue``
- ``QualityControlCode``
- ``ValidTimeInterval``
- ``ISO8601Duration``

### Pagination

- ``PaginationInfo``
- ``NWSPaginationError``

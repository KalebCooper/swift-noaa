# ``SwiftNWSModels``

Describe weather requests and decode National Weather Service responses with any networking stack.

## Overview

This product has no SDK or third-party networking dependency. It provides validated coordinates,
open station identifiers through ``ObservationSource``, typed ``WeatherRequest`` values,
single-HTTP ``Endpoint`` values, and portable response models.

Current conditions and forecasts are available. Forecast requests carry explicit typed units and
representation flags. Provider-enumerated codes are open values: named static members cover the
live schema while `rawValue` preserves additions. String-backed consumer enums can be passed to
request options and endpoints. Active alert factories support geographic and CAP filters, and
alert-history queries add a time window, page size, and cursor. Observation-history queries name a
station and a window.

Station-directory, active-alert, alert-history, and observation-history requests declare when a
custom executor may follow collection continuations. ``PaginationInfo`` validates a returned NWS link without adding an SDK or networking
dependency. A plain endpoint request remains one response.

Quantities preserve their WMO unit code and nullable value without conversion. The optional
`SwiftNWS` SDK adds Foundation measurement conversion and percentage fractions; these models do
not require full Foundation or a networking stack.

## Topics

### Request descriptions

- ``ActiveAlertFilter``
- ``AlertQuery``
- ``Endpoint``
- ``MediaType``
- ``ObservationQuery``
- ``ObservationSource``
- ``ObservationStationQuery``
- ``WeatherCoordinate``
- ``WeatherRequest``
- <doc:ExecutingRequests>

### Code values

- ``AlertCategory``
- ``AlertResponse``
- ``AlertScope``
- ``AreaCode``
- ``ForecastTemperatureTrend``
- ``ForecastTemperatureUnit``
- ``ForecastUnits``
- ``ForecastWindDirection``
- ``MarineRegionCode``
- ``NWSFeatureFlag``
- ``QualityControlCode``

### Response models

- ``AlertCertainty``
- ``AlertMessageType``
- ``AlertReference``
- ``AlertSeverity``
- ``AlertStatus``
- ``AlertUrgency``
- ``Feature``
- ``FeatureCollection``
- ``ForecastOptions``
- ``ForecastPeriod``
- ``ForecastTemperature``
- ``ForecastWind``
- ``JSONValue``
- ``ObservationStation``
- ``Point``
- ``ProblemDetail``
- ``QuantitativeValue``
- ``WeatherAlert``
- ``WeatherForecast``
- ``WeatherObservation``

### Pagination

- ``NWSPaginationError``
- ``PaginationInfo``

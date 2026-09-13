# ``SwiftNWSModels``

Describe weather requests and decode National Weather Service responses with any networking stack.

## Overview

This product has no SDK or third-party networking dependency. It provides validated coordinates,
open station identifiers through ``ObservationSource``, typed ``WeatherRequest`` values,
single-HTTP ``Endpoint`` values, and portable response models.

Current conditions and forecasts are available. Forecast requests carry explicit units and
representation flags. Active alert factories support geographic and CAP filters.

Quantities preserve their WMO unit code and nullable value without conversion. The optional
`SwiftNWS` SDK adds Foundation measurement conversion and percentage fractions; these models do
not require full Foundation or a networking stack.

## Topics

### Request descriptions

- ``ActiveAlertFilter``
- ``Endpoint``
- ``MediaType``
- ``ObservationSource``
- ``WeatherCoordinate``
- ``WeatherRequest``
- <doc:ExecutingRequests>

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

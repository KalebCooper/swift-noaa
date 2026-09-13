# ``SwiftNWSModels``

Describe weather requests and decode National Weather Service responses with any networking stack.

## Overview

This product has no SDK or third-party networking dependency. It provides validated coordinates,
open station identifiers through ``ObservationSource``, typed ``WeatherRequest`` values,
single-HTTP ``Endpoint`` values, and portable response models.

Current conditions and forecasts are available. Forecast requests carry explicit units and
representation flags. Alert request factories are not available yet.

## Topics

### Request descriptions

- ``Endpoint``
- ``MediaType``
- ``ObservationSource``
- ``WeatherCoordinate``
- ``WeatherRequest``
- <doc:ExecutingRequests>

### Response models

- ``Feature``
- ``FeatureCollection``
- ``ForecastOptions``
- ``ForecastPeriod``
- ``ForecastTemperature``
- ``ForecastWind``
- ``ObservationStation``
- ``Point``
- ``ProblemDetail``
- ``QuantitativeValue``
- ``WeatherForecast``
- ``WeatherObservation``

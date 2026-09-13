# ``SwiftNWSModels``

Describe weather requests and decode National Weather Service responses with any networking stack.

## Overview

This product has no SDK or third-party networking dependency. It provides validated coordinates,
open station identifiers through ``ObservationSource``, typed ``WeatherRequest`` values,
single-HTTP ``Endpoint`` values, and portable response models.

Only the current-conditions slice is built: points, their linked observation stations, and the
latest station observation. Forecast and alert request factories are not available yet.

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
- ``ObservationStation``
- ``Point``
- ``ProblemDetail``
- ``QuantitativeValue``
- ``WeatherObservation``

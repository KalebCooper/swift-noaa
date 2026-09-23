# ``SwiftNWSModels``

Describe weather requests and decode National Weather Service responses with any networking stack.

## Overview

This product has no SDK or third-party networking dependency. It provides validated coordinates,
open station identifiers through ``ObservationSource``, typed ``WeatherRequest`` values,
single-HTTP ``Endpoint`` values, and portable response models.

Current conditions and forecasts are available. Forecast requests carry explicit typed units and
representation flags. Provider-enumerated codes are open values: named static members cover the
live schema while `rawValue` preserves additions. String-backed consumer enums can be passed to
request options and endpoints. Active alert factories support geographic and CAP filters and the
area, marine region, and zone paths, and alert-history queries add a time window, page size, and
cursor. ``ActiveAlertCount`` and ``AlertTypes`` decode the JSON-LD count and event-type resources. Observation-history queries name a
station and a window. Station and timed-observation endpoints read one station's metadata and the
observation a station made at an exact instant.

Station-directory, active-alert, alert-history, and observation-history requests declare when a
custom executor may follow collection continuations. ``PaginationInfo`` validates a returned NWS link without adding an SDK or networking
dependency. A plain endpoint request remains one response.

``WeatherObservation`` decodes every field of the service's observation schema: the readings,
the station's elevation and link, the raw METAR message, 24-hour temperature extremes, one-,
three-, and six-hour precipitation, the decoded present weather as ``WeatherPhenomenon`` values,
and the reported ``CloudLayer`` values. A field the service omits stays `nil`.

``WeatherZone`` decodes a forecast, county, fire weather, or marine zone, from
`/zones/{type}/{zoneId}` or from the `/zones` and `/zones/{type}` directories that ``ZoneQuery``
filters. ``ZoneForecast`` decodes a zone's text forecast, whose ``ZoneForecastPeriod`` values carry
a number, a name, and forecast text and nothing else, and ``ZoneObservationQuery`` describes a
forecast zone's observations. Each zone route answers one response. ``Feature`` retains the
provider's GeoJSON geometry as raw ``JSONValue`` when the service sends one. See <doc:ZoneData>.

``ForecastGrid`` decodes a grid cell's raw forecast data: every quantitative layer keyed by an
open ``ForecastGridLayerName``, typed weather and hazards layers, and any layer or property the
package does not know yet. See <doc:ForecastGridData>.

Forecast and grid validity intervals decode as ``ValidTimeInterval``, an ISO 8601 start and duration whose
``ISO8601Duration`` keeps the text's calendar components and reports an exact length when it has
one. The exact text stays available as `rawValue`.

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
- ``ZoneObservationQuery``
- ``ZoneQuery``
- <doc:ExecutingRequests>

### Code values

- ``AlertCategory``
- ``AlertResponse``
- ``AlertScope``
- ``AreaCode``
- ``CloudLayerAmount``
- ``ForecastTemperatureTrend``
- ``ForecastTemperatureUnit``
- ``ForecastUnits``
- ``ForecastWindDirection``
- ``MarineRegionCode``
- ``NWSFeatureFlag``
- ``QualityControlCode``
- ``WeatherPhenomenonIntensity``
- ``WeatherPhenomenonKind``
- ``WeatherPhenomenonModifier``
- ``ZoneRegionCode``
- ``ZoneType``

### Response models

- ``ActiveAlertCount``
- ``AlertCertainty``
- ``AlertMessageType``
- ``AlertReference``
- ``AlertSeverity``
- ``AlertStatus``
- ``AlertTypes``
- ``AlertUrgency``
- ``CloudLayer``
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
- ``WeatherPhenomenon``
- ``WeatherZone``
- ``ZoneForecast``
- ``ZoneForecastPeriod``
- <doc:ZoneData>

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

### Time intervals

- ``ISO8601Duration``
- ``ValidTimeInterval``

### Pagination

- ``NWSPaginationError``
- ``PaginationInfo``

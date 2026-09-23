# Decoding forecast grid data

Decode the raw forecast grid behind the text forecasts, with any networking stack.

## Overview

A point's ``WeatherPoint/forecastGridData`` link names the grid cell's raw data,
`/gridpoints/{wfo}/{x},{y}`. Follow the link rather than building the path: the office identifier is
case sensitive, and the service answers a lowercase one with `404`.

```swift
let point = try JSONDecoder().decode(Feature<WeatherPoint>.self, from: pointBody).properties
// Request point.forecastGridData with Accept: application/geo+json, then:
let grid = try JSONDecoder().decode(Feature<ForecastGrid>.self, from: gridBody).properties
```

The service takes no `units` query and no `Feature-Flags` for grid data; it answers `units` with
`400`. Values are in the units each layer names. Only the GeoJSON representation is supported.

### Layers

Each quantitative layer is a ``ForecastGridLayer`` of `Double?` values keyed by its
``ForecastGridLayerName`` in ``ForecastGrid/layers``. Read one by name:

```swift
if let temperature = grid[.temperature] {
  print(temperature.unitCode ?? "no unit", temperature.values.count)
}
```

The grid distinguishes what the service sent:

- A layer the service omits has no entry. The service says some layers are not present in all areas.
- A layer the service sends with no values is present with an empty
  ``ForecastGridLayer/values``.
- A layer's ``ForecastGridLayer/unitCode`` is `nil` when the service names no unit, as it does for
  `heatRisk`. No unit is inferred.
- A value the service sends as `null` is `nil`. Values the service uses as sentinels, such as a
  negative ceiling height, are kept as sent.
- Values keep the service's order and intervals, and are never sorted, merged, or resampled.

A layer named anything other than the schema's names is kept in ``ForecastGrid/layers`` when it has
the quantitative shape, and in ``ForecastGrid/otherProperties`` as ``JSONValue`` otherwise. A named
layer that changes shape fails decoding.

The weather layer lists ``ForecastWeather`` values with open ``ForecastWeatherCoverage``,
``ForecastWeatherPhenomenon``, ``ForecastWeatherIntensity``, and ``ForecastWeatherAttribute`` codes.
A period with no expected weather is one value whose codes are all `nil`. The hazards layer lists
``ForecastHazard`` values with P-VTEC codes kept as strings.

To decode only the layers an application needs, decode a type of your own:

```swift
struct TemperatureOnly: Decodable {
  var temperature: ForecastGridLayer<Double?>
}
let slim = try JSONDecoder().decode(Feature<TemperatureOnly>.self, from: gridBody).properties
```

### Valid times

Every value applies over a ``ValidTimeInterval``: a start instant and an ``ISO8601Duration``, such
as `2026-09-17T17:00:00+00:00/PT3H`. The duration's components keep the text's own units, and
``ValidTimeInterval/end`` is available when the duration has no years or months. The exact text
stays in ``ValidTimeInterval/rawValue``.

The service's schema also allows a start and an end, a duration and an end, and `NOW`. The service
has only been observed to send a start and a duration, and the other forms are rejected: decoding
a grid with one fails with a `DecodingError` that names the value, rather than guessing.

### Units

Pair a quantitative value with its layer's unit through
``ForecastGridValue/quantity(unitCode:)`` to use the measurement conversion the `SwiftNWS` SDK
adds to ``QuantitativeValue``.

## Topics

### Grid data

- ``ForecastGrid``
- ``ForecastGridLayer``
- ``ForecastGridLayerName``
- ``ForecastGridValue``

### Weather and hazards

- ``ForecastHazard``
- ``ForecastWeather``
- ``ForecastWeatherAttribute``
- ``ForecastWeatherCoverage``
- ``ForecastWeatherIntensity``
- ``ForecastWeatherPhenomenon``

### Time intervals

- ``ISO8601Duration``
- ``ValidTimeInterval``

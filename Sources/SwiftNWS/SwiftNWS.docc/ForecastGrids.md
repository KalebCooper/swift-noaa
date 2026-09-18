# Reading raw forecast grid data

Retrieve every layer of a coordinate's forecast grid, with each value's valid time parsed.

## Overview

The raw forecast grid is the data behind the text forecasts: temperature, precipitation, wind, sky
cover, fire weather indices, marine layers, expected weather, and hazards, each as values over time
for one 2.5 km grid cell.

```swift
let grid = try await weather.forecastGrid(for: home)
if let temperature = grid[.temperature] {
  for entry in temperature.values {
    print(entry.validTime.start, entry.validTime.end as Any, entry.value ?? .nan)
  }
}
```

The same lookup is available at three levels:

- ``NWSClient/forecastGrid(for:)`` returns the grid.
- `WeatherRequest.forecastGrid(for:)` describes it as a reusable value for
  ``NWSClient/value(for:)``, returning the same grid.
- `Endpoint.forecastGrid(for:)` follows a decoded point's grid data link as one HTTP operation, for
  ``NWSClient/send(_:)`` or another networking stack. It keeps the GeoJSON feature envelope.

A lookup fetches the point, then follows its `forecastGridData` link. The link is validated rather
than rebuilt; a disallowed link throws ``NWSError/invalidLink(_:)`` without being sent.

### Layers

Quantitative layers are keyed by an open `ForecastGridLayerName`. Named members cover every layer in
the service's schema, and a layer the service adds later is kept under its own name. The service says
some layers are not present in all areas: a layer it omits has no entry, and a layer it sends with no
values is present with an empty value list.

Values keep the service's order, intervals, and `null`s. A layer's unit is the WMO unit code the
service names, or `nil` when it names none, as it does for `heatRisk`. Nothing is converted, sorted,
merged, or resampled, and sentinel values the service uses are kept as sent. To convert a value, pair
it with its layer's unit and use the measurement adapter described in <doc:Units>:

```swift
if let layer = grid[.temperature], let entry = layer.values.first,
  let quantity = entry.quantity(unitCode: layer.unitCode)
{
  let fahrenheit = quantity.measurement(in: UnitTemperature.fahrenheit)
}
```

The weather layer lists expected phenomena with open coverage, phenomenon, intensity, and attribute
codes; a period with no expected weather is a value whose codes are all `nil`. The hazards layer lists
P-VTEC phenomenon and significance codes, and an empty hazards layer means nothing is in effect.

### Valid times

Each value applies over a `ValidTimeInterval`, a start instant and an `ISO8601Duration` such as
`PT3H` or `P1DT19H`. Its `end` is available when the duration has no years or months. Interval
lengths vary within one layer. The package does not pick the value in effect at a given instant,
because the service does not say how overlapping or missing intervals resolve.

### What the service does and does not guarantee

The service takes no `units` query and no feature flags for grid data, and answers a `units` query
with `400`. Only the GeoJSON representation is supported. The grid's `updateTime` says when it last
changed; the service updates grids through the day and makes no other freshness guarantee.

The point comes from ``PointCache``, so a forecast, a grid, and an observation for one coordinate cost
one point request while the entry is valid. The grid itself is never cached. If a cached point's grid
link stops answering, clear the cache with ``PointCache/removeAll()``; the client does not fall back
to another request. Direct endpoint requests bypass the point cache.

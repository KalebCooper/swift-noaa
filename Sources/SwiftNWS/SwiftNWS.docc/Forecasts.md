# Retrieving forecasts

Follow a coordinate's forecast links and choose units and response representations.

## Overview

```swift
let forecast = try await weather.forecast(for: home)
let options = ForecastOptions(
  featureFlags: [.temperatureQuantity, .windSpeedQuantity], units: .si)
let hourly = try await weather.value(for: .hourlyForecast(for: home, options: options))
```

Both operations fetch a point and follow its corresponding service link. They return
`WeatherForecast` with periods in service order, including the timestamps and validity interval.
The client does not trim expired periods or infer a freshness guarantee.

Temperature preserves either a legacy number or a quantitative object. Wind speed and gusts preserve
either text (including ranges) or a quantitative object. Quantities can have a null value or only
minimum and maximum values. Unit, trend, and direction codes use typed open values; compare known
static members or inspect `rawValue` for a provider value added after this SDK release.
Hourly periods additionally expose dewpoint and relative humidity when present.

Use `Endpoint.forecast(for:options:)` or `Endpoint.hourlyForecast(for:options:)` with a decoded
point for a single HTTP operation. These retain the GeoJSON feature envelope and validate the
service link's origin. Options replace a link's units query while preserving its other encoded
query items. Only the forecast request receives its Feature-Flags header. `ForecastOptions` and
`Endpoint` also accept consumer-defined String-backed enums for feature flags and units.

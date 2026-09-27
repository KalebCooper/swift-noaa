# swift-noaa

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Weather forecasts, observations, alerts, and tide predictions from NOAA, with Swift types and
`async`/`await`. No API key required.

[Documentation](https://kalebcooper.github.io/swift-noaa/documentation/) ·
[Examples](#example-apps) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md)

## What's included

Choose the service you need. Each has a client and a separate models library for use with your own
networking stack.

| Service | What you can do | Products |
|---|---|---|
| National Weather Service | Read current conditions, daily and hourly forecasts, alerts, observation history, and forecast grids. Explore stations, zones, offices, text bulletins, and the weather glossary. | `SwiftNWS`, `SwiftNWSModels` |
| Tides & Currents (CO-OPS) | Find coastal stations, read notices/sensors/flood thresholds, get tide and current predictions, and retrieve measured water levels, currents, weather and ocean observations. | `SwiftNOAATides`, `SwiftNOAATidesModels` |

Tides support is **unreleased in this checkout**. See the [changelog](CHANGELOG.md) for release availability and API changes.

## Installation

Requires Swift 6.2 or later. Supports iOS, macOS, tvOS, visionOS, and watchOS 26 or later, plus Linux
and Android.

In Xcode, add `https://github.com/KalebCooper/swift-noaa` as a package dependency and select the
products for your service. For a Swift package, add:

```swift
.package(
  url: "https://github.com/KalebCooper/swift-noaa.git",
  .upToNextMinor(from: "0.2.0")
)
```

Then add the products to your target's dependencies:

```swift
.product(name: "SwiftNWS", package: "swift-noaa"),
.product(name: "SwiftNWSModels", package: "swift-noaa"),
```

Before 1.0, minor releases may change the public API. The requirement above stays within the 0.2
release series. To try the unreleased tides APIs before publication, use a local package reference
to this checkout and select `SwiftNOAATides` and `SwiftNOAATidesModels` instead.

On Linux and Android, also add `traits: ["HTTPPortable"]` to the package dependency and supply an
`AsyncHTTPClientTransport` from [swifty-networking](https://github.com/KalebCooper/swifty-networking)
to the client's `transport:` initializer. The examples below use the Apple-platform initializers.

## Weather in a few lines

Provide a User-Agent identifying your app and a contact, then request a forecast for a coordinate:

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

Use the same client for current conditions, hourly forecasts, and alerts:

```swift
let observation = try await weather.latestObservation(from: .station("KATT"))
print(observation.textDescription ?? "No description reported")

let hourly = try await weather.hourlyForecast(for: location)
let alerts = try await weather.activeAlerts(for: location)
```

You can also request `.nearest(to: location)` for observations. This uses the first station returned
by NWS; it does not guarantee the closest station or freshest reading. Missing measurements stay
`nil`, and unit conversion is explicit.

For more, see [forecasts](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/forecasts),
[observations](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/observationhistory), and
[alerts](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/activealerts).

## Coastal stations and tides

With the unreleased tides products, look up a station by its NOAA identifier:

```swift
import SwiftNOAATides
import SwiftNOAATidesModels

let tides = TidesClient()
let stationID = try CoastalStationIdentifier("9414290")
let station = try await tides.station(identifier: stationID)
print(station.name)
```

Request high and low tides for an explicit date range, datum, and unit system:

```swift
let range = try TidesDateRange(
  begin: TidesTimestamp("2026-09-26 00:00").date,
  end: TidesTimestamp("2026-09-27 23:59").date
)
let query = try HighLowTideQuery(
  datum: .meanLowerLowWater, range: range, stationIdentifier: stationID, units: .metric
)
let result = try await tides.highLowTides(matching: query)

for tide in result.predictions {
  print(tide.time.rawValue, tide.kind.rawValue, tide.height.rawValue)
}
```

Times are in GMT and both range bounds are inclusive. This example requests heights in meters
relative to mean lower low water (MLLW). Results are predictions, not measured water levels.

The [tides guide](Sources/SwiftNOAATides/SwiftNOAATides.docc/SwiftNOAATides.md) also covers station
discovery, predictions, current observations, measured water levels, meteorological and ocean observations,
metadata, exact coverage and limits, and all three request access levels.

## Explore the documentation

The [documentation site](https://kalebcooper.github.io/swift-noaa/documentation/) contains the full
API reference and focused guides:

- **Weather data:** [forecast grids](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/forecastgrids),
  [stations](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/observationstations),
  [zones](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/zones),
  [offices](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/offices),
  [text products](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/products), and
  [glossary](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/glossary).
- **Working with results:** [pagination](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/paginatingcollections),
  [alert history](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/alerthistory), and
  [unit conversion](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/units).
- **Customization:** [reusable requests, errors, caching, and retries](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/usingrequests),
  or [using your own networking stack](https://kalebcooper.github.io/swift-noaa/documentation/swiftnwsmodels/executingrequests).

## Example apps

- [Weather demo](Examples/SwiftNWSDemo): current conditions, forecasts, and alerts for an address or
  your device's location.
- [Tides demo](Examples/SwiftNOAATidesDemo): choose a coastal station and explore predictions, measured water levels,
  weather and ocean observations, and station metadata.

Open the demo's `.xcodeproj` and run on an iOS 26 or later simulator or device. Close the standalone
package in Xcode first; both apps reference the package locally.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, tests, and
documentation builds.

## Coastal observations

Use an explicit GMT window and choose native six-minute samples or on-hour samples. Hourly selection
does not average readings. Availability varies by station and product.

```swift
let observationQuery = try CoastalObservationQuery(
  interval: .sixMinutes, range: range, stationIdentifier: stationID, units: .metric
)
let wind = try await tides.windObservations(matching: observationQuery)
for reading in wind.observations {
  print(reading.time.rawValue, reading.speed.rawValue) // meters per second
}
```

| Data | Available operations |
|---|---|
| Weather and ocean observations | Air pressure, air temperature, conductivity, humidity, salinity and specific gravity, visibility, water temperature, wind |
| Measured water levels | Latest, preliminary one-minute and six-minute, verified hourly and observed high/low |
| Station metadata | Bins, datums, flood thresholds, notices, sensors |

All operations offer client methods, reusable requests, and direct endpoints. Missing readings stay
missing and provider errors remain errors. Quantities keep their product-specific units and raw
values; requested context stays separate from reported metadata. Flood thresholds do not report a
datum and must not be assumed comparable to a water-level series.

See the [Tides guide](Sources/SwiftNOAATides/SwiftNOAATides.docc/SwiftNOAATides.md) for a call site
for every operation, exact limits, units, and missing-data behavior. Coverage excludes all-bin
currents, deployment history, local-time queries, relative selectors other than latest water level,
daily/monthly statistics, OFS and DPAPI. No automatic metadata expansion, polling, interpolation,
datum conversion, or flood classification occurs.

## License

[MIT](LICENSE).

# swift-noaa

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Weather forecasts, observations, alerts, and tide predictions from NOAA, with Swift types and
`async`/`await`. No API key required.

[Documentation](https://kalebcooper.github.io/swift-noaa/documentation/) ·
[Examples](#example-apps) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md)

Station notices and sensor status are available through the Tides & Currents client, reusable
requests, and direct endpoints. Sensor status and elevation units retain NOAA's reported values.

water temperature observations are available in both unit systems, with explicit
six-minute or hourly selection. See the Tides documentation for query examples and units.

air pressure observations are available in both unit systems, with explicit
six-minute or hourly selection. See the Tides documentation for query examples and units.

air temperature observations are available in both unit systems, with explicit
six-minute or hourly selection. See the Tides documentation for query examples and units.

wind observations are available in both unit systems, with explicit
six-minute or hourly selection. See the Tides documentation for query examples and units.

conductivity observations are available in both unit systems, with explicit
six-minute or hourly selection. See the Tides documentation for query examples and units.

humidity observations are available in both unit systems, with explicit
six-minute or hourly selection. See the Tides documentation for query examples and units.

salinity observations are available in both unit systems, with explicit
six-minute or hourly selection. See the Tides documentation for query examples and units.

visibility observations are available in both unit systems, with explicit
six-minute or hourly selection. See the Tides documentation for query examples and units.

Latest water levels use NOAA's explicit latest selector with separate requested context.
See the Tides documentation for empty-response and unavailable-data behavior.

Preliminary one-minute water levels have a dedicated explicit query with a four-day limit.

## What's included

Choose the service you need. Each has a client and a separate models library for use with your own
networking stack.

| Service | What you can do | Products |
|---|---|---|
| National Weather Service | Read current conditions, daily and hourly forecasts, alerts, observation history, and forecast grids. Explore stations, zones, offices, text bulletins, and the weather glossary. | `SwiftNWS`, `SwiftNWSModels` |
| Tides & Currents (CO-OPS) | Find coastal stations, get high/low and sampled tide predictions, read datum/bin metadata, retrieve six-minute and verified hourly water levels, and read current observations and predictions. | `SwiftNOAATides`, `SwiftNOAATidesModels` |

Tides support is **unreleased in this checkout**. Core current observations and predictions are included. See the [changelog](CHANGELOG.md) for release availability and API changes.

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
discovery, hourly samples, datum tables, measured water levels, and reusable requests.

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
- [Tides demo](Examples/SwiftNOAATidesDemo): choose a coastal station and explore high/low tides and
  hourly prediction samples.

Open the demo's `.xcodeproj` and run on an iOS 26 or later simulator or device. Close the standalone
package in Xcode first; both apps reference the package locally.

## Contributing

Issues and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, tests, and
documentation builds.


### Verified hourly heights

Verified hourly heights use `HourlyWaterLevelQuery` and `hourlyWaterLevels(matching:)` at the same
three access levels. They select the separate `hourly_height` product, retain its two raw flags,
and accept explicit GMT windows up to one calendar year. Observed high/low and daily/monthly
statistics remain unsupported.

## Current observations

Discover `.currents`, `.historicCurrents`, or `.surveyCurrents` stations, then load
`currentBins(stationIdentifier:units:)` to inspect available bins. Metadata does not establish
historical depth: deployments can change the relationship between bin and depth.

```swift
let query = try CurrentObservationQuery(
  bin: .explicit(4), range: window,
  stationIdentifier: CoastalStationIdentifier("cb0102"), units: .metric)
let measured = try await tides.currentObservations(matching: query)
let request = TidesRequest.currentObservations(matching: query)
let reusable = try await tides.value(for: request)
let wire = try await tides.send(.currentObservations(matching: query))
```

A query requires either a positive explicit bin or `.providerDefault`, and accepts up to one
calendar month of inclusive GMT minutes. Observations preserve the reported bin, direction in
degrees, and speed: metric means **centimeters per second**, English means knots. No metadata
preflight, depth inference, gap filling, or all-bin access occurs. Bin tables retain reported units,
quality flags, nullable depth/distance, and a null table when NOAA returns one. Station deployment
and retrieval times remain provider text without an assumed UTC offset. Detailed beam diagnostics
and deployment-history retrieval are not supported.

## Current predictions

`currentEvents(matching:)` returns max/slack events from `CurrentEventQuery`. Events always request
major-axis velocity, retain signs and mean flood/ebb directions, and allow one calendar year.
A slack event can have nonzero velocity. `currentPredictions(matching:)` uses `CurrentPredictionQuery`
with a supported cadence (1, 6, 10, 30, or 60 minutes), a requested velocity mode, and at most one
calendar month. Both require an explicit positive bin or `.providerDefault`; predictions default
to the bin nearest the surface when NOAA supports that choice.

```swift
let query = try CurrentPredictionQuery(
  bin: .explicit(14), interval: .hourly, mode: .speedAndDirection, range: window,
  stationIdentifier: CoastalStationIdentifier("EPT0003"), units: .metric)
let samples = try await tides.currentPredictions(matching: query)
let request = TidesRequest.currentPredictions(matching: query)
let reusable = try await tides.value(for: request)
let wire = try await tides.send(.currentPredictions(matching: query))
```

Each sample's `CurrentVelocity` describes the **actual** major-axis or speed/direction fields.
NOAA can return major-axis data for a speed/direction request; the requested mode remains in
`requestedQuery` and never overrides those fields. Provider-reported units remain separate text.
Depth retains numeric strings or explicit null. Nothing converts velocity representations or units.

NOAA documents max/slack-only support for subordinate stations. If a sampled request receives events,
it fails decoding instead of relabeling events as samples. Provider refusals remain provider errors;
there is no automatic preflight, station substitution, alternate request, or interpolation.


## CO-OPS coverage

| Operation | Query / selection | Maximum explicit GMT window |
|---|---|---|
| Station directories and detail | `CoastalStationQuery`, `CoastalStationIdentifier` | Not a time series |
| High/low tide predictions | `HighLowTideQuery` | 10 calendar years |
| Sampled tide predictions | `TidePredictionQuery` | 1 calendar year |
| Datum and current-bin metadata | Explicit station and units | Not a time series |
| Six-minute water levels | `WaterLevelQuery` | 1 calendar month |
| Verified hourly heights | `HourlyWaterLevelQuery` | 1 calendar year |
| Current observations | `CurrentObservationQuery` | 1 calendar month |
| Max/slack current predictions | `CurrentEventQuery` | 1 calendar year |
| Sampled current predictions | `CurrentPredictionQuery` | 1 calendar month |

Every operation has client, reusable request and direct endpoint access. Date bounds are inclusive
GMT minutes. Units, datum and bin choices are explicit where applicable. Returned values and
requested context remain separate; no rounding, splitting, interpolation or conversion occurs.

Unsupported CO-OPS scope includes all-bin queries, historical deployment interpretation, local civil
time, relative/latest selectors, observed high/low water levels, daily/monthly statistics, one-minute
measurements, meteorological products, OFS guidance, and DPAPI. Metadata links are retained without
resource expansion. These values do not provide navigation advice or flood-danger classification.

## License

[MIT](LICENSE).

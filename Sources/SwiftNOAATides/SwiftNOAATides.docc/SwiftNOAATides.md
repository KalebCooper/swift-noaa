# ``SwiftNOAATides``

Discover NOAA CO-OPS stations and retrieve predicted high and low tides through a typed client.

## Overview

``TidesClient`` executes portable requests from [TidesRequest](https://kalebcooper.github.io/swift-noaa/documentation/swiftnoaatidesmodels/tidesrequest/) independently of
SwiftNWS. Choose a service's models alone for your own networking stack, or add its SDK product.

```swift
import SwiftNOAATides
import SwiftNOAATidesModels

let tides = TidesClient()
let query = try CoastalStationQuery(type: .tidePredictions)
let directory = try await tides.stations(matching: query)
let identifier = try CoastalStationIdentifier("9414290")
let station = try await tides.station(identifier: identifier)
let reusable = try await tides.value(for: .station(identifier: identifier))
let direct = try await tides.send(.station(identifier: identifier))
```

The directory is one response. Detail convenience calls require exactly one matching station;
direct sends retain the envelope. No nearest-station choice, resource expansion, sorting,
deduplication, pagination, or capability preflight is performed.

CO-OPS application identification is optional and separate from User-Agent. ``TidesConfiguration``
defaults the Data API application to swift-noaa; set it to nil to omit it. The NWS requirement for
a contact-bearing User-Agent does not apply to this client. Custom transports work on every
supported platform. Apple callers can use the URLSession initializer.

Every send checks cancellation and follows at most five same-origin HTTPS redirects without
credentials, fragments, or invalid encoded paths. Retries are disabled by default; explicitly
passing a swifty-networking RetryPolicy delegates retry timing to its injected Clock. The policy's
attempt budget applies independently to each redirect hop. No retry policy is inferred from
provider prose. Both Data API and Metadata API refusals become ``TidesError/provider(_:)``, even
when carried by HTTP 200. Malformed bodies, HTTP failures without a refusal, and transport
cancellation remain distinguishable.

## Predicted high and low tides

```swift
let range = try TidesDateRange(
  begin: TidesTimestamp("2026-09-26 00:00").date,
  end: TidesTimestamp("2026-09-27 23:59").date
)
let query = try HighLowTideQuery(
  datum: .meanLowerLowWater, range: range,
  stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric
)
let request = TidesRequest.highLowTides(matching: query)
```

The useful result keeps events with `requestedQuery`. This context is requested, not echoed by
NOAA. Direct endpoint responses decode independently with an ordinary JSONDecoder and no userInfo.
Timestamps are strict GMT minutes; custom date-decoding strategies do not change their interpretation.
Both range bounds are inclusive. The high/low window is limited to ten Gregorian calendar years,
including leap-day handling; no date rounding, splitting, interpolation, or extrema calculation occurs.
Metric heights are meters and English heights are feet, relative to the explicitly requested datum.
Numeric strings retain their exact spelling; missing or malformed required values fail decoding.

Subordinate tide stations require MLLW and support high/low predictions only. The client performs no
capability preflight or station substitution. A provider refusal for no data remains an error,
including at HTTP 200, and differs from a successfully decoded empty event array.

Execute `await tides.highLowTides(matching: query)`, `await tides.value(for: request)`, or
`await tides.send(.highLowTides(matching: query))` with `try` for the same send/error behavior.

## Sampled tides and datum metadata

```swift
let samples = try TidePredictionQuery(
  datum: .meanLowerLowWater, interval: .hourly, range: range,
  stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric
)
let sampleRequest = TidesRequest.tidePredictions(matching: samples)
let datumRequest = try TidesRequest.datums(
  stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric
)
```

Execute `tides.tidePredictions(matching:)` or `tides.datums(stationIdentifier:units:)` for everyday
access, `value(for:)` for stored requests, or `send(_:)` for independent wire responses.

Sampled predictions have their own query, wire response and contextual result. Supported cadences
are 1, 5, 6, 10, 15, 30 and 60 minutes, with a maximum of one Gregorian calendar year. Values remain
reported points; the package does not interpolate a curve or infer high/low events. Subordinate
stations reject sampled requests through the provider error path, without a reference-station fallback.

The datum table retains named entries, descriptions, numeric values, epoch, reported units, analysis
periods and disclaimers. A datum table is not permission to convert arbitrary heights. Individual
entry descriptions can qualify units, such as hours for time intervals. Metadata dates and times
remain provider text, without assuming GMT from the separate Data API query contract.

## Six-minute measured water levels

Use `WaterLevelQuery` with `waterLevels(matching:)`, `TidesRequest.waterLevels(matching:)`, or
`TidesEndpoint.waterLevels(matching:)`. These request `product=water_level` with explicit datum,
units and inclusive GMT minute bounds, limited to one Gregorian calendar month. There is no latest
selector, station substitution or automatic date-window splitting.

`WaterLevelResponse` retains provider station metadata and observations; `WaterLevels` adds the
original `requestedQuery` separately. Heights and sigma preserve numeric text. An empty numeric
string has no value, while malformed nonempty text and null required fields fail decoding. Missing
time steps remain absent. Quality is the provider's open `p`/`v` code, never inferred from age.

Raw flags keep their provider order. The first preliminary flag is an outlier count; the first
verified flag indicates an inferred value. The remaining fields describe flat, rate and level-limit
checks. The package does not infer flood danger, subtract predictions or fill gaps. Current products are separate operations and are not yet implemented.

## Verified hourly heights

`HourlyWaterLevelQuery` selects the separate `hourly_height` product, with explicit datum, units,
station and inclusive GMT bounds no longer than one Gregorian calendar year. Use
`hourlyWaterLevels(matching:)` at the client, request or endpoint level. This is not an interval
option on the six-minute water-level product.

`HourlyWaterLevel` retains height, sigma and raw flags. Its two flag positions indicate an inferred
value and an exceeded expected level limit. There is no echoed quality code: verification is part
of the provider product definition. `HourlyWaterLevels` keeps provider metadata and observations
alongside the original requested query. Unknown flags and empty numeric text remain observable;
missing time steps stay absent. Observed high/low levels and daily/monthly means are unsupported.

## Topics

### Essentials

- ``TidesClient``
- ``TidesConfiguration``
- ``TidesError``

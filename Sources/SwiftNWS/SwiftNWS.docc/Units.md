# Units

Convert WMO readings explicitly and format them for your audience.

## Convert a reading

```swift
import Foundation
import SwiftNWS
import SwiftNWSModels

let speed = observation.windSpeed?.measurement(in: UnitSpeed.milesPerHour)
let temperature = observation.temperature?.measurement(in: UnitTemperature.fahrenheit)
let fraction = observation.relativeHumidity?.fraction
```

The SDK maps `wmoUnit:degC`, `wmoUnit:degF`, `wmoUnit:K`, `wmoUnit:km_h-1`,
`wmoUnit:Pa`, `wmoUnit:m`, `wmoUnit:mm`, and `wmoUnit:degree_(angle)` to Foundation
dimensions. This covers every dimensional code in the recorded NWS responses. Foundation performs
conversion to a compatible destination unit. `wmoUnit:percent` exposes a fraction, such as 0.65
for a reported value of 65.

Unknown codes, incompatible destination dimensions, and missing measurements return nil.
No range bound is substituted for a missing value. The source quantity retains its bounds,
quality control, and unit code unchanged.

## Format for display

On Apple platforms, use the measurement's format style:

```swift
let text = temperature?.formatted(
  .measurement(width: .abbreviated, usage: .asProvided))
let humidity = fraction?.formatted(.percent)
```

`asProvided` keeps your requested unit. A usage such as `weather` can choose units for the
user's locale. Foundation's measurement formatting availability differs outside Apple platforms;
conversion and the measurement's numeric value and unit symbol remain available.

The adapter belongs to `SwiftNWS` because it uses full Foundation. Consumers importing only
`SwiftNWSModels` continue to receive the original portable quantities.

# ``SwiftNOAATides``

Discover NOAA CO-OPS stations and retrieve their metadata through a typed client.

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

## Topics

### Essentials

- ``TidesClient``
- ``TidesConfiguration``
- ``TidesError``

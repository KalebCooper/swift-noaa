# Reading the product catalogs

Discover the kinds of text product the service issues and the locations it issues them for.

## Overview

The service publishes text products, such as an area forecast discussion, under a short product
code and a location identifier. Four operations read the catalogs that name those codes and
locations:

| Operation | Path | Returns |
|---|---|---|
| ``NWSClient/productTypes()`` | `/products/types` | `ProductTypes` |
| ``NWSClient/productLocations()`` | `/products/locations` | `ProductLocations` |
| ``NWSClient/productLocations(for:)-(ProductCode)`` | `/products/types/{typeId}/locations` | `ProductLocations` |
| ``NWSClient/productTypes(at:)`` | `/products/locations/{locationId}/types` | `ProductTypes` |

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(example.com, contact@example.com)")
let types = try await weather.productTypes()
print(types.types.count)  // 338

let locations = try await weather.productLocations(for: .areaForecastDiscussion)
print(locations.locations["EWX"] ?? nil)  // "Austin/San Antonio, TX"
```

Each operation sends one GET asking for `application/ld+json`, the only representation the service
offers for these resources, with no query items and no feature flags. The body is decoded whole:
there is no GeoJSON wrapper to unwrap.

### These are catalogs, not product text

A catalog names what exists. It does not carry the text of any product, and none of these four
operations retrieves one. Reading an area forecast discussion for Austin/San Antonio means
requesting a product route this package does not yet build, listed under Supported product routes
below.

### Discovering a code and a location

The two dimensions of the catalogs, code and location, are each narrowed by the other:

```swift
// 1. Every kind of product the service issues, in service order.
let everyType = try await weather.productTypes()
for type in everyType.types.prefix(3) {
  print(type.productCode.rawValue, type.productName)
}

// 2. The locations one of those kinds is issued for.
let afdLocations = try await weather.productLocations(for: .areaForecastDiscussion)
print(afdLocations.locations.count)  // 123

// 3. The kinds issued for one of those locations.
let ewxTypes = try await weather.productTypes(at: "EWX")
print(ewxTypes.types.count)  // 20
```

Step 2 narrows the whole location catalog to the locations that issue one code. Step 3 narrows the
whole type catalog to the codes one location issues. Starting from either end reaches the same
pairing, and the package neither caches a catalog nor cross-checks one against the other.

### A location identifier is not an office identifier

``NWSClient/productLocations()`` answers 1,693 identifiers, far more than the service has forecast
offices. A location identifier is whatever the product routes accept as a path segment: an office
code such as `EWX`, but also a site, a region, or a national center. Some identifiers match an
office code exactly and still mean a different thing on these routes.

Nothing here converts between the two. A code from <doc:Offices> is not interchangeable with a
product location identifier, and the package does not look one up from the other, upper-case an
identifier, or otherwise normalize it. Pass a location identifier you read from a product catalog.

### Locations without a description

`ProductLocations` decodes as a dictionary keyed by identifier, whose value is the description the
service published or nil. Most of the whole catalog has no description: of the 1,693 identifiers
recorded from `/products/locations`, 1,562 arrived as `null`.

```swift
let locations = try await weather.productLocations()
print(locations.locations.count)                          // 1693
print(locations.locations["EWX"] ?? nil)                  // "Austin/San Antonio, TX"
print(locations.locations["ABC"] ?? nil)                  // nil, listed without a description
print(locations.locations["not a location"] ?? "missing") // "missing", not in the catalog
```

An undescribed location is kept with a nil value rather than dropped, because its identifier is
usable on the product routes either way. A nil value means the service sent no description for a
location it does list. A key that is absent means the service did not list that identifier at all.
The two are different answers, and both come back exactly as the service sent them: nothing
substitutes an empty string, fills in a name from another catalog, or filters the undescribed
identifiers out. Narrowing by code often describes everything it lists, as the 123 recorded
locations for `AFD` do, but that is what one recording showed rather than a guarantee.

### Three levels of access

Each operation is available as an everyday method, as a reusable request for
``NWSClient/value(for:)``, and as the single HTTP operation for ``NWSClient/send(_:)`` or another
networking stack:

```swift
let request = WeatherRequest.productTypes(at: "EWX")
let reusable = try await weather.value(for: request)

let catalog = try await weather.send(Endpoint.productTypes)

if let endpoint = Endpoint.productLocations(for: .areaForecastDiscussion) {
  let direct = try await weather.send(endpoint)
}
```

The everyday methods delegate to `WeatherRequest.productTypes`,
`WeatherRequest.productLocations`, `WeatherRequest.productLocations(for:)`, and
`WeatherRequest.productTypes(at:)`. All three levels return the same value. The two catalogs that
take no argument, `Endpoint.productTypes` and `Endpoint.productLocations`, are plain properties;
the two that take a code or an identifier are failable factories that return nil for an argument
they cannot encode as a path segment.

Each level accepts a product code of your own as well, so an app that already enumerates the codes
it cares about does not convert to `ProductCode` first:

```swift
enum Discussion: String {
  case area = "AFD"
}

let mine = try await weather.productLocations(for: Discussion.area)
```

### Codes and identifiers are checked before sending

The request factories always return a request. Executing one rejects an empty argument, or one that
does not produce a valid encoded path, before any request is sent:

- ``NWSError/invalidProductCode(_:)`` names an unusable product code.
- ``NWSError/invalidProductLocation(_:)`` names an unusable location identifier.

A code or identifier the service does not catalog is a different thing: it is sent, and the
service's refusal arrives as ``NWSError/problem(_:)``.

### Product codes are open values

`ProductCode` wraps the service's exact code. The service catalogs hundreds of codes and adds to
them, so the type spells out only three named members, `ProductCode.areaForecastDiscussion`
(`AFD`), `ProductCode.publicZoneForecast` (`ZFP`), and
`ProductCode.specialWeatherStatement` (`SPS`). Every other code is usable through
`ProductCode(rawValue:)`, and a code that arrives in a response keeps the service's exact spelling
in `rawValue` rather than failing to decode. ``NWSClient/productTypes()`` is the live authority on
which codes exist.

### Supported product routes

| Route | Supported |
|---|---|
| `/products/types` | Yes |
| `/products/locations` | Yes |
| `/products/types/{typeId}/locations` | Yes |
| `/products/locations/{locationId}/types` | Yes |
| `/products` | Not yet built |
| `/products/{productId}` | Not yet built |
| `/products/types/{typeId}` | Not yet built |
| `/products/types/{typeId}/locations/{locationId}` | Not yet built |
| `/products/types/{typeId}/locations/{locationId}/latest` | Not yet built |

### What the product catalog operations do not do

- Product text is not retrieved. The five routes above that list, look up, or return a product are
  not yet built, and plain-text product retrieval (`text/plain`) is not supported: every product
  request this package sends asks for `application/ld+json`.
- There are no product queries. The `/products` route's filters by code, location, office, time,
  and page size are not yet built.
- Each catalog is one response. The routes document no page size and no cursor, so neither is sent
  and there are no product page or item sequences. That describes the request, not a guarantee
  about how large a catalog is. See <doc:PaginatingCollections> for the collections that do
  continue.
- No completeness, freshness, or availability claim is made. A catalog is what the service answered
  for that request. A pairing it lists is not a promise that a product exists for it, and one it
  omits is not a promise that none does.
- `ProductTypes` keeps the order the service listed the types in, which is the only ordering there
  is. `ProductLocations` is a dictionary and therefore has no order at all. Nothing sorts, filters,
  deduplicates, or searches a catalog.
- Nothing is cached. ``PointCache`` covers coordinate lookups only.

Redirects, refusals, and cancellation behave as they do for every other request. A redirect is
validated against the HTTPS API origin, and one that leaves it throws ``NWSError/invalidLink(_:)``
rather than being followed. Cancellation is checked before the request is sent.

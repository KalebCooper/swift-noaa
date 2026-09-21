# Decoding product catalog data

Decode the service's product type and location catalogs with any networking stack.

## Overview

Four product catalog routes decode into two models:

| Path | Endpoint | Decodes as |
|---|---|---|
| `/products/types` | `Endpoint.productTypes` | ``ProductTypes`` |
| `/products/locations` | `Endpoint.productLocations` | ``ProductLocations`` |
| `/products/types/{typeId}/locations` | `Endpoint.productLocations(for:)` | ``ProductLocations`` |
| `/products/locations/{locationId}/types` | `Endpoint.productTypes(at:)` | ``ProductTypes`` |

```swift
import SwiftNWSModels

let endpoint = Endpoint.productTypes
print(endpoint.path)             // "/products/types"
print(endpoint.accept.rawValue)  // "application/ld+json"

// Send a GET to https://api.weather.gov plus endpoint.path with that Accept header and a
// User-Agent identifying your application, then:
let catalog = try JSONDecoder().decode(ProductTypes.self, from: body)
print(catalog.types.count)  // 338
```

The service offers these resources only as JSON-LD, so each endpoint asks for ``MediaType/jsonLD``
and carries no query items and no feature flags. Each body decodes whole, with no GeoJSON wrapper.
The two catalogs that take no argument are properties rather than factories. The two that take an
argument encode it as one path segment, without upper-casing or otherwise normalizing it, and
return nil for an empty argument or one that produces an invalid encoded path.

```swift
guard let endpoint = Endpoint.productLocations(for: .areaForecastDiscussion) else { return }
print(endpoint.path)  // "/products/types/AFD/locations"
```

These are catalogs of what the service issues, not the text of any product. `/products`,
`/products/{productId}`, `/products/types/{typeId}`,
`/products/types/{typeId}/locations/{locationId}`, and that pairing's `/latest` route are not yet
built, and there is no model for a product's text.

## Execution

`WeatherRequest.productTypes` and `WeatherRequest.productLocations` wrap their endpoints, so they
carry the plain `endpoint` resolution and add no case of their own.
`WeatherRequest.productLocations(for:)` and `WeatherRequest.productTypes(at:)` always return a
request and carry the `productLocations` and `productTypes` resolution cases:

```swift
let request = WeatherRequest.productTypes(at: "EWX")
if case .productTypes(let location) = request.resolution {
  print(location)  // "EWX"
}
```

The cases exist so an executor validates the argument before any request: it unwraps the endpoint
factory and reports an unusable code or identifier without sending. After that each case is one
request whose body decodes whole. See <doc:ExecutingRequests>.

Each factory also accepts a String-backed code of your own, which it converts to ``ProductCode``:

```swift
enum Discussion: String {
  case area = "AFD"
}

let mine = WeatherRequest.productLocations(for: Discussion.area)
```

The same endpoints decode a response model of your own, when you want less than the full body:

```swift
struct TypeNames: Decodable, Sendable {
  let graph: [Name]

  struct Name: Decodable, Sendable {
    let productName: String
  }

  enum CodingKeys: String, CodingKey {
    case graph = "@graph"
  }
}

if let endpoint = Endpoint<TypeNames>(accept: .jsonLD, path: "/products/types") {
  let request = WeatherRequest(endpoint: endpoint)
}
```

## Product types

`/products/types` and `/products/locations/{locationId}/types` answer a JSON-LD envelope whose
`@graph` key holds the catalog:

```json
{
  "@context": { "@version": "1.1", "@vocab": "https://api.weather.gov/ontology#" },
  "@graph": [
    { "productCode": "ABV", "productName": "Rawinsonde Data Above 100 Millibars" },
    { "productCode": "ADA", "productName": "Alarm/Alert Administrative Msg" }
  ]
}
```

``ProductTypes/types`` decodes from that `@graph` key and keeps the order the service listed the
types in, which is the only ordering there is. A body without a `@graph` array, or with one that is
not an array of product types, fails to decode rather than producing an empty list, so an empty
catalog and a missing one stay distinct. The JSON-LD context is not kept.

``ProductType/productCode`` and ``ProductType/productName`` are both required. An entry missing
either fails the whole catalog to decode rather than substituting an empty value.

The catalog is one response. The routes document no page size and no cursor, so the endpoints send
neither and there is no continuation to read. That describes the request, not a guarantee about how
large a catalog is. Nothing here sorts, filters, deduplicates, or searches the types.

## Product locations

`/products/locations` and `/products/types/{typeId}/locations` answer a JSON-LD envelope whose
`locations` key is an object, not an array:

```json
{
  "@context": [],
  "locations": {
    "ABC": null,
    "ABQ": "Albuquerque, NM",
    "EWX": "Austin/San Antonio, TX"
  }
}
```

``ProductLocations/locations`` decodes that object as `[String: String?]`. Each key is a location
identifier the product routes take as a path segment, and each value is the description the service
published for it. A body without a `locations` object fails to decode rather than producing an
empty catalog, and a description that is neither a string nor `null` fails to decode as well.

The dictionary's value type is optional because the service publishes a description for only some
of what it lists. Of the 1,693 identifiers recorded from `/products/locations`, 1,562 arrived as
`null`. An undescribed location is kept with a nil value rather than dropped, because its
identifier is usable on the product routes either way:

```swift
let catalog = try JSONDecoder().decode(ProductLocations.self, from: body)
print(catalog.locations.count)                          // 1693
print(catalog.locations["EWX"] ?? nil)                  // "Austin/San Antonio, TX"
print(catalog.locations["ABC"] ?? nil)                  // nil, listed without a description
print(catalog.locations["not a location"] ?? "missing") // "missing", not in the catalog
```

A nil value and an absent key are different answers. A nil value means the service listed the
identifier and sent no description for it. An absent key means the service did not list that
identifier at all. Nothing substitutes an empty string, supplies a name from another catalog, or
filters the undescribed identifiers out. Encoding writes an undescribed location back as `null`,
so a decoded catalog round-trips.

A location identifier is whatever the product routes accept as a path segment: an office code such
as `EWX`, but also a site, a region, or a national center. Some identifiers match a forecast office
code exactly and still mean a different thing on these routes. These models do not convert between
the two, and a code from <doc:OfficeData> is not interchangeable with a product location
identifier.

A dictionary has no order, so the whole-catalog route publishes none through this model. Narrowing
by code often describes everything it lists, as the 123 recorded locations for `AFD` do, but that
is what one recording showed rather than a guarantee. The routes document no page size or cursor,
so neither is sent and there is no location pagination, ordering policy, or filtering.

## Product codes

``ProductCode`` is an extensible String-backed code naming one kind of text product, the `typeId`
segment of the product routes. The service catalogs hundreds of codes and adds to them, so the type
spells out only the three this package names:

| Member | Raw value | Meaning |
|---|---|---|
| ``ProductCode/areaForecastDiscussion`` | `AFD` | An office's area forecast discussion. |
| ``ProductCode/publicZoneForecast`` | `ZFP` | A public zone forecast. |
| ``ProductCode/specialWeatherStatement`` | `SPS` | A special weather statement. |

Every other code is usable through ``ProductCode/init(rawValue:)``, and a code that arrives in a
response keeps the service's exact spelling in ``ProductCode/rawValue`` rather than failing to
decode. The named members are a convenience, not the set of valid codes: `/products/types` is the
live authority on which codes exist, and these models neither validate a code against it nor treat
an unnamed code as unknown.

``ProductCode/init(_:)`` converts a String-backed value of your own, so an app that already
enumerates the codes it cares about keeps its own type at every level of the API.

## What is not supported

- Product text has no model. `/products`, `/products/{productId}`, `/products/types/{typeId}`,
  `/products/types/{typeId}/locations/{locationId}`, and that pairing's `/latest` route are not yet
  built, and no endpoint or request factory describes them.
- Plain-text product retrieval (`text/plain`) is not supported. Every product endpoint here asks
  for ``MediaType/jsonLD``.
- There is no product query type. The filters `/products` documents, by code, location, office,
  time, and page size, are not yet built.
- No completeness, freshness, or availability claim is made. A catalog is what the service answered
  for that request. A pairing it lists is not a promise that a product exists for it, and one it
  omits is not a promise that none does.

## Topics

### Product catalogs

- ``ProductCode``
- ``ProductLocations``
- ``ProductType``
- ``ProductTypes``

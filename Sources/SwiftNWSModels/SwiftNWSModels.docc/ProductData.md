# Decoding product data

Decode the service's product catalogs and the text products themselves with any networking stack.

## Overview

Nine product routes decode into four models:

| Path | Endpoint | Decodes as |
|---|---|---|
| `/products` | `Endpoint.products(matching:)` | ``TextProducts`` |
| `/products/types` | `Endpoint.productTypes` | ``ProductTypes`` |
| `/products/locations` | `Endpoint.productLocations` | ``ProductLocations`` |
| `/products/{productId}` | `Endpoint.product(identifier:)` | ``TextProduct`` |
| `/products/types/{typeId}` | `Endpoint.products(ofType:)` | ``TextProducts`` |
| `/products/types/{typeId}/locations` | `Endpoint.productLocations(for:)` | ``ProductLocations`` |
| `/products/types/{typeId}/locations/{locationId}` | `Endpoint.products(at:ofType:)` | ``TextProducts`` |
| `/products/types/{typeId}/locations/{locationId}/latest` | `Endpoint.latestProduct(at:ofType:)` | ``TextProduct`` |
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
and carries no feature flags. Each body decodes whole, with no GeoJSON wrapper. Only
`Endpoint.products(matching:)` carries query items, and they come from a validated ``ProductQuery``;
the other eight endpoints send none, because their routes document no options and refuse one. The
two catalogs that take no argument are properties rather than factories, and
`Endpoint.products(matching:)` is not failable either, because the query validated itself. Every
other factory encodes its argument as one path segment, without upper-casing or otherwise
normalizing it, and returns nil for an empty argument or one that produces an invalid encoded path.

```swift
guard let endpoint = Endpoint.productLocations(for: .areaForecastDiscussion) else { return }
print(endpoint.path)  // "/products/types/AFD/locations"
```

Four of the nine routes are catalogs of what the service issues. The other five list or retrieve
products, and only the single-product and latest routes carry a bulletin's words. Every route
answers JSON-LD; the words are a JSON string inside it, so there is no plain-text representation to
request and no text decoder here.

## Execution

`WeatherRequest.productTypes`, `WeatherRequest.productLocations`, and
`WeatherRequest.products(matching:)` wrap their endpoints, so they carry the plain `endpoint`
resolution and add no case of their own. The five factories that take a path argument always return
a request and carry a resolution case: `productLocations`, `productTypes`, `product`,
`productsOfType`, and `latestProduct`.

```swift
let request = WeatherRequest.productTypes(at: "EWX")
if case .productTypes(let location) = request.resolution {
  print(location)  // "EWX"
}
```

The cases exist so an executor validates the argument before any request: it unwraps the endpoint
factory and reports an unusable code or identifier without sending. After that each case is one
request whose body decodes whole. See <doc:ExecutingRequests>.

`productsOfType` carries an optional location, which is the one place a resolution chooses between
two routes: a nil location selects `/products/types/{typeId}` and a location selects
`/products/types/{typeId}/locations/{locationId}`. It is a bounded choice inside one operation, not
dispatch over arbitrary resources. `latestProduct` carries a location and a code and is still one
request, because the service selects the product; an executor must not turn it into a list followed
by a detail lookup. When an operation takes both a code and a location, check the code first, so
the reported failure names which argument was unusable.

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

## Text products

`/products/{productId}` and the `/latest` route answer one JSON-LD object per product, with the
bulletin in a `productText` string:

```json
{
  "@context": { "@version": "1.1", "@vocab": "https://api.weather.gov/ontology#" },
  "@id": "https://api.weather.gov/products/a6addd61-6620-4718-9d53-effd7d8c2560",
  "id": "a6addd61-6620-4718-9d53-effd7d8c2560",
  "wmoCollectiveId": "FXUS64",
  "issuingOffice": "KEWX",
  "issuanceTime": "2026-09-20T05:18:00+00:00",
  "productCode": "AFD",
  "productName": "Area Forecast Discussion",
  "productText": "\n000\nFXUS64 KEWX 200518\nAFDEWX\n\nArea Forecast Discussion\n..."
}
```

``TextProduct/id`` is required. Every other field is optional, because the routes differ in what
they send: ``TextProduct/url`` decodes from the `@id` identity link, ``TextProduct/issuanceTime``
decodes as ISO 8601 independently of the decoder's date strategy, and a missing or malformed value
where the schema is strict fails the whole product rather than being replaced.

``TextProduct/productText`` is the bulletin exactly as the service transmitted it, whatever
whitespace, blank lines, line endings, and heading lines it carries. The recorded area forecast
discussion, for example, opens with a newline ahead of its WMO heading. Nothing here trims,
normalizes, wraps, re-encodes, or interprets it, and an encode writes the same characters back:

```swift
let product = try JSONDecoder().decode(TextProduct.self, from: body)
print(product.productText?.hasPrefix("\n000\n") ?? false)  // true for the recorded discussion
```

``TextProduct/issuingOffice`` is the WMO identifier of the office that transmitted the bulletin,
such as `KEWX`. That is a different vocabulary from the product location identifiers of
``ProductLocations``, such as `EWX`, and from a forecast office code in <doc:OfficeData>. Neither
is derived from the other and nothing here converts between them.

`/products`, `/products/types/{typeId}`, and `/products/types/{typeId}/locations/{locationId}`
answer a JSON-LD envelope whose `@graph` key holds the products:

```json
{
  "@context": { "@version": "1.1", "@vocab": "https://api.weather.gov/ontology#" },
  "@graph": [
    {
      "@id": "https://api.weather.gov/products/a6addd61-6620-4718-9d53-effd7d8c2560",
      "id": "a6addd61-6620-4718-9d53-effd7d8c2560",
      "wmoCollectiveId": "FXUS64",
      "issuingOffice": "KEWX",
      "issuanceTime": "2026-09-20T05:18:00+00:00",
      "productCode": "AFD",
      "productName": "Area Forecast Discussion"
    }
  ]
}
```

``TextProducts/products`` decodes from that `@graph` key and keeps the order the service listed the
products in. A body without a `@graph` array, or with one that is not an array of products, fails
to decode rather than producing an empty list.

A list entry carries no `productText` key at all, so ``TextProduct/productText`` is nil for every
entry. That is the shape of a list, not a bulletin with no words: nothing substitutes an empty
string and nothing fetches a product's detail to fill it in. An empty string, an absent key, and a
`null` value stay three distinct answers after decoding. Retrieve the words with the single-product
endpoint, or follow an entry's ``TextProduct/url`` through `Endpoint(accept:link:)`, which
validates the link against the API origin.

## Product queries

``ProductQuery`` carries every option `/products` accepts and nothing else:

```swift
let query = try ProductQuery(limit: 2, locations: ["EWX"], types: [.areaForecastDiscussion])
print(Endpoint.products(matching: query).path)  // "/products?limit=2&location=EWX&type=AFD"
```

`end`, `issuingOffices`, `limit`, `locations`, `start`, `types`, and `wmoCollectiveIdentifiers` map
to the service's `end`, `office`, `limit`, `location`, `start`, `type`, and `wmoid` parameters. Each
list is sent as one comma-separated value, an empty list leaves that filter off, and the values are
passed through without case conversion, because the service owns its changing vocabulary. Window
bounds are sent as ISO 8601 instants in UTC with whole-second precision, and an absent bound leaves
that side of the window open.

A limit is validated as 1 through 500 when the query is created and throws
``ProductQuery/ValidationError/invalidLimit`` otherwise. A nil limit is omitted from the path
entirely, because the route documents no default page size. The query declares no cursor, because
the route declares none. Product locations and issuing offices stay separate fields, and a reversed
window is sent as written for the service to judge.

The other two product list routes take no options at all and refuse a limit, so no query type
applies to them.

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

- Plain-text product retrieval (`text/plain`) is not supported. Every product endpoint here asks
  for ``MediaType/jsonLD``, and a bulletin arrives as a JSON string inside that body.
- There is no product pagination. No product route declares a cursor and no recorded response
  carried a continuation, so nothing here reads or synthesizes one and there are no product
  sequences. A page size is a `/products` filter, not a cursor.
- A bulletin is not interpreted. There is no WMO heading parser, section splitter, text
  normalization, or conversion of a product into ``WeatherForecast``.
- No completeness, freshness, or availability claim is made. A catalog is what the service answered
  for that request. A pairing it lists is not a promise that a product exists for it, and one it
  omits is not a promise that none does.

## Topics

### Products

- ``ProductCode``
- ``ProductLocations``
- ``ProductQuery``
- ``ProductType``
- ``ProductTypes``
- ``TextProduct``
- ``TextProducts``

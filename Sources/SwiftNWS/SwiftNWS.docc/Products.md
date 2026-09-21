# Reading text products

Discover the kinds of text product the service issues, the locations it issues them for, and the
bulletins themselves.

## Overview

The service publishes text products, such as an area forecast discussion, under a short product
code and a location identifier. Nine operations read them. Four read the catalogs that name the
codes and locations, and five list or retrieve the products:

| Operation | Path | Returns |
|---|---|---|
| ``NWSClient/productTypes()`` | `/products/types` | `ProductTypes` |
| ``NWSClient/productLocations()`` | `/products/locations` | `ProductLocations` |
| ``NWSClient/productLocations(for:)-(ProductCode)`` | `/products/types/{typeId}/locations` | `ProductLocations` |
| ``NWSClient/productTypes(at:)`` | `/products/locations/{locationId}/types` | `ProductTypes` |
| ``NWSClient/products(matching:)`` | `/products` | `TextProducts` |
| ``NWSClient/products(ofType:)-(ProductCode)`` | `/products/types/{typeId}` | `TextProducts` |
| ``NWSClient/products(at:ofType:)-(_,ProductCode)`` | `/products/types/{typeId}/locations/{locationId}` | `TextProducts` |
| ``NWSClient/product(identifier:)`` | `/products/{productId}` | `TextProduct` |
| ``NWSClient/latestProduct(at:ofType:)-(_,ProductCode)`` | `/products/types/{typeId}/locations/{locationId}/latest` | `TextProduct` |

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(example.com, contact@example.com)")
let discussion = try await weather.latestProduct(at: "EWX", ofType: .areaForecastDiscussion)
print(discussion.issuingOffice ?? "")  // "KEWX"
print(discussion.productText ?? "")    // the bulletin, exactly as the service sent it
```

Each operation sends one GET asking for `application/ld+json`, the only representation the service
offers for these resources, and the body is decoded whole: there is no GeoJSON wrapper to unwrap.
Only ``NWSClient/products(matching:)`` carries query items, supplied by `ProductQuery`; the other
eight send none, and no product operation sends feature flags.

### The response is JSON-LD and the bulletin is a string inside it

A product route answers JSON, not a raw bulletin. The words are a JSON string,
`TextProduct.productText`, decoded like any other field. Plain-text retrieval (`text/plain`) is not
supported: every request this package sends asks for `application/ld+json`, and there is no text
decoder, alternate response codec, or byte-to-String fallback.

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

### From a pairing to a bulletin

A code and a location name a list of products, and a product's identifier names its text:

```swift
let listed = try await weather.products(at: "EWX", ofType: .areaForecastDiscussion)
print(listed.products.count)  // 33

guard let entry = listed.products.first else { return }
print(entry.productText ?? "no text")  // "no text", a list entry carries none

let product = try await weather.product(identifier: entry.id)
print(product.productText ?? "")
```

The service also answers the newest product for a pairing directly:

```swift
let latest = try await weather.latestProduct(at: "EWX", ofType: .areaForecastDiscussion)
```

``NWSClient/latestProduct(at:ofType:)-(_,ProductCode)`` is one request. The service selects the
product; the package does not list products, sort them, read a first entry, or fetch a detail
behind the call.

### Querying `/products`

``NWSClient/products(matching:)`` is the one product route that takes options, and `ProductQuery`
supplies all of them:

```swift
let query = try ProductQuery(limit: 2, locations: ["EWX"], types: [.areaForecastDiscussion])
let products = try await weather.products(matching: query)
print(products.products.count)  // 2
// GET /products?limit=2&location=EWX&type=AFD
```

Each filter is a list the service reads as alternatives and the query sends as one comma-separated
parameter; an empty list leaves that filter off. Window bounds, `start` and `end`, are sent as ISO
8601 instants in UTC with whole-second precision, and an absent bound leaves that side of the
window open. A limit is validated as 1 through 500 when the query is created and omitted entirely
when nil, because the route documents no default page size. An unfiltered query is
`try ProductQuery()`.

The other two list routes, `/products/types/{typeId}` and
`/products/types/{typeId}/locations/{locationId}`, accept no options at all: the service refuses a
limit on either. Use ``NWSClient/products(matching:)`` when you need one.

### List entries carry no product text

`/products` and the two typed list routes send a product's metadata only. `TextProduct.productText`
is nil for every entry, which is the shape of a list rather than a bulletin with no words:

```swift
let listed = try await weather.products(ofType: .areaForecastDiscussion)
print(listed.products.count)                                 // 4567
print(listed.products.allSatisfy { $0.productText == nil })  // true
```

Nothing substitutes an empty string for the missing text and nothing fetches a product's detail to
fill it in. Retrieve the words with ``NWSClient/product(identifier:)``, or follow a list entry's
`TextProduct.url` through `Endpoint(accept:link:)`, which validates the link against the API origin
before it is followed.

### Product text is kept exactly as sent

`TextProduct.productText` is the bulletin as the service transmitted it, whatever whitespace, blank
lines, line endings, and heading lines it carries. The recorded area forecast discussion, for
example, opens with a newline ahead of its WMO heading and separates its sections with `$$`. The
package does not trim, normalize, wrap, re-encode, or interpret any of it, and it neither parses
meteorological prose nor turns a bulletin into a forecast.

An empty string and an absent value stay distinct: `""` is a bulletin the service sent with no
words in it, and nil means the response carried no text at all.

### A location identifier is not an office identifier

``NWSClient/productLocations()`` answers 1,693 identifiers, far more than the service has forecast
offices. A location identifier is whatever the product routes accept as a path segment: an office
code such as `EWX`, but also a site, a region, or a national center. Some identifiers match an
office code exactly and still mean a different thing on these routes.

A product's own `TextProduct.issuingOffice` is a third vocabulary: the WMO identifier of the office
that transmitted the bulletin, such as `KEWX`, not the `EWX` the route was asked for. Nothing here
converts between any of them, looks one up from another, upper-cases an identifier, or otherwise
normalizes it. A code from <doc:Offices> is not interchangeable with a product location identifier
either. Pass a location identifier you read from a product catalog.

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
let request = WeatherRequest.latestProduct(at: "EWX", ofType: .areaForecastDiscussion)
let reusable = try await weather.value(for: request)

let catalog = try await weather.send(Endpoint.productTypes)

if let endpoint = Endpoint.product(identifier: "a6addd61-6620-4718-9d53-effd7d8c2560") {
  let direct = try await weather.send(endpoint)
}
```

The everyday methods delegate to the matching `WeatherRequest` factories, and all three levels
return the same value. `Endpoint.productTypes` and `Endpoint.productLocations` are plain properties
and `Endpoint.products(matching:)` takes an already validated query, so none of those three is
failable; every other product endpoint factory returns nil for an argument it cannot encode as a
path segment. The request factories always return a request and report an unusable argument when
the request is executed.

Each level accepts a product code of your own as well, so an app that already enumerates the codes
it cares about does not convert to `ProductCode` first:

```swift
enum Discussion: String {
  case area = "AFD"
}

let mine = try await weather.latestProduct(at: "EWX", ofType: Discussion.area)
```

### Codes and identifiers are checked before sending

Executing a request rejects an empty argument, or one that does not produce a valid encoded path,
before any request is sent:

- ``NWSError/invalidProductCode(_:)`` names an unusable product code.
- ``NWSError/invalidProductIdentifier(_:)`` names an unusable product identifier.
- ``NWSError/invalidProductLocation(_:)`` names an unusable location identifier.

An operation taking both a code and a location checks the code first, so the failure names which
argument was unusable.

A code, location, or identifier the service does not catalog is a different thing: it is sent, and
the service's refusal arrives as ``NWSError/problem(_:)``, usually a `404`.

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
| `/products` | Yes |
| `/products/types` | Yes |
| `/products/locations` | Yes |
| `/products/{productId}` | Yes |
| `/products/types/{typeId}` | Yes |
| `/products/types/{typeId}/locations` | Yes |
| `/products/types/{typeId}/locations/{locationId}` | Yes |
| `/products/types/{typeId}/locations/{locationId}/latest` | Yes |
| `/products/locations/{locationId}/types` | Yes |
| Plain-text (`text/plain`) product retrieval | No |

### What the product operations do not do

- Nothing is paged. No product route declares a cursor and no recorded response carried a
  continuation, so there are no product page or item sequences and nothing to follow. A page size
  is a `/products` filter, not a cursor. See <doc:PaginatingCollections> for the collections that
  do continue.
- No completeness, freshness, or availability claim is made. A list is what the service answered
  for that request. A pairing a catalog lists is not a promise that a product exists for it, and
  one it omits is not a promise that none does.
- Nothing is ordered here. `TextProducts` and `ProductTypes` keep the order the service listed
  their entries in, which is the only ordering there is, and `ProductLocations` is a dictionary and
  therefore has no order at all. Nothing sorts, filters, deduplicates, or searches a response.
- No bulletin is interpreted. There is no WMO heading parser, no section splitter, and no
  conversion of a product into a forecast.
- A typed list route is never rewritten as a `/products` query, and the latest route is never
  turned into a list followed by a detail lookup. Their filters and retention can differ.
- Nothing is cached. ``PointCache`` covers coordinate lookups only.

Redirects, refusals, and cancellation behave as they do for every other request. A redirect is
validated against the HTTPS API origin, and one that leaves it throws ``NWSError/invalidLink(_:)``
rather than being followed. Cancellation is checked before the request is sent.

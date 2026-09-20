# Decoding glossary data

Decode the service's glossary of weather terms with any networking stack.

## Overview

`/glossary` answers every term the service publishes together with its definition, in one body, and
decodes as ``WeatherGlossary``.

```swift
import SwiftNWSModels

let endpoint = Endpoint.glossary
print(endpoint.path)             // "/glossary"
print(endpoint.accept.rawValue)  // "application/ld+json"

// Send a GET to https://api.weather.gov plus endpoint.path with that Accept header and a
// User-Agent identifying your application, then:
let glossary = try JSONDecoder().decode(WeatherGlossary.self, from: body)
print(glossary.entries.count, glossary.entries.first?.term as Any)
```

The service offers this resource only as JSON-LD, so the endpoint asks for ``MediaType/jsonLD``. It
carries no query items and no feature flags, because the service documents no page size and no cursor
for the glossary. There is nothing to send alongside the path and no continuation to read out of the
answer.

## Execution

`WeatherRequest.glossary` wraps that endpoint through `WeatherRequest(endpoint:)`, so its resolution
is the plain endpoint case:

```swift
let request = WeatherRequest.glossary
if case .endpoint(let endpoint) = request.resolution {
  print(endpoint.path)  // "/glossary"
}
```

There is no glossary resolution case, because there would be nothing for one to describe. A custom
executor sends that one endpoint and decodes the whole body as ``WeatherGlossary``: there is no
identifier to reject before sending, no GeoJSON envelope to unwrap, and no second request to make.
See <doc:ExecutingRequests> for the resolutions that do describe multi-request work.

The same endpoint decodes a response model of your own, when you want less than the full glossary:

```swift
struct GlossaryTerms: Decodable, Sendable {
  struct Term: Decodable, Sendable {
    let term: String
  }

  let glossary: [Term]
}

if let endpoint = Endpoint<GlossaryTerms>(accept: .jsonLD, path: "/glossary") {
  let request = WeatherRequest(endpoint: endpoint)
}
```

## Entries

``WeatherGlossary/entries`` decodes from the body's `glossary` key and is required. A body without
that key, or one whose value is not an array of entries, fails to decode rather than producing an
empty glossary, so an empty result and a missing result stay distinct. An explicitly empty array
decodes as no entries. The JSON-LD `@context` key is ignored.

| Property | Type | Notes |
|---|---|---|
| ``GlossaryEntry/definition`` | `String` | The service's description of the term, with its markup and line endings unchanged. |
| ``GlossaryEntry/term`` | `String` | The term as the service spells it, such as `AGL`. |
| ``WeatherGlossary/entries`` | `[GlossaryEntry]` | The entries in the order the service listed them. |

Both entry fields are required, and an entry missing either one fails to decode.

Entries are an array rather than a dictionary because terms repeat. One recorded response held 3,183
entries under 3,175 distinct terms, including two `AGL` entries whose definitions differed only in
trailing whitespace, so keying by term would drop one of each such pair. That count is what one
recording held, not a size the service promises. Read a term as a filter that can match several
entries rather than as a unique key, and choose for yourself whether to group, deduplicate, or sort:

```swift
let matches = glossary.entries.filter { $0.term == "AGL" }
let byTerm = Dictionary(grouping: glossary.entries, by: \.term)
```

## Definitions

A definition is kept exactly as sent. Definitions carry HTML markup such as `<br>`, character
entities such as `&frac12;` and `&deg;`, and carriage return line endings inside a paragraph, and
these models change none of it:

```swift
// A recorded definition, shown with its escapes:
// "1. Abbrevation for hail in weather observations.\r\n<br>\r\n<br>\r\n2. Symbol used on ..."
```

Nothing here renders, escapes, strips, or normalizes that text, and nothing converts it to an
attributed string. A definition placed directly into a control that does not interpret markup shows
the tags and entities instead of the meaning, so decide how to present it before displaying it.
Links and references inside a definition are text as well: they are not resolved or fetched.

These models also add no search index, fuzzy matching, or term normalization, and no caching. The
glossary is one request whose whole answer you receive and keep yourself.

## Topics

### Glossary

- ``GlossaryEntry``
- ``WeatherGlossary``

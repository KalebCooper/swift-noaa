# Reading the glossary

Retrieve the service's glossary of weather terms, with each definition exactly as the service wrote it.

## Overview

The glossary is the service's own list of weather terms and their definitions, at `/glossary`. It
arrives in one response.

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(example.com, contact@example.com)")
let glossary = try await weather.glossary()
for entry in glossary.entries.prefix(3) {
  print(entry.term, entry.definition)
}
```

The same lookup is available at three levels:

- ``NWSClient/glossary()`` returns the glossary.
- `WeatherRequest.glossary` describes it as a reusable value for ``NWSClient/value(for:)``, returning
  the same glossary.
- `Endpoint.glossary` is the single HTTP operation, for ``NWSClient/send(_:)`` or another networking
  stack.

```swift
let stored = WeatherRequest.glossary
let reusable = try await weather.value(for: stored)
let direct = try await weather.send(.glossary)
```

All three send one GET to `/glossary` asking for `application/ld+json`, the only representation the
service offers for this resource, and return the same value. The endpoint carries no query items and
no feature flags.

### Entries are a list

`WeatherGlossary.entries` is an array, in the order the service listed the terms, because the service
repeats terms. One recorded response carried two `AGL` entries whose definitions differed only in
trailing whitespace. Keying the list by term would silently drop one of each such pair, so the
package keeps the array and leaves the choice to you:

```swift
let matches = glossary.entries.filter { $0.term == "AGL" }
let byTerm = Dictionary(grouping: glossary.entries, by: \.term)
```

A term does not identify an entry. Treat a term lookup as a filter that can return more than one
result rather than as a key.

### Definitions are markup

A definition is the service's text, unchanged. It can contain HTML tags such as `<br>`, character
entities such as `&frac12;` and `&deg;`, and carriage return line endings inside a paragraph. The
client does not render, escape, strip, or normalize any of that, and it does not produce attributed
strings.

Presenting a definition is therefore your app's decision. Text placed directly into a control that
does not interpret markup shows the tags and entities instead of the meaning, so convert or escape a
definition on the way to the screen:

```swift
let entry = glossary.entries[6]
print(entry.definition)  // May contain "<br>" and "&deg;" and "\r\n"
```

### What the lookup does not do

- The service documents no page size and no cursor for `/glossary`, so the endpoint sends neither and
  there are no glossary page or item sequences. That describes the request, not the size of the
  answer. See <doc:PaginatingCollections> for the collections that do continue.
- Nothing is cached. Each call sends a request. ``PointCache`` covers coordinate lookups only.
- There is no search index, fuzzy matching, or term normalization. Filtering, sorting, and
  deduplicating are yours to choose.
- Links and references inside a definition are text. The client does not resolve or fetch them.

Redirects, refusals, and cancellation behave as they do for every other endpoint request. A redirect
is validated against the HTTPS API origin, and one that leaves it throws ``NWSError/invalidLink(_:)``
rather than being followed. The service's refusal arrives as ``NWSError/problem(_:)`` with its
details, and cancellation is checked before the request is sent.

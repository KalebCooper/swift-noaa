import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Observation-station pagination", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ObservationStationPaginationTests {
  @Test("Cancellation before the first read sends nothing")
  @MainActor
  func cancellationBeforeTheFirstReadSendsNothing() async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let query = try ObservationStationQuery()
    let task = Task { () throws -> NWSError? in
      var iterator = client.observationStationPages(query: query).makeAsyncIterator()
      let error = await #expect(throws: NWSError.self) { try await iterator.next() }
      #expect(try await iterator.next() == nil)
      return error
    }
    task.cancel()
    guard case .transport(.cancelled) = try await task.value else {
      Issue.record("Expected cancellation")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test(
    "Cancellation between reads ends both page and buffered-item iterators",
    arguments: [false, true])
  func cancellationBetweenReadsEndsBothPageAndBufferedItemIterators(items: Bool) async throws {
    let transport = MockTransport()
    try answer(
      transport, page: page(next: "https://api.weather.gov/stations?cursor=2"))
    let client = makeClient(transport)
    let query = try ObservationStationQuery()
    let started = AsyncStream<Void>.makeStream()
    let resume = AsyncStream<Void>.makeStream()
    let task = Task {
      defer { started.continuation.finish() }
      if items {
        var iterator = client.observationStations(query: query).makeAsyncIterator()
        _ = try await iterator.next()
        started.continuation.yield()
        for await _ in resume.stream {}
        let error = await #expect(throws: NWSError.self) { try await iterator.next() }
        #expect(try await iterator.next() == nil)
        return error
      } else {
        var iterator = client.observationStationPages(query: query).makeAsyncIterator()
        _ = try await iterator.next()
        started.continuation.yield()
        for await _ in resume.stream {}
        let error = await #expect(throws: NWSError.self) { try await iterator.next() }
        #expect(try await iterator.next() == nil)
        return error
      }
    }
    for await _ in started.stream { break }
    task.cancel()
    resume.continuation.finish()
    guard case .transport(.cancelled) = try await task.value else {
      Issue.record("Expected cancellation")
      return
    }
    #expect(transport.requests.count == 1)
  }

  @Test("Continuation links preserve the exact encoded path and headers")
  func continuationLinksPreserveTheExactEncodedPathAndHeaders() async throws {
    let transport = MockTransport()
    let path = "/stations?id%5B0%5D=KATT&cursor=a%2Fb%3D&limit=1"
    try answer(
      transport, page: page(next: "https://api.weather.gov" + path))
    try answer(transport, page: page())
    var iterator = makeClient(transport).observationStationPages(
      query: try ObservationStationQuery()
    ).makeAsyncIterator()
    #expect(try await iterator.next() != nil)
    #expect(transport.requests.count == 1)
    #expect(try await iterator.next() != nil)
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.map(\.request.path) == ["/stations?limit=500", path])
    #expect(
      transport.requests.allSatisfy {
        $0.request.headerFields[.accept] == "application/geo+json"
          && $0.request.headerFields[.userAgent] == "tests"
      })
  }

  @Test("Custom endpoint headers survive redirects")
  func customEndpointHeadersSurviveRedirects() async throws {
    let transport = MockTransport()
    transport.enqueue(
      .success(.init(Response(body: Data(), headers: [.location: "/canonical"], status: .found))))
    try answer(transport, page: page())
    let endpoint = Endpoint<FeatureCollection<ObservationStation>>(
      accept: .init(rawValue: "application/ld+json"),
      featureFlags: [.init(rawValue: "future_flag")], path: "/custom")
    var iterator = makeClient(transport).observationStationPages(for: .init(endpoint: endpoint))
      .makeAsyncIterator()
    #expect(try await iterator.next() != nil)
    #expect(try await iterator.next() == nil)
    let flag = try #require(HTTPField.Name("Feature-Flags"))
    #expect(
      transport.requests.allSatisfy {
        $0.request.headerFields[.accept] == "application/ld+json"
          && $0.request.headerFields[flag] == "future_flag"
      })
  }

  @Test("Custom endpoint requests remain one page even with malformed pagination")
  func customEndpointRequestsRemainOnePageEvenWithMalformedPagination() async throws {
    let transport = MockTransport()
    try answer(transport, page: page(next: "bad link"))
    let client = makeClient(transport)
    let request = WeatherRequest(
      endpoint: Endpoint<FeatureCollection<ObservationStation>>(path: "/custom"))
    var iterator = client.observationStationPages(for: request).makeAsyncIterator()
    #expect(try await iterator.next() != nil)
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.count == 1)
  }

  @Test(
    "Disallowed redirects end the iterator without sending their targets",
    arguments: [
      "https://example.com/stations", "https://user@api.weather.gov/stations",
      "https://api.weather.gov/stations#fragment",
    ])
  func disallowedRedirectsEndTheIteratorWithoutSendingTheirTargets(location: String) async throws {
    let transport = MockTransport()
    transport.enqueue(
      .success(.init(Response(body: Data(), headers: [.location: location], status: .found))))
    var iterator = makeClient(transport).observationStationPages(
      query: try ObservationStationQuery()
    ).makeAsyncIterator()
    let error = await #expect(throws: NWSError.self) { try await iterator.next() }
    guard case .invalidLink = error else { Issue.record("Expected invalid redirect link"); return }
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.count == 1)
  }

  @Test("Empty pages continue and items equal flattened pages")
  func emptyPagesContinueAndItemsEqualFlattenedPages() async throws {
    let transport = MockTransport()
    let query = try ObservationStationQuery()
    var empty = try page(next: "https://api.weather.gov/stations?cursor=2")
    empty.features = []
    let terminal = try page()
    try answer(transport, page: empty)
    try answer(transport, page: terminal)
    try answer(transport, page: empty)
    try answer(transport, page: terminal)
    let client = makeClient(transport)
    var pages: [FeatureCollection<ObservationStation>] = []
    for try await page in client.observationStationPages(query: query) { pages.append(page) }
    var items: [Feature<ObservationStation>] = []
    for try await item in client.observationStations(query: query) { items.append(item) }
    #expect(pages.count == 2)
    #expect(items == pages.flatMap(\.features))
    #expect(transport.requests.count == 4)
  }

  @Test(
    "Invalid next links fail before exposing their page",
    arguments: [
      "", "not a link", "/stations?cursor=2", "http://api.weather.gov/stations",
      "https://example.com/stations", "https://api.weather.gov:444/stations",
      "https://user@api.weather.gov/stations", "https://api.weather.gov/stations#fragment",
    ])
  func invalidNextLinksFailBeforeExposingTheirPage(raw: String) async throws {
    let transport = MockTransport()
    try answer(transport, page: page(next: raw))
    var iterator = makeClient(transport).observationStationPages(
      query: try ObservationStationQuery()
    ).makeAsyncIterator()
    let error = await #expect(throws: NWSError.self) { try await iterator.next() }
    guard case .pagination(.invalidNext(let actual)) = error else {
      Issue.record("Expected invalid continuation")
      return
    }
    #expect(actual == raw)
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.count == 1)
  }

  @Test("Later HTTP and decoding failures end iteration", arguments: [false, true])
  func laterHTTPAndDecodingFailuresEndIteration(problem: Bool) async throws {
    let transport = MockTransport()
    try answer(
      transport, page: page(next: "https://api.weather.gov/stations?cursor=2"))
    let body = problem ? try Fixture.problemDetail.data() : Data("not json".utf8)
    transport.enqueue(.success(.init(Response(body: body, status: problem ? .notFound : .ok))))
    var iterator = makeClient(transport).observationStationPages(
      query: try ObservationStationQuery()
    ).makeAsyncIterator()
    #expect(try await iterator.next() != nil)
    let error = await #expect(throws: NWSError.self) { try await iterator.next() }
    if problem {
      guard case .problem = error else { Issue.record("Expected problem details"); return }
    } else {
      guard case .transport(.decode) = error else {
        Issue.record("Expected decoding error"); return
      }
    }
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.count == 2)
  }

  @Test("Missing continuation metadata fails before yielding")
  func missingContinuationMetadataFailsBeforeYielding() async throws {
    let transport = MockTransport()
    var invalid = try page()
    invalid.pagination = PaginationInfo()
    try answer(transport, page: invalid)
    var iterator = makeClient(transport).observationStationPages(
      query: try ObservationStationQuery()
    ).makeAsyncIterator()
    let error = await #expect(throws: NWSError.self) { try await iterator.next() }
    guard case .pagination(.missingNext) = error else {
      Issue.record("Expected missing next"); return
    }
    #expect(try await iterator.next() == nil)
  }

  @Test("Redirect loops and hop limits end the iterator", arguments: [false, true])
  func redirectLoopsAndHopLimitsEndTheIterator(loop: Bool) async throws {
    let transport = MockTransport()
    for hop in 1...6 {
      let location = loop ? "/stations?limit=500" : "/hop/\(hop)"
      transport.enqueue(
        .success(.init(Response(body: Data(), headers: [.location: location], status: .found))))
    }
    var iterator = makeClient(transport).observationStationPages(
      query: try ObservationStationQuery()
    ).makeAsyncIterator()
    let error = await #expect(throws: NWSError.self) { try await iterator.next() }
    guard case .tooManyRedirects = error else { Issue.record("Expected redirect limit"); return }
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.count == (loop ? 1 : 6))
  }

  @Test("Redirects preserve headers and resume pagination")
  func redirectsPreserveHeadersAndResumePagination() async throws {
    let transport = MockTransport()
    transport.enqueue(
      .success(
        .init(Response(body: Data(), headers: [.location: "/canonical"], status: .movedPermanently))
      ))
    try answer(
      transport, page: page(next: "https://api.weather.gov/stations?cursor=2"))
    try answer(transport, page: page())
    var iterator = makeClient(transport).observationStationPages(
      query: try ObservationStationQuery()
    ).makeAsyncIterator()
    #expect(try await iterator.next() != nil)
    #expect(try await iterator.next() != nil)
    #expect(try await iterator.next() == nil)
    #expect(
      transport.requests.map(\.request.path) == [
        "/stations?limit=500", "/canonical", "/stations?cursor=2",
      ])
    #expect(transport.requests.allSatisfy { $0.request.headerFields[.userAgent] == "tests" })
  }

  @Test("Repeated and cyclic links fail on the page that declares them", arguments: [false, true])
  func repeatedAndCyclicLinksFailOnThePageThatDeclaresThem(cycle: Bool) async throws {
    let transport = MockTransport()
    let first = "https://api.weather.gov/stations?limit=500"
    let second = "https://api.weather.gov/stations?cursor=2"
    try answer(transport, page: page(next: cycle ? second : first))
    try answer(transport, page: page(next: first))
    var iterator = makeClient(transport).observationStationPages(
      query: try ObservationStationQuery()
    ).makeAsyncIterator()
    if cycle { #expect(try await iterator.next() != nil) }
    let error = await #expect(throws: NWSError.self) { try await iterator.next() }
    guard case .pagination(.repeatedNext(let actual)) = error else {
      Issue.record("Expected repeated next"); return
    }
    #expect(actual == first)
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.count == (cycle ? 2 : 1))
  }

  @Test("Sequence and request factories infer concrete responses without I/O")
  func sequenceAndRequestFactoriesInferConcreteResponsesWithoutIO() throws {
    let transport = MockTransport()
    let client = NWSClient(configuration: .init(userAgent: "tests"), transport: transport)
    let query = try ObservationStationQuery()
    let request = WeatherRequest.observationStations(query: query)
    let _: ObservationStationPageSequence = client.observationStationPages(query: query)
    let _: ObservationStationSequence = client.observationStations(query: query)
    let _: ObservationStationPageSequence = client.observationStationPages(for: request)
    let _: ObservationStationSequence = client.observationStations(
      for: .observationStations(query: query))
    let custom = WeatherRequest(
      endpoint: Endpoint<FeatureCollection<ObservationStation>>(path: "/custom"))
    let _: ObservationStationPageSequence = client.observationStationPages(for: custom)
    #expect(transport.requests.isEmpty)
  }

  @Test("Sequences are lazy, independently iterable, and never prefetch")
  func sequencesAreLazyIndependentlyIterableAndNeverPrefetch() async throws {
    let transport = MockTransport()
    try answer(
      transport, page: page(next: "https://api.weather.gov/stations?cursor=2"))
    try answer(
      transport, page: page(next: "https://api.weather.gov/stations?cursor=2"))
    try answer(
      transport, page: page(next: "https://api.weather.gov/stations?cursor=2"))
    let sequence = makeClient(transport).observationStationPages(
      query: try ObservationStationQuery())
    var first = sequence.makeAsyncIterator()
    var second = sequence.makeAsyncIterator()
    #expect(transport.requests.isEmpty)
    #expect(try await first.next() == second.next())
    #expect(transport.requests.count == 2)
    for try await _ in sequence { break }
    #expect(transport.requests.count == 3)
  }

  @Test("Single-page and sequence access levels return the same first page")
  func singlePageAndSequenceAccessLevelsReturnTheSameFirstPage() async throws {
    let transport = MockTransport()
    let expected = try page(next: "https://api.weather.gov/stations?cursor=2")
    for _ in 0..<4 { try answer(transport, page: expected) }
    let client = makeClient(transport)
    let query = try ObservationStationQuery(cursor: "start", limit: 1)
    let request = WeatherRequest.observationStations(query: query)
    let direct = try await client.send(.observationStations(query: query))
    let value = try await client.value(for: request)
    var everyday = client.observationStationPages(query: query).makeAsyncIterator()
    var reusable = client.observationStationPages(for: request).makeAsyncIterator()
    #expect(direct == expected)
    #expect(value == direct)
    #expect(try await everyday.next() == expected)
    #expect(try await reusable.next() == expected)
    #expect(transport.requests.allSatisfy { $0.request.path == "/stations?cursor=start&limit=1" })
  }

  private func answer(
    _ transport: MockTransport, page: FeatureCollection<ObservationStation>
  ) throws {
    let body = try JSONEncoder().encode(page)
    transport.enqueue(.success(.init(Response(body: body, status: .ok))))
  }

  private func compileResponses(_ client: NWSClient, query: ObservationStationQuery) async throws {
    let page = try await client.value(for: .observationStations(query: query))
    let direct = try await client.send(.observationStations(query: query))
    let _: FeatureCollection<ObservationStation> = page
    let _: FeatureCollection<ObservationStation> = direct
    for try await page in client.observationStationPages(query: query) {
      let _: FeatureCollection<ObservationStation> = page
    }
    for try await feature in client.observationStations(query: query) {
      let _: ObservationStation = feature.properties
    }
  }

  private func makeClient(_ transport: MockTransport) -> NWSClient {
    NWSClient(configuration: .init(userAgent: "tests"), transport: transport)
  }

  // Variants derive from the recorded station collection; they are not live response captures.
  private func page(next: String? = nil) throws -> FeatureCollection<ObservationStation> {
    var page = try JSONDecoder().decode(
      FeatureCollection<ObservationStation>.self, from: Fixture.observationStations.data())
    page.pagination = next.map { PaginationInfo(next: $0) }
    return page
  }
}

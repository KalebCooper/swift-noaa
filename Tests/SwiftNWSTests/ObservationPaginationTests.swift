import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Observation-history pagination", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ObservationPaginationTests {
  private static let recordedPath =
    "/stations/KATT/observations?end=2026-09-17T00:00:00Z&limit=2&start=2026-09-16T00:00:00Z"

  @Test("Await selects one page and iteration selects features")
  func awaitSelectsOnePageAndIterationSelectsFeatures() async throws {
    let transport = MockTransport()
    let expected = try page()
    for _ in 0..<5 { try answer(transport, page: expected) }
    let client = makeClient(transport)
    let query = try recordedQuery()
    let request = WeatherRequest.observations(query: query)
    let single = try await client.observations(query: query)
    let _: FeatureCollection<WeatherObservation> = single
    let sequence: ObservationSequence = client.observations(query: query)
    let _: ObservationPageSequence = client.observationPages(query: query)
    let _: ObservationPageSequence = client.observationPages(for: request)
    let _: ObservationSequence = client.observations(for: .observations(query: query))
    let _: ObservationSequence = client.observations(for: try .campMabryHistory)
    #expect(single == expected)
    #expect(try await client.value(for: request) == single)
    #expect(try await client.send(.observations(query: query)) == single)
    for try await feature in sequence {
      #expect(feature == expected.features.first)
      break
    }
    for try await feature in client.observations(query: query) {
      let _: WeatherObservation = feature.properties
      break
    }
    #expect(transport.requests.count == 5)
    #expect(transport.requests.allSatisfy { $0.request.path == Self.recordedPath })
    #expect(
      transport.requests.allSatisfy {
        $0.request.headerFields[.accept] == "application/geo+json"
          && $0.request.headerFields[.userAgent] == "observation-history-tests"
      })
  }

  @Test("Cancellation before the first read sends nothing")
  @MainActor
  func cancellationBeforeTheFirstReadSendsNothing() async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let query = try ObservationQuery(stationIdentifier: "KATT")
    let task = Task { () throws -> NWSError? in
      var iterator = client.observationPages(query: query).makeAsyncIterator()
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
    try answer(transport, page: page())
    let client = makeClient(transport)
    let query = try recordedQuery()
    let started = AsyncStream<Void>.makeStream()
    let resume = AsyncStream<Void>.makeStream()
    let task = Task {
      defer { started.continuation.finish() }
      if items {
        var iterator = client.observations(query: query).makeAsyncIterator()
        _ = try await iterator.next()
        started.continuation.yield()
        for await _ in resume.stream {}
        let error = await #expect(throws: NWSError.self) { try await iterator.next() }
        #expect(try await iterator.next() == nil)
        return error
      } else {
        var iterator = client.observationPages(query: query).makeAsyncIterator()
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

  @Test("Custom endpoint requests remain one page even with malformed pagination")
  func customEndpointRequestsRemainOnePageEvenWithMalformedPagination() async throws {
    let transport = MockTransport()
    try answer(transport, page: page(next: "bad link"))
    let request = WeatherRequest(
      endpoint: try #require(Endpoint<FeatureCollection<WeatherObservation>>(path: "/custom")))
    var iterator = makeClient(transport).observations(for: request).makeAsyncIterator()
    var features: [Feature<WeatherObservation>] = []
    while let feature = try await iterator.next() { features.append(feature) }
    #expect(features == (try page()).features)
    #expect(transport.requests.map(\.request.path) == ["/custom"])
  }

  @Test("Empty pages continue and items equal flattened pages")
  func emptyPagesContinueAndItemsEqualFlattenedPages() async throws {
    let transport = MockTransport()
    let query = try recordedQuery()
    var empty = try page(next: "https://api.weather.gov/stations/KATT/observations?cursor=2")
    empty.features = []
    let terminal = try page(next: nil)
    for _ in 0..<2 {
      try answer(transport, page: empty)
      try answer(transport, page: terminal)
    }
    let client = makeClient(transport)
    var pages: [FeatureCollection<WeatherObservation>] = []
    for try await page in client.observationPages(query: query) { pages.append(page) }
    var items: [Feature<WeatherObservation>] = []
    for try await item in client.observations(query: query) { items.append(item) }
    #expect(pages.count == 2)
    #expect(items == pages.flatMap(\.features))
    #expect(items.count == 2)
    #expect(transport.requests.count == 4)
  }

  @Test(
    "Invalid next links fail before exposing their page",
    arguments: [
      "", "not a link", "/stations/KATT/observations?cursor=2",
      "https://example.com/stations/KATT/observations",
    ])
  func invalidNextLinksFailBeforeExposingTheirPage(raw: String) async throws {
    let transport = MockTransport()
    try answer(transport, page: page(next: raw))
    var iterator = makeClient(transport).observationPages(query: try recordedQuery())
      .makeAsyncIterator()
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
    try answer(transport, page: page())
    let body = problem ? try Fixture.problemDetail.data() : Data("not json".utf8)
    transport.enqueue(.success(.init(Response(body: body, status: problem ? .notFound : .ok))))
    var iterator = makeClient(transport).observationPages(query: try recordedQuery())
      .makeAsyncIterator()
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

  @Test("Repeated and cyclic links fail on the page that declares them", arguments: [false, true])
  func repeatedAndCyclicLinksFailOnThePageThatDeclaresThem(cycle: Bool) async throws {
    let transport = MockTransport()
    let first = "https://api.weather.gov" + Self.recordedPath
    let second = "https://api.weather.gov/stations/KATT/observations?cursor=2"
    try answer(transport, page: page(next: cycle ? second : first))
    try answer(transport, page: page(next: first))
    var iterator = makeClient(transport).observationPages(query: try recordedQuery())
      .makeAsyncIterator()
    if cycle { #expect(try await iterator.next() != nil) }
    let error = await #expect(throws: NWSError.self) { try await iterator.next() }
    guard case .pagination(.repeatedNext(let actual)) = error else {
      Issue.record("Expected repeated next"); return
    }
    #expect(actual == first)
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.count == (cycle ? 2 : 1))
  }

  @Test("Sequences are lazy, independently iterable, and never prefetch")
  func sequencesAreLazyIndependentlyIterableAndNeverPrefetch() async throws {
    let transport = MockTransport()
    for _ in 0..<3 { try answer(transport, page: page()) }
    let sequence = makeClient(transport).observationPages(query: try recordedQuery())
    var first = sequence.makeAsyncIterator()
    var second = sequence.makeAsyncIterator()
    #expect(transport.requests.isEmpty)
    #expect(try await first.next() == second.next())
    #expect(transport.requests.count == 2)
    for try await _ in sequence { break }
    #expect(transport.requests.count == 3)
  }

  @Test("The recorded continuation link is followed exactly as the service sent it")
  func theRecordedContinuationLinkIsFollowedExactlyAsTheServiceSentIt() async throws {
    let transport = MockTransport()
    let recorded = try page()
    let next = try #require(recorded.pagination?.next)
    try answer(transport, page: recorded)
    try answer(transport, page: page(next: nil))
    var iterator = makeClient(transport).observationPages(query: try recordedQuery())
      .makeAsyncIterator()
    #expect(try await iterator.next() == recorded)
    #expect(transport.requests.count == 1)
    #expect(try await iterator.next() != nil)
    #expect(try await iterator.next() == nil)
    #expect(
      transport.requests.map(\.request.path) == [
        Self.recordedPath, String(next.dropFirst("https://api.weather.gov".count)),
      ])
  }

  private func answer(
    _ transport: MockTransport, page: FeatureCollection<WeatherObservation>
  ) throws {
    transport.enqueue(.success(.init(Response(body: try JSONEncoder().encode(page), status: .ok))))
  }

  private func makeClient(_ transport: MockTransport) -> NWSClient {
    NWSClient(configuration: .init(userAgent: "observation-history-tests"), transport: transport)
  }

  // The recorded page keeps its live continuation link; variants replace it and are not captures.
  private func page(next: String?) throws -> FeatureCollection<WeatherObservation> {
    var page = try page()
    page.pagination = next.map { PaginationInfo(next: $0) }
    return page
  }

  private func page() throws -> FeatureCollection<WeatherObservation> {
    try JSONDecoder().decode(
      FeatureCollection<WeatherObservation>.self, from: Fixture.observationHistory.data())
  }

  private func recordedQuery() throws -> ObservationQuery {
    // 2026-09-16T00:00:00Z through 2026-09-17T00:00:00Z, the recorded window.
    try ObservationQuery(
      end: Date(timeIntervalSince1970: 1_789_603_200), limit: 2,
      start: Date(timeIntervalSince1970: 1_789_516_800), stationIdentifier: "KATT")
  }
}

extension WeatherRequest where Response == FeatureCollection<WeatherObservation> {
  fileprivate static var campMabryHistory: Self {
    get throws {
      .observations(query: try ObservationQuery(limit: 24, stationIdentifier: "KATT"))
    }
  }
}

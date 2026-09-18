import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Alert-history pagination", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct AlertHistoryPaginationTests {
  private static let recordedPath =
    "/alerts?area=TX&end=2026-09-17T00:00:00Z&limit=2&start=2026-09-16T00:00:00Z&status=actual"

  @Test("Await selects one page and iteration selects features")
  func awaitSelectsOnePageAndIterationSelectsFeatures() async throws {
    let transport = MockTransport()
    let expected = try page()
    for _ in 0..<5 { try answer(transport, page: expected) }
    let client = makeClient(transport)
    let query = try recordedQuery()
    let request = WeatherRequest.alerts(matching: query)
    let single = try await client.alerts(matching: query)
    let _: FeatureCollection<WeatherAlert> = single
    let sequence: AlertSequence = client.alerts(matching: query)
    let _: AlertPageSequence = client.alertPages(matching: query)
    let _: AlertPageSequence = client.alertPages(for: request)
    let _: AlertSequence = client.alerts(for: .alerts(matching: query))
    let _: AlertSequence = client.alerts(for: try .yesterdaysTexasAlerts)
    #expect(single == expected)
    #expect(try await client.value(for: request) == single)
    #expect(try await client.send(.alerts(matching: query)) == single)
    for try await feature in sequence {
      #expect(feature == expected.features.first)
      break
    }
    for try await feature in client.alerts(matching: query) {
      let _: WeatherAlert = feature.properties
      break
    }
    #expect(transport.requests.count == 5)
    #expect(transport.requests.allSatisfy { $0.request.path == Self.recordedPath })
  }

  @Test("Cancellation before the first read sends nothing")
  @MainActor
  func cancellationBeforeTheFirstReadSendsNothing() async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let query = try AlertQuery()
    let task = Task { () throws -> NWSError? in
      var iterator = client.alertPages(matching: query).makeAsyncIterator()
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

  @Test("Canonical redirects retain headers and continue through the page pipeline")
  func canonicalRedirectsRetainHeadersAndContinueThroughThePagePipeline() async throws {
    let transport = MockTransport()
    // The OpenAPI response for /alerts documents this possible 301.
    transport.enqueue(
      .success(
        .init(Response(headers: [.location: "/alerts/canonical"], status: .movedPermanently))))
    let next = "/alerts?cursor=a%2Fb%3D"
    try answer(transport, page: page(next: "https://api.weather.gov" + next))
    try answer(transport, page: page(next: nil))
    var iterator = makeClient(transport).alertPages(matching: try AlertQuery())
      .makeAsyncIterator()
    #expect(transport.requests.isEmpty)
    #expect(try await iterator.next() != nil)
    #expect(transport.requests.count == 2)
    #expect(try await iterator.next() != nil)
    #expect(try await iterator.next() == nil)
    #expect(
      transport.requests.map(\.request.path) == ["/alerts?limit=500", "/alerts/canonical", next])
    #expect(
      transport.requests.allSatisfy {
        $0.request.headerFields[.accept] == "application/geo+json"
          && $0.request.headerFields[.userAgent] == "alert-history-tests"
      })
  }

  @Test("Custom endpoint requests remain one page even with malformed pagination")
  func customEndpointRequestsRemainOnePageEvenWithMalformedPagination() async throws {
    let transport = MockTransport()
    try answer(transport, page: page(next: "bad link"))
    let request = WeatherRequest(
      endpoint: Endpoint<FeatureCollection<WeatherAlert>>(path: "/custom"))
    var iterator = makeClient(transport).alerts(for: request).makeAsyncIterator()
    var features: [Feature<WeatherAlert>] = []
    while let feature = try await iterator.next() { features.append(feature) }
    #expect(features == (try page()).features)
    #expect(transport.requests.map(\.request.path) == ["/custom"])
  }

  @Test("Empty pages continue and items equal flattened pages")
  func emptyPagesContinueAndItemsEqualFlattenedPages() async throws {
    let transport = MockTransport()
    let query = try recordedQuery()
    var empty = try page(next: "https://api.weather.gov/alerts?cursor=2")
    empty.features = []
    let terminal = try page(next: nil)
    for _ in 0..<2 {
      try answer(transport, page: empty)
      try answer(transport, page: terminal)
    }
    let client = makeClient(transport)
    var pages: [FeatureCollection<WeatherAlert>] = []
    for try await page in client.alertPages(matching: query) { pages.append(page) }
    var items: [Feature<WeatherAlert>] = []
    for try await item in client.alerts(matching: query) { items.append(item) }
    #expect(pages.count == 2)
    #expect(items == pages.flatMap(\.features))
    #expect(items.count == 2)
    #expect(transport.requests.count == 4)
  }

  @Test(
    "Invalid next links fail before exposing their page",
    arguments: ["", "not a link", "/alerts?cursor=2", "https://example.com/alerts"])
  func invalidNextLinksFailBeforeExposingTheirPage(raw: String) async throws {
    let transport = MockTransport()
    try answer(transport, page: page(next: raw))
    var iterator = makeClient(transport).alertPages(matching: try AlertQuery())
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

  @Test("Later HTTP failures end iteration after the pages already yielded")
  func laterHTTPFailuresEndIterationAfterThePagesAlreadyYielded() async throws {
    let transport = MockTransport()
    try answer(transport, page: page())
    transport.enqueue(
      .success(.init(Response(body: try Fixture.problemDetail.data(), status: .notFound))))
    var iterator = makeClient(transport).alerts(matching: try recordedQuery()).makeAsyncIterator()
    #expect(try await iterator.next() != nil)
    #expect(try await iterator.next() != nil)
    let error = await #expect(throws: NWSError.self) { try await iterator.next() }
    guard case .problem = error else { Issue.record("Expected problem details"); return }
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.count == 2)
  }

  @Test(
    "Library alert requests follow links through either alert executor", arguments: [false, true])
  func libraryAlertRequestsFollowLinksThroughEitherAlertExecutor(history: Bool) async throws {
    let transport = MockTransport()
    let next = "/alerts?cursor=next"
    try answer(transport, page: page(next: "https://api.weather.gov" + next))
    try answer(transport, page: page(next: nil))
    let client = makeClient(transport)
    let request: WeatherRequest<FeatureCollection<WeatherAlert>> =
      history ? .alerts(matching: try AlertQuery(limit: 1)) : .activeAlerts(inArea: .texas)
    let first = history ? "/alerts?limit=1" : "/alerts/active/area/TX"
    var pages: [FeatureCollection<WeatherAlert>] = []
    if history {
      for try await page in client.activeAlertPages(for: request) { pages.append(page) }
    } else {
      for try await page in client.alertPages(for: request) { pages.append(page) }
    }
    #expect(pages.count == 2)
    #expect(transport.requests.map(\.request.path) == [first, next])
  }

  @Test("The recorded continuation link is followed exactly as the service sent it")
  func theRecordedContinuationLinkIsFollowedExactlyAsTheServiceSentIt() async throws {
    let transport = MockTransport()
    let recorded = try page()
    let next = try #require(recorded.pagination?.next)
    try answer(transport, page: recorded)
    try answer(transport, page: page(next: nil))
    var iterator = makeClient(transport).alertPages(matching: try recordedQuery())
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

  @Test("Sequences are lazy, independently iterable, and never prefetch")
  func sequencesAreLazyIndependentlyIterableAndNeverPrefetch() async throws {
    let transport = MockTransport()
    for _ in 0..<3 { try answer(transport, page: page()) }
    let sequence = makeClient(transport).alertPages(matching: try recordedQuery())
    var first = sequence.makeAsyncIterator()
    var second = sequence.makeAsyncIterator()
    #expect(transport.requests.isEmpty)
    #expect(try await first.next() == second.next())
    #expect(transport.requests.count == 2)
    for try await _ in sequence { break }
    #expect(transport.requests.count == 3)
  }

  private func answer(_ transport: MockTransport, page: FeatureCollection<WeatherAlert>) throws {
    transport.enqueue(.success(.init(Response(body: try JSONEncoder().encode(page), status: .ok))))
  }

  private func makeClient(_ transport: MockTransport) -> NWSClient {
    NWSClient(configuration: .init(userAgent: "alert-history-tests"), transport: transport)
  }

  // The recorded page keeps its live continuation link; variants replace it and are not captures.
  private func page(next: String?) throws -> FeatureCollection<WeatherAlert> {
    var page = try page()
    page.pagination = next.map { PaginationInfo(next: $0) }
    return page
  }

  private func page() throws -> FeatureCollection<WeatherAlert> {
    try JSONDecoder().decode(
      FeatureCollection<WeatherAlert>.self, from: Fixture.alertHistory.data())
  }

  private func recordedQuery() throws -> AlertQuery {
    // 2026-09-16T00:00:00Z through 2026-09-17T00:00:00Z, the recorded window.
    try AlertQuery(
      end: Date(timeIntervalSince1970: 1_789_603_200),
      filter: .init(location: .areas([.texas]), status: [.actual]), limit: 2,
      start: Date(timeIntervalSince1970: 1_789_516_800))
  }
}

extension WeatherRequest where Response == FeatureCollection<WeatherAlert> {
  fileprivate static var yesterdaysTexasAlerts: Self {
    get throws {
      .alerts(
        matching: try AlertQuery(
          end: Date(timeIntervalSince1970: 1_789_603_200),
          filter: .init(location: .areas([.texas])),
          start: Date(timeIntervalSince1970: 1_789_516_800)))
    }
  }
}

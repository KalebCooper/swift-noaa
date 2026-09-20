import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Active-alert pagination", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct AlertPaginationTests {
  @Test("Await selects one page and iteration selects features")
  func awaitSelectsOnePageAndIterationSelectsFeatures() async throws {
    let transport = MockTransport()
    let expected = try page(next: "https://api.weather.gov/alerts?cursor=2")
    for _ in 0..<5 { try answer(transport, page: expected) }
    let client = makeClient(transport)
    let filter = ActiveAlertFilter(severity: [.severe])
    let request = WeatherRequest.activeAlerts(matching: filter)
    let single = try await client.activeAlerts(matching: filter)
    let _: FeatureCollection<WeatherAlert> = single
    let sequence: ActiveAlertSequence = client.activeAlerts(matching: filter)
    let pages = client.activeAlertPages(matching: filter)
    let _: ActiveAlertPageSequence = client.activeAlertPages(for: request)
    let _: ActiveAlertSequence = client.activeAlerts(for: .activeAlerts(matching: filter))
    #expect(single == expected)
    #expect(try await client.value(for: request) == single)
    #expect(try await client.send(.activeAlerts(matching: filter)) == single)
    for try await feature in sequence {
      #expect(feature == expected.features.first)
      break
    }
    for try await feature in client.activeAlerts(matching: filter) {
      let _: WeatherAlert = feature.properties
      break
    }
    let _ = pages
    #expect(transport.requests.count == 5)
  }

  @Test("Cancellation during a canonical redirect ends the alert iterator")
  func cancellationDuringACanonicalRedirectEndsTheAlertIterator() async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/alerts/active") { _ in
      unsafe withUnsafeCurrentTask { unsafe $0?.cancel() }
      return .success(
        .init(
          Response(
            headers: [.location: "/alerts/active/area/TX"], status: .movedPermanently)))
    }
    let task = Task { () throws -> NWSError? in
      var iterator = makeClient(transport).activeAlertPages().makeAsyncIterator()
      let error = await #expect(throws: NWSError.self) { try await iterator.next() }
      #expect(try await iterator.next() == nil)
      return error
    }
    guard case .transport(.cancelled) = try await task.value else {
      Issue.record("Expected cancellation"); return
    }
    #expect(transport.requests.count == 1)
  }

  @Test("Canonical redirects retain headers and continue through the page pipeline")
  func canonicalRedirectsRetainHeadersAndContinueThroughThePagePipeline() async throws {
    let transport = MockTransport()
    // The OpenAPI response for /alerts/active documents this possible 301.
    transport.enqueue(
      .success(
        .init(
          Response(
            headers: [.location: "/alerts/active/area/TX"], status: .movedPermanently))))
    let path = "/alerts?active=true&area=TX&cursor=a%2Fb%3D"
    try answer(transport, page: page(next: "https://api.weather.gov" + path))
    try answer(transport, page: page())
    var iterator = makeClient(transport).activeAlertPages(
      matching: .init(location: .areas([.texas]))
    ).makeAsyncIterator()
    #expect(transport.requests.isEmpty)
    #expect(try await iterator.next() != nil)
    #expect(transport.requests.count == 2)
    #expect(try await iterator.next() != nil)
    #expect(try await iterator.next() == nil)
    #expect(
      transport.requests.map(\.request.path) == [
        "/alerts/active?area=TX", "/alerts/active/area/TX", path,
      ])
    #expect(
      transport.requests.allSatisfy {
        $0.request.headerFields[.accept] == "application/geo+json"
          && $0.request.headerFields[.userAgent] == "alert-pagination-tests"
      })
  }

  @Test("Custom alert endpoints remain one page and retain headers across redirects")
  func customAlertEndpointsRemainOnePageAndRetainHeadersAcrossRedirects() async throws {
    let transport = MockTransport()
    transport.enqueue(
      .success(
        .init(
          Response(
            headers: [.location: "/canonical"], status: .movedPermanently))))
    try answer(transport, page: page(next: "invalid continuation"))
    let endpoint = try #require(
      Endpoint<FeatureCollection<WeatherAlert>>(
        accept: .init(rawValue: "application/ld+json"),
        featureFlags: [.init(rawValue: "future_flag")], path: "/custom"))
    let request = WeatherRequest(endpoint: endpoint)
    var iterator = makeClient(transport).activeAlerts(for: request).makeAsyncIterator()
    var features: [Feature<WeatherAlert>] = []
    while let feature = try await iterator.next() { features.append(feature) }
    #expect(features == (try page()).features)
    #expect(transport.requests.map(\.request.path) == ["/custom", "/canonical"])
    let flag = try #require(HTTPField.Name("Feature-Flags"))
    #expect(
      transport.requests.allSatisfy {
        $0.request.headerFields[.accept] == "application/ld+json"
          && $0.request.headerFields[flag] == "future_flag"
          && $0.request.headerFields[.userAgent] == "alert-pagination-tests"
      })
  }

  @Test(
    "Disallowed canonical redirects never send to their targets",
    arguments: [
      "https://example.com/alerts", "http://api.weather.gov/alerts",
      "https://user@api.weather.gov/alerts", "https://api.weather.gov:444/alerts",
      "https://api.weather.gov/alerts#fragment",
    ])
  func disallowedCanonicalRedirectsNeverSendToTheirTargets(location: String) async throws {
    let transport = MockTransport()
    transport.enqueue(
      .success(
        .init(
          Response(
            headers: [.location: location], status: .movedPermanently))))
    var iterator = makeClient(transport).activeAlertPages().makeAsyncIterator()
    let error = await #expect(throws: NWSError.self) { try await iterator.next() }
    guard case .invalidLink = error else { Issue.record("Expected invalid link"); return }
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.count == 1)
    #expect(transport.requests.first?.request.path == "/alerts/active")
  }

  @Test("Every filter and specialized request starts traversal at its original endpoint")
  func everyFilterAndSpecializedRequestStartsTraversalAtItsOriginalEndpoint() async throws {
    let point = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
    let locations: [ActiveAlertFilter.Location?] = [
      nil, .areas([.texas]), .point(point), .regionType(.marine),
      .regions([.alaska]), .zones(["TXZ192"]),
    ]
    var requests: [WeatherRequest<FeatureCollection<WeatherAlert>>] = [
      .activeAlerts(for: point), try #require(.activeAlerts(inArea: .texas)),
      try #require(.activeAlerts(inArea: AlertArea.texas)),
      try #require(.activeAlerts(inZone: "TXZ192")),
    ]
    var expectedPaths = [
      "/alerts/active?point=30.2672,-97.7431",
      "/alerts/active/area/TX", "/alerts/active/area/TX", "/alerts/active/zone/TXZ192",
    ]
    for location in locations {
      let filter = ActiveAlertFilter(
        certainty: [.likely], code: ["HTY"], event: ["Heat Advisory"], location: location,
        messageType: [.update], severity: [.moderate], status: [.actual], urgency: [.expected])
      requests.append(.activeAlerts(matching: filter))
      expectedPaths.append(Endpoint.activeAlerts(matching: filter).path)
    }
    for (request, path) in zip(requests, expectedPaths) {
      guard case .activeAlerts(let endpoint) = request.resolution else {
        Issue.record("Expected a library active-alert resolution"); continue
      }
      #expect(endpoint.path == path)
      let transport = MockTransport()
      let next = "/alerts?cursor=next%2Fpage"
      try answer(transport, page: page(next: "https://api.weather.gov" + next))
      try answer(transport, page: page())
      var iterator = makeClient(transport).activeAlertPages(for: request).makeAsyncIterator()
      #expect(transport.requests.isEmpty)
      #expect(try await iterator.next() != nil)
      #expect(try await iterator.next() != nil)
      #expect(try await iterator.next() == nil)
      #expect(transport.requests.map(\.request.path) == [path, next])
    }
  }

  @Test("Feature traversal skips empty advancing pages and preserves independent service order")
  func featureTraversalSkipsEmptyAdvancingPagesAndPreservesIndependentServiceOrder() async throws {
    let transport = MockTransport()
    var empty = try page(next: "https://api.weather.gov/alerts?cursor=next")
    empty.features = []
    let terminal = try page()
    for _ in 0..<2 {
      try answer(transport, page: empty)
      try answer(transport, page: terminal)
    }
    let sequence: ActiveAlertSequence = makeClient(transport).activeAlerts()
    var first = sequence.makeAsyncIterator()
    var second = sequence.makeAsyncIterator()
    #expect(transport.requests.isEmpty)
    #expect(try await first.next() == terminal.features.first)
    #expect(transport.requests.count == 2)
    #expect(try await second.next() == terminal.features.first)
    #expect(transport.requests.count == 4)
    #expect(try await first.next() == terminal.features.last)
    #expect(try await first.next() == nil)
    #expect(transport.requests.count == 4)
  }

  @Test("Invalid alert continuation fails before yielding and ends traversal")
  func invalidAlertContinuationFailsBeforeYieldingAndEndsTraversal() async throws {
    let transport = MockTransport()
    try answer(transport, page: page(next: "https://example.com/alerts"))
    var iterator = makeClient(transport).activeAlertPages().makeAsyncIterator()
    let error = await #expect(throws: NWSError.self) { try await iterator.next() }
    guard case .pagination(.invalidNext("https://example.com/alerts")) = error else {
      Issue.record("Expected invalid continuation"); return
    }
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.count == 1)
  }

  private func answer(_ transport: MockTransport, page: FeatureCollection<WeatherAlert>) throws {
    transport.enqueue(.success(.init(Response(body: try JSONEncoder().encode(page), status: .ok))))
  }

  private func makeClient(_ transport: MockTransport) -> NWSClient {
    NWSClient(configuration: .init(userAgent: "alert-pagination-tests"), transport: transport)
  }

  // Pagination variants derive from the recorded active-alert response, not live page captures.
  private func page(next: String? = nil) throws -> FeatureCollection<WeatherAlert> {
    var page = try JSONDecoder().decode(
      FeatureCollection<WeatherAlert>.self, from: Fixture.activeAlerts.data())
    page.pagination = next.map { PaginationInfo(next: $0) }
    return page
  }
}

private enum AlertArea: String {
  case texas = "TX"
}

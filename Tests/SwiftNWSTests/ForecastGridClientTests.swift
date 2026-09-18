import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Forecast grid client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ForecastGridClientTests {
  private static let gridPath = "/gridpoints/EWX/156,91"
  private static let pointPath = "/points/30.2672,-97.7431"

  @Test("A grid lookup sends the point and then its grid data link")
  func aGridLookupSendsThePointAndThenItsGridDataLink() async throws {
    let transport = try preparedTransport()
    _ = try await makeClient(transport).forecastGrid(for: try home())
    #expect(transport.requests.map(\.request.path) == [Self.pointPath, Self.gridPath])
    let sent = try #require(transport.requests.last)
    let flag = try #require(HTTPField.Name("Feature-Flags"))
    #expect(sent.request.headerFields[.accept] == "application/geo+json")
    #expect(sent.request.headerFields[.userAgent] == "(example.com, contact@example.com)")
    #expect(sent.request.headerFields[flag] == nil)
    #expect(sent.request.url?.query == nil)
  }

  @Test("The everyday grid method and its request return the same grid", arguments: [false, true])
  func theEverydayGridMethodAndItsRequestReturnTheSameGrid(useRequest: Bool) async throws {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let result = try await grid(client, useRequest: useRequest)
    let recorded = try JSONDecoder().decode(
      Feature<ForecastGrid>.self, from: Fixture.forecastGrid.data())
    #expect(result == recorded.properties)
  }

  @Test(
    "The everyday grid method and its request fail with the same error", arguments: [false, true])
  func theEverydayGridMethodAndItsRequestFailWithTheSameError(useRequest: Bool) async throws {
    let transport = MockTransport()
    try answer(transport, path: Self.pointPath, with: .point)
    transport.setHandler(forPath: Self.gridPath) { _ in
      .success(MockTransport.Answer(Response(body: Data(#"{"type":"Feature"}"#.utf8), status: .ok)))
    }
    let failure = await #expect(throws: NWSError.self) {
      try await grid(makeClient(transport), useRequest: useRequest)
    }
    guard case .transport(.decode) = failure else {
      Issue.record("Expected a decoding failure, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.map(\.request.path) == [Self.pointPath, Self.gridPath])
  }

  @Test("A forecast and a grid for one coordinate share one point request")
  func aForecastAndAGridForOneCoordinateShareOnePointRequest() async throws {
    let transport = try preparedTransport()
    try answer(transport, path: "/gridpoints/EWX/156,91/forecast", with: .forecast)
    let client = makeClient(transport)
    let location = try home()
    _ = try await client.forecast(for: location)
    _ = try await client.forecastGrid(for: location)
    _ = try await client.value(for: .forecastGrid(for: location))
    #expect(
      transport.requests.map(\.request.path) == [
        Self.pointPath, "/gridpoints/EWX/156,91/forecast?units=us", Self.gridPath, Self.gridPath,
      ])
  }

  @Test("A direct grid endpoint bypasses the point cache")
  func aDirectGridEndpointBypassesThePointCache() async throws {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let endpoint = try #require(Endpoint.forecastGrid(for: try recordedPoint()))
    let feature = try await client.send(endpoint)
    #expect(feature.properties.gridId == "EWX")
    #expect(transport.requests.map(\.request.path) == [Self.gridPath])
    _ = try await client.forecastGrid(for: try home())
    #expect(
      transport.requests.map(\.request.path) == [Self.gridPath, Self.pointPath, Self.gridPath])
  }

  @Test("A cancelled grid lookup sends nothing", arguments: [false, true])
  @MainActor
  func aCancelledGridLookupSendsNothing(useRequest: Bool) async throws {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let task = Task {
      await #expect(throws: NWSError.self) { try await grid(client, useRequest: useRequest) }
    }
    // The inherited main actor keeps the task from starting before cancellation.
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected cancellation")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Cancellation after the point prevents the grid request")
  func cancellationAfterThePointPreventsTheGridRequest() async throws {
    let transport = MockTransport()
    let body = try Fixture.point.data()
    transport.setHandler(forPath: Self.pointPath) { _ in
      unsafe withUnsafeCurrentTask { unsafe $0?.cancel() }
      return .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = makeClient(transport)
    let location = try home()
    let work = Task {
      await #expect(throws: NWSError.self) { try await client.forecastGrid(for: location) }
    }
    guard case .transport(.cancelled) = await work.value else {
      Issue.record("Expected cancellation")
      return
    }
    #expect(transport.requests.map(\.request.path) == [Self.pointPath])
  }

  @Test("A disallowed grid data link is not followed", arguments: [false, true])
  func aDisallowedGridDataLinkIsNotFollowed(useRequest: Bool) async throws {
    let transport = MockTransport()
    var point = try JSONDecoder().decode(Feature<Point>.self, from: Fixture.point.data())
    let link = try #require(URL(string: "https://example.com/gridpoints/EWX/156,91"))
    point.properties.forecastGridData = link
    let body = try JSONEncoder().encode(point)
    transport.setHandler(forPath: Self.pointPath) { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let failure = await #expect(throws: NWSError.self) {
      try await grid(makeClient(transport), useRequest: useRequest)
    }
    guard case .invalidLink(let actual) = failure else {
      Issue.record("Expected an invalid link, got \(String(describing: failure))")
      return
    }
    #expect(actual == link)
    #expect(transport.requests.map(\.request.path) == [Self.pointPath])
  }

  @Test("Grid problem details map to a problem error", arguments: [false, true])
  func gridProblemDetailsMapToAProblemError(useRequest: Bool) async throws {
    let transport = MockTransport()
    try answer(transport, path: Self.pointPath, with: .point)
    let problem = try Fixture.problemDetail.data()
    transport.setHandler(forPath: Self.gridPath) { _ in
      .success(MockTransport.Answer(Response(body: problem, status: .notFound)))
    }
    let failure = await #expect(throws: NWSError.self) {
      try await grid(makeClient(transport), useRequest: useRequest)
    }
    guard case .problem(let detail) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    let recorded = try JSONDecoder().decode(ProblemDetail.self, from: problem)
    #expect(detail == recorded)
  }

  @Test(
    "A grid redirect within the API is followed and one to another origin is refused",
    arguments: [
      ("/gridpoints/EWX/156,92", true),
      ("https://example.com/gridpoints/EWX/156,92", false),
    ])
  func aGridRedirectWithinTheAPIIsFollowedAndOneToAnotherOriginIsRefused(
    location: String, allowed: Bool
  ) async throws {
    let transport = MockTransport()
    try answer(transport, path: Self.pointPath, with: .point)
    transport.setHandler(forPath: Self.gridPath) { _ in
      .success(
        MockTransport.Answer(
          Response(body: Data(), headers: [.location: location], status: .movedPermanently)))
    }
    try answer(transport, path: "/gridpoints/EWX/156,92", with: .forecastGrid)
    let client = makeClient(transport)
    if allowed {
      let result = try await client.forecastGrid(for: try home())
      #expect(result.gridId == "EWX")
      #expect(
        transport.requests.map(\.request.path) == [
          Self.pointPath, Self.gridPath, "/gridpoints/EWX/156,92",
        ])
      #expect(transport.requests.last?.request.headerFields[.accept] == "application/geo+json")
    } else {
      let failure = await #expect(throws: NWSError.self) {
        try await client.forecastGrid(for: try home())
      }
      guard case .invalidLink(let link) = failure else {
        Issue.record("Expected an invalid link, got \(String(describing: failure))")
        return
      }
      #expect(link.absoluteString == location)
      #expect(transport.requests.map(\.request.path) == [Self.pointPath, Self.gridPath])
    }
  }

  @Test("A malformed grid body is a transport failure")
  func aMalformedGridBodyIsATransportFailure() async throws {
    let transport = MockTransport()
    try answer(transport, path: Self.pointPath, with: .point)
    // The recorded grid with one interval the service does not send.
    let recorded = try Fixture.forecastGrid.data()
    let text = String(decoding: recorded, as: UTF8.self).replacingOccurrences(
      of: "2026-09-17T17:00:00+00:00/P7DT8H", with: "NOW/P7DT8H")
    let body = Data(text.utf8)
    transport.setHandler(forPath: Self.gridPath) { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let failure = await #expect(throws: NWSError.self) {
      try await makeClient(transport).forecastGrid(for: try home())
    }
    guard case .transport(.decode) = failure else {
      Issue.record("Expected a decoding failure, got \(String(describing: failure))")
      return
    }
  }

  @Test("A consumer-defined grid endpoint decodes only its own layers")
  func aConsumerDefinedGridEndpointDecodesOnlyItsOwnLayers() async throws {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let point = try await client.send(.point(for: try home())).properties
    let slim = try #require(Endpoint<Feature<TemperatureOnly>>(link: point.forecastGridData))
    let result = try await client.value(for: WeatherRequest(endpoint: slim)).properties
    #expect(result.temperature.unitCode == "wmoUnit:degC")
    #expect(result.temperature.values.first?.value == 33.333333333333336)
    #expect(transport.requests.map(\.request.path) == [Self.pointPath, Self.gridPath])
  }

  @Test("Grid factories infer their response without sending")
  func gridFactoriesInferTheirResponseWithoutSending() throws {
    let transport = MockTransport()
    let location = try home()
    let stored = WeatherRequest.forecastGrid(for: location)
    let named: WeatherRequest<ForecastGrid> = try .austinGrid
    #expect(stored == named)
    guard case .forecastGrid(let actual) = stored.resolution else {
      Issue.record("Expected a grid resolution")
      return
    }
    #expect(actual == location)
    #expect(transport.requests.isEmpty)
  }

  private func callSites(_ client: NWSClient, location: WeatherCoordinate, point: Point)
    async throws
  {
    let _: ForecastGrid = try await client.forecastGrid(for: location)
    let _: ForecastGrid = try await client.value(for: .forecastGrid(for: location))
    let _: ForecastGrid = try await client.value(for: .austinGrid)
    let endpoint = try #require(Endpoint.forecastGrid(for: point))
    let _: Feature<ForecastGrid> = try await client.send(endpoint)
    let _: [ForecastGridValue<Double?>] =
      try await client.forecastGrid(for: location)[
        .temperature]?.values ?? []
  }

  private func answer(_ transport: MockTransport, path: String, with fixture: Fixture) throws {
    let body = try fixture.data()
    transport.setHandler(forPath: path) { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
  }

  private func grid(_ client: NWSClient, useRequest: Bool) async throws(NWSError) -> ForecastGrid {
    let location: WeatherCoordinate
    do {
      location = try home()
    } catch {
      preconditionFailure("The Austin coordinate is valid.")
    }
    return useRequest
      ? try await client.value(for: .forecastGrid(for: location))
      : try await client.forecastGrid(for: location)
  }

  private func home() throws -> WeatherCoordinate {
    try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
  }

  private func makeClient(_ transport: MockTransport) -> NWSClient {
    NWSClient(
      configuration: .init(userAgent: "(example.com, contact@example.com)"), transport: transport)
  }

  private func preparedTransport() throws -> MockTransport {
    let transport = MockTransport()
    try answer(transport, path: Self.pointPath, with: .point)
    try answer(transport, path: Self.gridPath, with: .forecastGrid)
    return transport
  }

  private func recordedPoint() throws -> Point {
    try JSONDecoder().decode(Feature<Point>.self, from: Fixture.point.data()).properties
  }
}

private struct TemperatureOnly: Decodable, Sendable {
  var temperature: ForecastGridLayer<Double?>
}

extension WeatherRequest where Response == ForecastGrid {
  fileprivate static var austinGrid: Self {
    get throws {
      .forecastGrid(for: try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431))
    }
  }
}

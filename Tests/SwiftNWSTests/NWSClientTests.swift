import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("NWSClient", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct NWSClientTests {
  private let configuration = NWSConfiguration(userAgent: "(example.com, contact@example.com)")

  @Test("A cancelled lookup sends nothing", arguments: [false, true])
  @MainActor
  func aCancelledLookupSendsNothing(useRequest: Bool) async throws {
    let transport = MockTransport()
    let client = NWSClient(configuration: configuration, transport: transport)
    let task = Task {
      return await #expect(throws: NWSError.self) {
        try await observation(client, from: .station("KATT"), useRequest: useRequest)
      }
    }
    // The inherited main actor keeps the task from starting before cancellation.
    task.cancel()
    let failure = await task.value
    guard case .transport(.cancelled) = failure else {
      Issue.record("Expected cancellation, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("A custom endpoint infers its consumer-defined response")
  func aCustomEndpointInfersItsConsumerDefinedResponse() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/stations/KATT/observations/latest", with: .observation)
    let client = NWSClient(configuration: configuration, transport: transport)
    let request = WeatherRequest(
      endpoint: try #require(Endpoint<Feature<Reading>>(path: "/stations/KATT/observations/latest"))
    )
    #expect(transport.requests.isEmpty)

    let result = try await client.value(for: request)

    #expect(result.properties.stationId == "KATT")
    #expect(result.properties.timestamp == "2026-09-13T19:51:00+00:00")
    #expect(transport.requests.count == 1)
  }

  @Test("A disallowed station-list link is refused before it is sent", arguments: [false, true])
  func aDisallowedStationListLinkIsRefusedBeforeItIsSent(useRequest: Bool) async throws {
    let transport = MockTransport()
    var point = try JSONDecoder().decode(Feature<WeatherPoint>.self, from: Fixture.point.data())
    let link = try #require(URL(string: "https://example.com/stations"))
    point.properties.observationStations = link
    let body = try JSONEncoder().encode(point)
    transport.setHandler(forPath: "/points/30.2672,-97.7431") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = NWSClient(configuration: configuration, transport: transport)
    let home = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)

    let failure = await #expect(throws: NWSError.self) {
      try await observation(client, from: .nearest(to: home), useRequest: useRequest)
    }

    guard case .invalidLink(let actual) = failure else {
      Issue.record("Expected an invalid link, got \(String(describing: failure))")
      return
    }
    #expect(actual == link)
    #expect(transport.requests.map(\.request.path) == ["/points/30.2672,-97.7431"])
  }

  @Test("A factory extension is reusable and infers the observation response")
  func aFactoryExtensionIsReusableAndInfersTheObservationResponse() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/stations/KATT/observations/latest", with: .observation)
    let client = NWSClient(configuration: configuration, transport: transport)
    let request = WeatherRequest.homeConditions
    #expect(transport.requests.isEmpty)

    let first = try await client.value(for: request)
    let second = try await client.value(for: .homeConditions)

    #expect(first == second)
    #expect(first.stationId == "KATT")
    #expect(transport.requests.count == 2)
  }

  @Test("A malformed observation produces the same decoding error", arguments: [false, true])
  func aMalformedObservationProducesTheSameDecodingError(useRequest: Bool) async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/stations/KATT/observations/latest") { _ in
      .success(MockTransport.Answer(Response(body: Data("{}".utf8), status: .ok)))
    }
    let client = NWSClient(configuration: configuration, transport: transport)

    let failure = await #expect(throws: NWSError.self) {
      try await observation(client, from: .station("KATT"), useRequest: useRequest)
    }

    guard case .transport(.decode) = failure else {
      Issue.record("Expected a decoding failure, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.count == 1)
  }

  @Test("An empty station identifier is rejected without sending", arguments: [false, true])
  func anEmptyStationIdentifierIsRejectedWithoutSending(useRequest: Bool) async throws {
    let transport = MockTransport()
    let client = NWSClient(configuration: configuration, transport: transport)

    let failure = await #expect(throws: NWSError.self) {
      try await observation(client, from: .station(""), useRequest: useRequest)
    }

    guard case .invalidStationIdentifier("") = failure else {
      Issue.record("Expected an invalid identifier, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("A point with no nearby station stops after the station list", arguments: [false, true])
  func aPointWithNoNearbyStationStopsAfterTheStationList(useRequest: Bool) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/points/30.2672,-97.7431", with: .point)
    transport.setHandler(forPath: "/gridpoints/EWX/156,91/stations") { _ in
      .success(MockTransport.Answer(Response(body: Data(#"{"features":[]}"#.utf8), status: .ok)))
    }
    let client = NWSClient(configuration: configuration, transport: transport)
    let home = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)

    let failure = await #expect(throws: NWSError.self) {
      try await observation(client, from: .nearest(to: home), useRequest: useRequest)
    }

    guard case .noObservationStation = failure else {
      Issue.record("Expected noObservationStation, got \(String(describing: failure))")
      return
    }
    #expect(
      transport.requests.map(\.request.path) == [
        "/points/30.2672,-97.7431", "/gridpoints/EWX/156,91/stations",
      ])
  }

  @Test("A refusal with problem details is thrown as the problem", arguments: [false, true])
  func aRefusalWithProblemDetailsIsThrownAsTheProblem(useRequest: Bool) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/points/0,0", status: .notFound, with: .problemDetail)
    let client = NWSClient(configuration: configuration, transport: transport)
    let location = try WeatherCoordinate(latitude: 0, longitude: 0)

    let failure = await #expect(throws: NWSError.self) {
      try await observation(client, from: .nearest(to: location), useRequest: useRequest)
    }

    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.title == "Data Unavailable For Requested Point")
    #expect(problem.status == 404)
    #expect(transport.requests.map(\.request.path) == ["/points/0,0"])
  }

  @Test("A station failure does not fall back to another station", arguments: [false, true])
  func aStationFailureDoesNotFallBackToAnotherStation(useRequest: Bool) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/points/30.2672,-97.7431", with: .point)
    try answer(transport, path: "/gridpoints/EWX/156,91/stations", with: .observationStations)
    transport.setHandler(forPath: "/stations/KATT/observations/latest") { _ in
      .success(MockTransport.Answer(Response(body: Data("Bad Gateway".utf8), status: .badGateway)))
    }
    let client = NWSClient(configuration: configuration, transport: transport)
    let home = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)

    let failure = await #expect(throws: NWSError.self) {
      try await observation(client, from: .nearest(to: home), useRequest: useRequest)
    }

    guard case .transport(let underlying) = failure else {
      Issue.record("Expected a transport failure, got \(String(describing: failure))")
      return
    }
    #expect(underlying.statusCode == 502)
    #expect(
      transport.requests.map(\.request.path) == [
        "/points/30.2672,-97.7431", "/gridpoints/EWX/156,91/stations",
        "/stations/KATT/observations/latest",
      ])
  }

  @Test("Direct endpoints retain their GeoJSON metadata and requested media type")
  func directEndpointsRetainTheirGeoJSONMetadataAndRequestedMediaType() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/points/30.2672,-97.7431", with: .point)
    let client = NWSClient(configuration: configuration, transport: transport)
    let home = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
    var endpoint = Endpoint.point(for: home)
    endpoint.accept = MediaType(rawValue: "application/ld+json")

    let direct = try await client.send(endpoint)
    let reusable = try await client.value(for: WeatherRequest(endpoint: endpoint))

    #expect(direct == reusable)
    #expect(direct.id?.absoluteString == "https://api.weather.gov/points/30.2672,-97.7431")
    #expect(
      transport.requests.allSatisfy {
        $0.request.headerFields[.accept] == "application/ld+json"
      })
  }

  @Test("Explicit stations need only one request", arguments: [false, true])
  func explicitStationsNeedOnlyOneRequest(useRequest: Bool) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/stations/KATT/observations/latest", with: .observation)
    let client = NWSClient(configuration: configuration, transport: transport)

    let result = try await observation(client, from: .station("KATT"), useRequest: useRequest)

    #expect(result.stationId == "KATT")
    #expect(result.timestamp == Date(timeIntervalSince1970: 1_789_329_060))
    #expect(transport.requests.map(\.request.path) == ["/stations/KATT/observations/latest"])
  }

  @Test("Nearest lookups share results, sequencing, and headers", arguments: [false, true])
  func nearestLookupsShareResultsSequencingAndHeaders(useRequest: Bool) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/points/30.2672,-97.7431", with: .point)
    try answer(transport, path: "/gridpoints/EWX/156,91/stations", with: .observationStations)
    try answer(transport, path: "/stations/KATT/observations/latest", with: .observation)
    let client = NWSClient(configuration: configuration, transport: transport)
    let home = try WeatherCoordinate(latitude: 30.26721, longitude: -97.74306)

    let result = try await observation(client, from: .nearest(to: home), useRequest: useRequest)
    let recorded = try JSONDecoder().decode(
      Feature<WeatherObservation>.self, from: Fixture.observation.data())

    #expect(result == recorded.properties)
    #expect(result.windChill?.value == nil)
    #expect(result.timestamp == Date(timeIntervalSince1970: 1_789_329_060))
    #expect(
      transport.requests.map(\.request.path) == [
        "/points/30.2672,-97.7431", "/gridpoints/EWX/156,91/stations",
        "/stations/KATT/observations/latest",
      ])
    #expect(
      transport.requests.allSatisfy {
        $0.request.headerFields[.accept] == "application/geo+json"
          && $0.request.headerFields[.userAgent] == "(example.com, contact@example.com)"
      })
  }

  private func answer(
    _ transport: MockTransport,
    path: String,
    status: HTTPResponse.Status = .ok,
    with fixture: Fixture
  ) throws {
    let body = try fixture.data()
    transport.setHandler(forPath: path) { _ in
      .success(MockTransport.Answer(Response(body: body, status: status)))
    }
  }

  private func observation(
    _ client: NWSClient,
    from source: ObservationSource,
    useRequest: Bool
  ) async throws(NWSError) -> WeatherObservation {
    if useRequest {
      try await client.value(for: .latestObservation(from: source))
    } else {
      try await client.latestObservation(from: source)
    }
  }
}

private struct Reading: Decodable, Sendable {
  let stationId: String
  let timestamp: String
}

extension WeatherRequest where Response == WeatherObservation {
  fileprivate static var homeConditions: Self {
    .latestObservation(from: .station("KATT"))
  }
}

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

  @Test("latestObservation follows the point to its nearest station's latest observation")
  func latestObservationFollowsThePointToItsNearestStationsLatestObservation() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/points/30.2672,-97.7431", with: .point)
    try answer(transport, path: "/gridpoints/EWX/156,91/stations", with: .observationStations)
    try answer(transport, path: "/stations/KATT/observations/latest", with: .observation)
    let client = NWSClient(configuration: configuration, transport: transport)

    let observation = try await client.latestObservation(latitude: 30.26721, longitude: -97.74306)

    #expect(observation.stationId == "KATT")
    #expect(
      observation.temperature
        == QuantitativeValue(qualityControl: "V", unitCode: "wmoUnit:degC", value: 37.8))
    #expect(
      transport.requests.map(\.request.path) == [
        "/points/30.2672,-97.7431",
        "/gridpoints/EWX/156,91/stations",
        "/stations/KATT/observations/latest",
      ])
  }

  @Test("Every request carries the configured user agent and asks for GeoJSON")
  func everyRequestCarriesTheConfiguredUserAgentAndAsksForGeoJSON() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/points/30.2672,-97.7431", with: .point)
    let client = NWSClient(configuration: configuration, transport: transport)

    _ = try await client.send(Endpoint.point(latitude: 30.2672, longitude: -97.7431))

    let fields = try #require(transport.last?.request.headerFields)
    #expect(fields[.userAgent] == "(example.com, contact@example.com)")
    #expect(fields[.accept] == "application/geo+json")
  }

  @Test("A refusal with problem details is thrown as the problem")
  func aRefusalWithProblemDetailsIsThrownAsTheProblem() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/points/0,0", with: .problemDetail, status: .notFound)
    let client = NWSClient(configuration: configuration, transport: transport)

    let failure = await #expect(throws: NWSError.self) {
      try await client.send(Endpoint.point(latitude: 0, longitude: 0))
    }

    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.title == "Data Unavailable For Requested Point")
    #expect(problem.status == 404)
  }

  @Test("A refusal without problem details is thrown as the transport failure")
  func aRefusalWithoutProblemDetailsIsThrownAsTheTransportFailure() async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/points/0,0") { _ in
      .success(MockTransport.Answer(Response(body: Data("Bad Gateway".utf8), status: .badGateway)))
    }
    let client = NWSClient(configuration: configuration, transport: transport)

    let failure = await #expect(throws: NWSError.self) {
      try await client.send(Endpoint.point(latitude: 0, longitude: 0))
    }

    guard case .transport(let underlying) = failure else {
      Issue.record("Expected a transport failure, got \(String(describing: failure))")
      return
    }
    #expect(underlying.statusCode == 502)
  }

  @Test("A point with no nearby station throws noObservationStation")
  func aPointWithNoNearbyStationThrowsNoObservationStation() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/points/30.2672,-97.7431", with: .point)
    transport.setHandler(forPath: "/gridpoints/EWX/156,91/stations") { _ in
      .success(MockTransport.Answer(Response(body: Data(#"{"features":[]}"#.utf8), status: .ok)))
    }
    let client = NWSClient(configuration: configuration, transport: transport)

    let failure = await #expect(throws: NWSError.self) {
      try await client.latestObservation(latitude: 30.2672, longitude: -97.7431)
    }

    guard case .noObservationStation = failure else {
      Issue.record("Expected noObservationStation, got \(String(describing: failure))")
      return
    }
  }

  private func answer(
    _ transport: MockTransport,
    path: String,
    with fixture: Fixture,
    status: HTTPResponse.Status = .ok
  ) throws {
    let body = try fixture.data()
    transport.setHandler(forPath: path) { _ in
      .success(MockTransport.Answer(Response(body: body, status: status)))
    }
  }
}

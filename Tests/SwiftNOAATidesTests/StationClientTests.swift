import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import SwiftNWS
import SwiftNWSModels
import Testing

@Suite("Tides station client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct StationClientTests {
  @Test("A cancelled request sends nothing")
  @MainActor
  func aCancelledRequestSendsNothing() async throws {
    let transport = MockTransport()
    let client = TidesClient(transport: transport)
    let query = try CoastalStationQuery(type: .tidePredictions)
    let task = Task {
      await #expect(throws: TidesError.self) { try await client.stations(matching: query) }
    }
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected cancellation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("A custom array response decodes without a provider envelope")
  func aCustomArrayResponseDecodesWithoutAProviderEnvelope() async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/custom") { _ in
      .success(MockTransport.Answer(Response(body: Data("[1,2]".utf8), status: .ok)))
    }
    let result = try await TidesClient(transport: transport).send(
      #require(TidesEndpoint<[Int]>(path: "/custom")))
    #expect(result == [1, 2])
  }

  @Test("A custom response and constrained request extension compile and execute")
  func aCustomResponseAndConstrainedRequestExtensionCompileAndExecute() async throws {
    let transport = MockTransport()
    let body = try Fixture.station.data()
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/9414290.json") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let request = try TidesRequest<StationCount>.sanFrancisco()
    #expect(try await client.value(for: request).count == 1)
    let range = try TidesDateRange(
      begin: TidesTimestamp("2025-01-01 00:00").date,
      end: TidesTimestamp("2025-01-01 01:00").date)
    let observationQuery = try CoastalObservationQuery(
      interval: .hourly, range: range,
      stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric)
    let observationRequest = TidesRequest.windObservations(matching: observationQuery)
    let observationEndpoint = TidesEndpoint.windObservations(matching: observationQuery)
    let _: TidesRequest<WindObservations> = observationRequest
    let _: TidesEndpoint<WindResponse> = observationEndpoint
    let _: NWSConfiguration = .init(userAgent: "test")
    let _: Endpoint<WeatherGlossary> = .glossary
  }

  @Test("All station access levels preserve the recorded response", arguments: [0, 1, 2])
  func allStationAccessLevelsPreserveTheRecordedResponse(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.station.data()
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/9414290.json") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(configuration: .init(userAgent: "test-app"), transport: transport)
    let identifier = try CoastalStationIdentifier("9414290")
    let station: CoastalStation
    switch level {
    case 0: station = try await client.station(identifier: identifier)
    case 1: station = try await client.value(for: .station(identifier: identifier))
    default:
      station = try #require(await client.send(.station(identifier: identifier)).stations.first)
    }
    #expect(station.identifier == "9414290")
    #expect(station.name == "San Francisco")
    #expect(transport.requests.count == 1)
    #expect(transport.requests.first?.request.headerFields[.accept] == "application/json")
    #expect(transport.requests.first?.request.headerFields[.userAgent] == "test-app")
  }

  @Test(
    "Detail cardinality and identity are validated",
    arguments: [
      "{\"count\":0,\"stations\":[]}",
      "{\"count\":1,\"stations\":[{\"id\":\"different\",\"name\":\"x\",\"lat\":0,\"lng\":0}]}",
      "{\"count\":2,\"stations\":[{\"id\":\"9414290\",\"name\":\"x\",\"lat\":0,\"lng\":0}]}",
      "{\"count\":1,\"stations\":[{\"id\":\"9414290\",\"name\":\"x\",\"lat\":0,\"lng\":0},{\"id\":\"9414290\",\"name\":\"x\",\"lat\":0,\"lng\":0}]}",
    ])
  func detailCardinalityAndIdentityAreValidated(body: String) async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/9414290.json") { _ in
      .success(MockTransport.Answer(Response(body: Data(body.utf8), status: .ok)))
    }
    let error = await #expect(throws: TidesError.self) {
      try await TidesClient(transport: transport).station(
        identifier: CoastalStationIdentifier("9414290"))
    }
    guard case .invalidStationResponse = error else {
      Issue.record("Expected station validation"); return
    }
    #expect(transport.requests.count == 1)
  }

  @Test(
    "Directory execution sends one request without resource expansion", arguments: [false, true])
  func directoryExecutionSendsOneRequestWithoutResourceExpansion(useRequest: Bool) async throws {
    let transport = MockTransport()
    let body = try Fixture.stationsWaterLevels.data()
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations.json") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let query = try CoastalStationQuery(type: .waterLevels)
    let client = TidesClient(transport: transport)
    let response =
      try await
      (useRequest
      ? client.value(for: .stations(matching: query)) : client.stations(matching: query))
    #expect(response.stations.first?.identifier == "1611400")
    #expect(
      transport.requests.map(\.request.path) == [
        "/mdapi/prod/webapi/stations.json?type=waterlevels"
      ])
  }

  @Test("Malformed successful bodies fail decoding")
  func malformedSuccessfulBodiesFailDecoding() async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/test") { _ in
      .success(MockTransport.Answer(Response(body: Data("{}".utf8), status: .ok)))
    }
    let error = await #expect(throws: TidesError.self) {
      try await TidesClient(transport: transport).send(
        #require(TidesEndpoint<CoastalStations>(path: "/test")))
    }
    guard case .decoding = error else { Issue.record("Expected decoding error"); return }
  }

  @Test("Provider refusals survive successful and failed HTTP statuses", arguments: [200, 400])
  func providerRefusalsSurviveSuccessfulAndFailedHTTPStatuses(status: Int) async throws {
    for fixture in [Fixture.invalidStation, .stationInvalidMDAPI] {
      let transport = MockTransport()
      let body = try fixture.data()
      transport.setHandler(forPath: "/test") { _ in
        .success(MockTransport.Answer(Response(body: body, status: .init(code: status))))
      }
      let error = await #expect(throws: TidesError.self) {
        try await TidesClient(transport: transport).send(
          #require(TidesEndpoint<StationCount>(path: "/test")))
      }
      guard case .provider(let refusal) = error else {
        Issue.record("Expected provider error"); continue
      }
      #expect(!refusal.message.isEmpty)
      #expect(refusal.code == (fixture == .stationInvalidMDAPI ? 404 : nil))
    }
  }

  @Test(
    "Redirects reject foreign and malformed locations",
    arguments: [
      "https://evil.com/test", "//evil.com/test", "/a/../test", "/%2e%2e/test",
      "https://user@api.tidesandcurrents.noaa.gov/test", "/test#fragment",
    ])
  func redirectsRejectForeignAndMalformedLocations(location: String) async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/test") { _ in
      .success(
        MockTransport.Answer(Response(headers: [.location: location], status: .movedPermanently)))
    }
    let error = await #expect(throws: TidesError.self) {
      try await TidesClient(transport: transport).send(
        #require(TidesEndpoint<StationCount>(path: "/test")))
    }
    guard case .invalidLink = error else { Issue.record("Expected invalid link"); return }
    #expect(transport.requests.count == 1)
  }

  @Test("Same-origin redirects are followed and cycles are bounded")
  func sameOriginRedirectsAreFollowedAndCyclesAreBounded() async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/first") { _ in
      .success(MockTransport.Answer(Response(headers: [.location: "/second"], status: .found)))
    }
    transport.setHandler(forPath: "/second") { _ in
      .success(MockTransport.Answer(Response(body: Data("{\"count\":7}".utf8), status: .ok)))
    }
    let client = TidesClient(transport: transport)
    #expect(try await client.send(#require(TidesEndpoint<StationCount>(path: "/first"))).count == 7)
    transport.setHandler(forPath: "/second") { _ in
      .success(MockTransport.Answer(Response(headers: [.location: "/first"], status: .found)))
    }
    let error = await #expect(throws: TidesError.self) {
      try await client.send(#require(TidesEndpoint<StationCount>(path: "/first")))
    }
    guard case .tooManyRedirects = error else { Issue.record("Expected bounded redirects"); return }
    #expect(transport.requests.count == 4)
  }
}

private struct StationCount: Decodable {
  let count: Int
}

extension TidesRequest where Response == StationCount {
  fileprivate static func sanFrancisco() throws -> Self {
    Self(endpoint: try #require(TidesEndpoint(path: "/mdapi/prod/webapi/stations/9414290.json")))
  }
}

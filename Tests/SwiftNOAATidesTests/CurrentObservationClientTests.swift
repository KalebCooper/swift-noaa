import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Verified current-observation client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct CurrentObservationClientTests {
  @Test("Cancelled current-observation requests send nothing")
  @MainActor
  func cancelledCurrentObservationRequestsSendNothing() async throws {
    let transport = MockTransport()
    let query = try Self.query()
    let task = Task {
      await #expect(throws: TidesError.self) {
        try await TidesClient(transport: transport).currentObservations(matching: query)
      }
    }
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected cancellation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Current bins use one request at every access level", arguments: [0, 1, 2])
  func currentBinsUseOneRequestAtEveryAccessLevel(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.stationBins.data()
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/cb0102/bins.json") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let station = try CoastalStationIdentifier("cb0102")
    let bins: CurrentBins
    switch level {
    case 0: bins = try await client.currentBins(stationIdentifier: station, units: .metric)
    case 1:
      let request = try TidesRequest.currentBins(stationIdentifier: station, units: .metric)
      bins = try await client.value(for: request)
    default: bins = try await client.send(.currentBins(stationIdentifier: station, units: .metric))
    }
    #expect(bins.count == 15)
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/mdapi/prod/webapi/stations/cb0102/bins.json?units=metric")
  }

  @Test("Hourly-height access levels agree without metadata preflight", arguments: [0, 1, 2])
  func currentObservationAccessLevelsAgreeWithoutMetadataPreflight(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.currentsPorts.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let query = try Self.query()
    let observations: [CurrentObservation]
    switch level {
    case 0:
      let response = try await client.currentObservations(matching: query)
      #expect(response.requestedQuery == query)
      #expect(response.metadata.identifier == "cb0102")
      observations = response.observations
    case 1:
      let request = TidesRequest.currentObservations(matching: query)
      let response = try await client.value(for: request)
      #expect(response.requestedQuery == query)
      observations = response.observations
    default:
      observations = try await client.send(.currentObservations(matching: query)).observations
    }
    #expect(observations.count == 10)
    #expect(observations.first?.speed.value == 0.7)
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/api/prod/datagetter?begin_date=20240926%2000:00&bin=4&end_date=20240926%2001:00&format=json&product=currents&station=cb0102&time_zone=gmt&units=metric&application=swift-noaa"
    )
  }

  @Test("Hourly-height refusals remain provider errors at every level", arguments: [0, 1, 2])
  func currentObservationRefusalsRemainProviderErrorsAtEveryLevel(level: Int) async throws {
    for fixture in [Fixture.currentsInvalidBin, .currentsNoData, .currentsOverMonth] {
      let transport = MockTransport()
      let body = try fixture.data()
      transport.setHandler(forPath: "/api/prod/datagetter") { _ in
        .success(MockTransport.Answer(Response(body: body, status: .ok)))
      }
      let client = TidesClient(transport: transport)
      let query = try Self.query()
      let error = await #expect(throws: TidesError.self) {
        switch level {
        case 0: _ = try await client.currentObservations(matching: query)
        case 1: _ = try await client.value(for: .currentObservations(matching: query))
        default: _ = try await client.send(.currentObservations(matching: query))
        }
      }
      guard case .provider(let value) = error else {
        Issue.record("Expected provider refusal"); continue
      }
      let raw = try #require(
        JSONSerialization.jsonObject(with: body) as? [String: [String: String]])
      #expect(value.message == raw["error"]?["message"])
      #expect(transport.requests.count == 1)
    }
  }

  @Test("Custom current-observation response requests use the shared executor")
  func customCurrentObservationResponseRequestsUseTheSharedExecutor() async throws {
    let transport = MockTransport()
    let body = try Fixture.currentsPorts.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let request = try TidesRequest<CurrentMetadataOnly>.currentMetadata(matching: Self.query())
    let response = try await TidesClient(transport: transport).value(for: request)
    #expect(response.metadata.identifier == "cb0102")
    #expect(transport.requests.count == 1)
  }

  @Test("Invalid bin-table units send nothing")
  func invalidBinTableUnitsSendNothing() async throws {
    let transport = MockTransport()
    let error = await #expect(throws: TidesError.self) {
      try await TidesClient(transport: transport).currentBins(
        stationIdentifier: CoastalStationIdentifier("cb0102"), units: .init(rawValue: ""))
    }
    guard case .invalidQuery(.invalidUnits("")) = error else {
      Issue.record("Expected local validation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Provider-default current selection omits the bin without metadata lookup")
  func providerDefaultCurrentSelectionOmitsTheBinWithoutMetadataLookup() async throws {
    let transport = MockTransport()
    let body = try Fixture.currentsPorts.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let explicit = try Self.query()
    let query = try CurrentObservationQuery(
      bin: .providerDefault, range: explicit.range, stationIdentifier: explicit.stationIdentifier,
      units: .metric)
    let result = try await TidesClient(transport: transport).currentObservations(matching: query)
    #expect(result.requestedQuery.bin == .providerDefault)
    #expect(result.observations.first?.bin == "4")
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/api/prod/datagetter?begin_date=20240926%2000:00&end_date=20240926%2001:00&format=json&product=currents&station=cb0102&time_zone=gmt&units=metric&application=swift-noaa"
    )
  }

  private static func query() throws -> CurrentObservationQuery {
    try CurrentObservationQuery(
      bin: .explicit(4),
      range: TidesDateRange(
        begin: TidesTimestamp("2024-09-26 00:00").date, end: TidesTimestamp("2024-09-26 01:00").date
      ),
      stationIdentifier: CoastalStationIdentifier("cb0102"), units: .metric)
  }
}

private struct CurrentMetadataOnly: Decodable {
  let metadata: CoastalDataMetadata
}

extension TidesRequest where Response == CurrentMetadataOnly {
  fileprivate static func currentMetadata(matching query: CurrentObservationQuery) throws -> Self {
    Self(
      endpoint: try #require(
        TidesEndpoint(path: TidesEndpoint.currentObservations(matching: query).path)))
  }
}

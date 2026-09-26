import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Measured water-level client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct WaterLevelClientTests {
  @Test("Cancelled water-level requests send nothing")
  @MainActor
  func cancelledWaterLevelRequestsSendNothing() async throws {
    let transport = MockTransport()
    let query = try Self.query()
    let task = Task {
      await #expect(throws: TidesError.self) {
        try await TidesClient(transport: transport).waterLevels(matching: query)
      }
    }
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected cancellation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Custom water-level response requests use the shared executor")
  func customWaterLevelResponseRequestsUseTheSharedExecutor() async throws {
    let transport = MockTransport()
    let body = try Fixture.waterLevel.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let request = try TidesRequest<WaterMetadataOnly>.waterMetadata(matching: Self.query())
    let response = try await TidesClient(transport: transport).value(for: request)
    #expect(response.metadata.identifier == "9414290")
    #expect(transport.requests.count == 1)
  }

  @Test("Water-level access levels agree without metadata preflight", arguments: [0, 1, 2])
  func waterLevelAccessLevelsAgreeWithoutMetadataPreflight(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.waterLevel.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let query = try Self.query()
    let observations: [WaterLevel]
    switch level {
    case 0:
      let response = try await client.waterLevels(matching: query)
      #expect(response.requestedQuery == query)
      #expect(response.metadata.identifier == "9414290")
      observations = response.observations
    case 1:
      let request = TidesRequest.waterLevels(matching: query)
      let response = try await client.value(for: request)
      #expect(response.requestedQuery == query)
      observations = response.observations
    default: observations = try await client.send(.waterLevels(matching: query)).observations
    }
    #expect(observations.count == 11)
    #expect(observations.first?.height.value == 1.647)
    #expect(observations.first?.quality == .verified)
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/api/prod/datagetter?begin_date=20240926%2000:00&datum=MLLW&end_date=20240926%2001:00&format=json&product=water_level&station=9414290&time_zone=gmt&units=metric&application=swift-noaa"
    )
  }

  @Test("Water-level refusals remain provider errors at every level", arguments: [0, 1, 2])
  func waterLevelRefusalsRemainProviderErrorsAtEveryLevel(level: Int) async throws {
    for fixture in [Fixture.waterInvalidDatum, .waterNoData, .waterOverMonth] {
      let transport = MockTransport()
      let body = try fixture.data()
      transport.setHandler(forPath: "/api/prod/datagetter") { _ in
        .success(MockTransport.Answer(Response(body: body, status: .ok)))
      }
      let client = TidesClient(transport: transport)
      let query = try Self.query()
      let error = await #expect(throws: TidesError.self) {
        switch level {
        case 0: _ = try await client.waterLevels(matching: query)
        case 1: _ = try await client.value(for: .waterLevels(matching: query))
        default: _ = try await client.send(.waterLevels(matching: query))
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

  private static func query() throws -> WaterLevelQuery {
    try WaterLevelQuery(
      datum: .meanLowerLowWater,
      range: TidesDateRange(
        begin: TidesTimestamp("2024-09-26 00:00").date, end: TidesTimestamp("2024-09-26 01:00").date
      ),
      stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric)
  }
}

private struct WaterMetadataOnly: Decodable {
  let metadata: CoastalDataMetadata
}

extension TidesRequest where Response == WaterMetadataOnly {
  fileprivate static func waterMetadata(matching query: WaterLevelQuery) throws -> Self {
    Self(
      endpoint: try #require(TidesEndpoint(path: TidesEndpoint.waterLevels(matching: query).path)))
  }
}

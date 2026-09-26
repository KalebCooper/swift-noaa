import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Verified hourly-height client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct HourlyWaterLevelClientTests {
  @Test("Cancelled hourly-height requests send nothing")
  @MainActor
  func cancelledHourlyWaterLevelRequestsSendNothing() async throws {
    let transport = MockTransport()
    let query = try Self.query()
    let task = Task {
      await #expect(throws: TidesError.self) {
        try await TidesClient(transport: transport).hourlyWaterLevels(matching: query)
      }
    }
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected cancellation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Custom hourly-height response requests use the shared executor")
  func customHourlyWaterLevelResponseRequestsUseTheSharedExecutor() async throws {
    let transport = MockTransport()
    let body = try Fixture.hourlyWater.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let request = try TidesRequest<HourlyMetadataOnly>.hourlyMetadata(matching: Self.query())
    let response = try await TidesClient(transport: transport).value(for: request)
    #expect(response.metadata.identifier == "9414290")
    #expect(transport.requests.count == 1)
  }

  @Test("Hourly-height access levels agree without metadata preflight", arguments: [0, 1, 2])
  func hourlyWaterLevelAccessLevelsAgreeWithoutMetadataPreflight(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.hourlyWater.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let query = try Self.query()
    let observations: [HourlyWaterLevel]
    switch level {
    case 0:
      let response = try await client.hourlyWaterLevels(matching: query)
      #expect(response.requestedQuery == query)
      #expect(response.metadata.identifier == "9414290")
      observations = response.observations
    case 1:
      let request = TidesRequest.hourlyWaterLevels(matching: query)
      let response = try await client.value(for: request)
      #expect(response.requestedQuery == query)
      observations = response.observations
    default: observations = try await client.send(.hourlyWaterLevels(matching: query)).observations
    }
    #expect(observations.count == 2)
    #expect(observations.first?.height.value == 1.647)
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/api/prod/datagetter?begin_date=20240926%2000:00&datum=MLLW&end_date=20240926%2001:00&format=json&product=hourly_height&station=9414290&time_zone=gmt&units=metric&application=swift-noaa"
    )
  }

  @Test("Hourly-height refusals remain provider errors at every level", arguments: [0, 1, 2])
  func hourlyWaterLevelRefusalsRemainProviderErrorsAtEveryLevel(level: Int) async throws {
    for fixture in [Fixture.hourlyInvalidDatum, .hourlyNoData, .hourlyOverYear] {
      let transport = MockTransport()
      let body = try fixture.data()
      transport.setHandler(forPath: "/api/prod/datagetter") { _ in
        .success(MockTransport.Answer(Response(body: body, status: .ok)))
      }
      let client = TidesClient(transport: transport)
      let query = try Self.query()
      let error = await #expect(throws: TidesError.self) {
        switch level {
        case 0: _ = try await client.hourlyWaterLevels(matching: query)
        case 1: _ = try await client.value(for: .hourlyWaterLevels(matching: query))
        default: _ = try await client.send(.hourlyWaterLevels(matching: query))
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

  private static func query() throws -> HourlyWaterLevelQuery {
    try HourlyWaterLevelQuery(
      datum: .meanLowerLowWater,
      range: TidesDateRange(
        begin: TidesTimestamp("2024-09-26 00:00").date, end: TidesTimestamp("2024-09-26 01:00").date
      ),
      stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric)
  }
}

private struct HourlyMetadataOnly: Decodable {
  let metadata: CoastalDataMetadata
}

extension TidesRequest where Response == HourlyMetadataOnly {
  fileprivate static func hourlyMetadata(matching query: HourlyWaterLevelQuery) throws -> Self {
    Self(
      endpoint: try #require(
        TidesEndpoint(path: TidesEndpoint.hourlyWaterLevels(matching: query).path)))
  }
}

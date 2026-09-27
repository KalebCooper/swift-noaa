import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Observed high/low water-level client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ObservedHighLowWaterLevelClientTests {
  @Test("Cancelled water-level requests send nothing")
  @MainActor
  func cancelledObservedHighLowWaterLevelRequestsSendNothing() async throws {
    let transport = MockTransport()
    let query = try Self.query()
    let task = Task {
      await #expect(throws: TidesError.self) {
        try await TidesClient(transport: transport).observedHighLowWaterLevels(matching: query)
      }
    }
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected cancellation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Custom water-level response requests use the shared executor")
  func customObservedHighLowWaterLevelResponseRequestsUseTheSharedExecutor() async throws {
    let transport = MockTransport()
    let body = try Fixture.observedHighLowMetric.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let request = try TidesRequest<ObservedMetadataOnly>.observedMetadata(matching: Self.query())
    let response = try await TidesClient(transport: transport).value(for: request)
    #expect(response.metadata.identifier == "9414290")
    #expect(transport.requests.count == 1)
  }

  @Test("Empty success keeps separate requested and reported context")
  func emptySuccessKeepsSeparateRequestedAndReportedContext() async throws {
    let transport = MockTransport()
    let body = Data(
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":[]}"#.utf8)
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let query = try Self.query()
    let result = try await TidesClient(transport: transport).observedHighLowWaterLevels(
      matching: query)
    #expect(result.observations.isEmpty)
    #expect(result.metadata.identifier == "reported")
    #expect(result.requestedQuery == query)
    #expect(transport.requests.count == 1)
  }

  @Test(
    "Water-level access levels agree without metadata preflight", arguments: [0, 1, 2],
    [Fixture.observedHighLowMetric, .observedHighLowEnglish])
  func observedHighLowWaterLevelAccessLevelsAgreeWithoutMetadataPreflight(
    level: Int, fixture: Fixture
  )
    async throws
  {
    let transport = MockTransport()
    let body = try fixture.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let query = try Self.query(units: fixture == .observedHighLowMetric ? .metric : .english)
    let observations: [ObservedHighLowWaterLevel]
    switch level {
    case 0:
      let response = try await client.observedHighLowWaterLevels(matching: query)
      #expect(response.requestedQuery == query)
      #expect(response.metadata.identifier == "9414290")
      observations = response.observations
    case 1:
      let request = TidesRequest.observedHighLowWaterLevels(matching: query)
      let response = try await client.value(for: request)
      #expect(response.requestedQuery == query)
      observations = response.observations
    default:
      observations = try await client.send(.observedHighLowWaterLevels(matching: query))
        .observations
    }
    #expect(observations.count == 8)
    #expect(
      observations.first?.height.rawValue
        == (fixture == .observedHighLowMetric ? "-0.35" : "-1.147"))
    #expect(observations.first?.kind == .lowerLow)
    #expect(observations.first?.flags == "0,0")
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/api/prod/datagetter?begin_date=20250101%2000:00&datum=MLLW&end_date=20250103%2000:00&format=json&product=high_low&station=9414290&time_zone=gmt&units="
        + query.units.rawValue + "&application=swift-noaa"
    )
  }

  @Test("Water-level refusals remain provider errors at every level", arguments: [0, 1, 2])
  func observedHighLowWaterLevelRefusalsRemainProviderErrorsAtEveryLevel(level: Int) async throws {
    for fixture in [Fixture.observedHighLowNoData] {
      let transport = MockTransport()
      let body = try fixture.data()
      transport.setHandler(forPath: "/api/prod/datagetter") { _ in
        .success(MockTransport.Answer(Response(body: body, status: .ok)))
      }
      let client = TidesClient(transport: transport)
      let query = try Self.query()
      let error = await #expect(throws: TidesError.self) {
        switch level {
        case 0: _ = try await client.observedHighLowWaterLevels(matching: query)
        case 1: _ = try await client.value(for: .observedHighLowWaterLevels(matching: query))
        default: _ = try await client.send(.observedHighLowWaterLevels(matching: query))
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

  private static func query(units: TidesUnits = .metric) throws -> ObservedHighLowWaterLevelQuery {
    try ObservedHighLowWaterLevelQuery(
      datum: .meanLowerLowWater,
      range: TidesDateRange(
        begin: TidesTimestamp("2025-01-01 00:00").date, end: TidesTimestamp("2025-01-03 00:00").date
      ),
      stationIdentifier: CoastalStationIdentifier("9414290"), units: units)
  }
}

private struct ObservedMetadataOnly: Decodable {
  let metadata: CoastalDataMetadata
}

extension TidesRequest where Response == ObservedMetadataOnly {
  fileprivate static func observedMetadata(matching query: ObservedHighLowWaterLevelQuery) throws
    -> Self
  {
    Self(
      endpoint: try #require(
        TidesEndpoint(path: TidesEndpoint.observedHighLowWaterLevels(matching: query).path)))
  }
}

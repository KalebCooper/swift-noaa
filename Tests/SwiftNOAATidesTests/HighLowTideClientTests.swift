import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("High and low tide client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct HighLowTideClientTests {
  @Test("All prediction access levels agree without a station preflight", arguments: [0, 1, 2])
  func allPredictionAccessLevelsAgreeWithoutAStationPreflight(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.tideHighLow.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let query = try Self.query()
    let client = TidesClient(configuration: .init(application: "test&app"), transport: transport)
    let events: [HighLowTide]
    switch level {
    case 0:
      let result = try await client.highLowTides(matching: query)
      #expect(result.requestedQuery == query)
      events = result.predictions
    case 1:
      let request = TidesRequest.highLowTides(matching: query)
      let result = try await client.value(for: request)
      #expect(result.requestedQuery == query)
      events = result.predictions
    default: events = try await client.send(.highLowTides(matching: query)).predictions
    }
    #expect(events.count == 8)
    #expect(events.first?.height.value == 0.377)
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/api/prod/datagetter?begin_date=20260926%2000:00&datum=MLLW&end_date=20260927%2023:59&format=json&interval=hilo&product=predictions&station=9414290&time_zone=gmt&units=metric&application=test%26app"
    )
  }

  @Test("Cancelled contextual predictions send nothing")
  @MainActor
  func cancelledContextualPredictionsSendNothing() async throws {
    let transport = MockTransport()
    let query = try Self.query()
    let client = TidesClient(transport: transport)
    let task = Task {
      await #expect(throws: TidesError.self) {
        try await client.value(for: .highLowTides(matching: query))
      }
    }
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected cancellation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Custom prediction requests decode independent wire responses")
  func customPredictionRequestsDecodeIndependentWireResponses() async throws {
    let transport = MockTransport()
    let body = try Fixture.tideHighLow.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let request = try TidesRequest<PredictionCount>.events(matching: Self.query())
    let result = try await TidesClient(transport: transport).value(for: request)
    #expect(result.predictions.count == 8)
  }

  @Test("Prediction refusals stay equivalent across access levels", arguments: [0, 1, 2])
  func predictionRefusalsStayEquivalentAcrossAccessLevels(level: Int) async throws {
    for fixture in [
      Fixture.invalidStation, .tideEmptyWindow, .tideInvalidDatum, .tideNoData, .tideReversed,
    ] {
      let transport = MockTransport()
      let body = try fixture.data()
      transport.setHandler(forPath: "/api/prod/datagetter") { _ in
        .success(MockTransport.Answer(Response(body: body, status: .ok)))
      }
      let client = TidesClient(transport: transport)
      let query = try Self.query()
      let error = await #expect(throws: TidesError.self) {
        switch level {
        case 0: _ = try await client.highLowTides(matching: query)
        case 1: _ = try await client.value(for: .highLowTides(matching: query))
        default: _ = try await client.send(.highLowTides(matching: query))
        }
      }
      guard case .provider(let refusal) = error else {
        Issue.record("Expected provider refusal"); continue
      }
      let raw = try #require(
        JSONSerialization.jsonObject(with: body) as? [String: [String: String]])
      #expect(refusal.message == raw["error"]?["message"])
      #expect(transport.requests.count == 1)
    }
  }

  private static func query() throws -> HighLowTideQuery {
    try HighLowTideQuery(
      datum: .meanLowerLowWater,
      range: TidesDateRange(
        begin: TidesTimestamp("2026-09-26 00:00").date, end: TidesTimestamp("2026-09-27 23:59").date
      ),
      stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric)
  }
}

private struct PredictionCount: Decodable {
  let predictions: [[String: String]]
}

extension TidesRequest where Response == PredictionCount {
  fileprivate static func events(matching query: HighLowTideQuery) throws -> Self {
    Self(
      endpoint: try #require(TidesEndpoint(path: TidesEndpoint.highLowTides(matching: query).path)))
  }
}

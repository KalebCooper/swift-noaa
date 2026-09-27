import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Salinity execution", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct SalinityClientTests {
  @Test(
    "Access levels agree with exact options and no metadata preflight",
    arguments: [
      Fixture.salinityMetric, .salinityEnglish, .salinityMetricHourly, .salinityEnglishHourly,
    ], [0, 1, 2])
  func accessLevelsAgreeWithExactOptionsAndNoMetadataPreflight(fixture: Fixture, level: Int)
    async throws
  {
    let transport = MockTransport()
    let body = try fixture.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let hourly = fixture.rawValue.contains("hourly")
    let english = fixture.rawValue.contains("english")
    let query = try Self.query(
      interval: hourly ? .hourly : .sixMinutes, units: english ? .english : .metric)
    let request = TidesRequest.salinityObservations(matching: query)
    #expect(transport.requests.isEmpty)
    let client = TidesClient(transport: transport)
    let samples: [SalinityObservation]
    switch level {
    case 0:
      let result = try await client.salinityObservations(matching: query)
      #expect(result.requestedQuery == query)
      samples = result.observations
    case 1:
      let result = try await client.value(for: request)
      #expect(result.requestedQuery == query)
      samples = result.observations
    default: samples = try await client.send(.salinityObservations(matching: query)).observations
    }
    #expect(samples.first?.salinity.rawValue == "26.38")
    #expect(samples.first?.specificGravity.rawValue == "1.022")
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/api/prod/datagetter?begin_date=20250101%2000:00&end_date=20250101%2001:00&format=json"
        + (hourly ? "&interval=h" : "") + "&product=salinity&station=8419870&time_zone=gmt&units="
        + (english ? "english" : "metric") + "&application=swift-noaa")
  }

  @Test("Cancelled requests send nothing")
  @MainActor
  func cancelledRequestsSendNothing() async throws {
    let transport = MockTransport()
    let query = try Self.query()
    let task = Task {
      await #expect(throws: TidesError.self) {
        try await TidesClient(transport: transport).salinityObservations(matching: query)
      }
    }
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected cancellation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Custom response factories remain reusable")
  func customResponseFactoriesRemainReusable() async throws {
    let transport = MockTransport()
    let body = try Fixture.salinityMetric.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let request = try TidesRequest.salinityObservationsMetadata(matching: Self.query())
    let result = try await TidesClient(transport: transport).value(for: request)
    #expect(result.metadata.identifier == "8419870")
  }

  @Test("Empty responses preserve requested and reported context separately")
  func emptyResponsesPreserveRequestedAndReportedContextSeparately() async throws {
    let transport = MockTransport()
    let body = Data(
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":[]}"#.utf8)
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let query = try Self.query()
    let result = try await TidesClient(transport: transport).value(
      for: .salinityObservations(matching: query))
    #expect(result.metadata.identifier == "reported")
    #expect(result.requestedQuery.stationIdentifier.rawValue == "8419870")
    #expect(result.observations.isEmpty)
    #expect(transport.requests.count == 1)
  }

  @Test("Provider refusals stay errors at every access level", arguments: [0, 1, 2])
  func providerRefusalsStayErrorsAtEveryAccessLevel(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.salinityNoData.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let query = try Self.query()
    let error = await #expect(throws: TidesError.self) {
      switch level {
      case 0: _ = try await client.salinityObservations(matching: query)
      case 1: _ = try await client.value(for: .salinityObservations(matching: query))
      default: _ = try await client.send(.salinityObservations(matching: query))
      }
    }
    guard case .provider(let refusal) = error else {
      Issue.record("Expected provider refusal"); return
    }
    #expect(
      refusal.message
        == "No data was found. This product may not be offered at this station at the requested time."
    )
    #expect(transport.requests.count == 1)
  }

  private static func query(
    interval: CoastalObservationInterval = .sixMinutes, units: TidesUnits = .metric
  ) throws -> CoastalObservationQuery {
    try CoastalObservationQuery(
      interval: interval,
      range: TidesDateRange(
        begin: TidesTimestamp("2025-01-01 00:00").date, end: TidesTimestamp("2025-01-01 01:00").date
      ),
      stationIdentifier: CoastalStationIdentifier("8419870"), units: units)
  }
}

private struct SalinityMetadataOnly: Decodable {
  let metadata: CoastalDataMetadata
}

extension TidesRequest where Response == SalinityMetadataOnly {
  fileprivate static func salinityObservationsMetadata(matching query: CoastalObservationQuery)
    throws -> Self
  {
    Self(
      endpoint: try #require(
        TidesEndpoint(path: TidesEndpoint.salinityObservations(matching: query).path)))
  }
}

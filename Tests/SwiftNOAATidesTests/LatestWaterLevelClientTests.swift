import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Latest water level execution", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct LatestWaterLevelClientTests {
  @Test(
    "Access levels use the exact latest selector",
    arguments: [Fixture.latestMetric, .latestEnglish], [0, 1, 2])
  func accessLevelsUseTheExactLatestSelector(fixture: Fixture, level: Int) async throws {
    let transport = MockTransport()
    let body = try fixture.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let metric = fixture == .latestMetric
    let query = try Self.query(units: metric ? .metric : .english)
    let request = TidesRequest.latestWaterLevel(matching: query)
    #expect(transport.requests.isEmpty)
    let client = TidesClient(transport: transport)
    let sample: WaterLevel?
    switch level {
    case 0:
      let result = try await client.latestWaterLevel(matching: query)
      #expect(result.requestedQuery == query)
      sample = result.observation
    case 1:
      let result = try await client.value(for: request)
      #expect(result.requestedQuery == query)
      sample = result.observation
    default: sample = try await client.send(.latestWaterLevel(matching: query)).observations.first
    }
    #expect(sample?.height.rawValue == (metric ? "0.861" : "2.826"))
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/api/prod/datagetter?date=latest&datum=MLLW&format=json&product=water_level&station=9414290&time_zone=gmt&units="
        + (metric ? "metric" : "english") + "&application=swift-noaa")
  }

  @Test("Cancellation sends nothing")
  @MainActor
  func cancellationSendsNothing() async throws {
    let transport = MockTransport()
    let query = try Self.query()
    let task = Task {
      await #expect(throws: TidesError.self) {
        try await TidesClient(transport: transport).latestWaterLevel(matching: query)
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
    let body = try Fixture.latestMetric.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let result = try await TidesClient(transport: transport).value(
      for: .latestMetadata(matching: Self.query()))
    #expect(result.metadata.identifier == "9414290")
  }

  @Test("Empty success retains reported metadata and requested context", arguments: [0, 1])
  func emptySuccessRetainsReportedMetadataAndRequestedContext(level: Int) async throws {
    let transport = MockTransport()
    let body = Data(
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":[]}"#.utf8)
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let query = try Self.query()
    let client = TidesClient(transport: transport)
    let result =
      try await
      (level == 0
      ? client.latestWaterLevel(matching: query)
      : client.value(for: .latestWaterLevel(matching: query)))
    #expect(result.observation == nil)
    #expect(result.metadata.identifier == "reported")
    #expect(result.requestedQuery == query)
    #expect(transport.requests.count == 1)
  }

  @Test("Malformed success remains a decoding failure")
  func malformedSuccessRemainsADecodingFailure() async throws {
    for raw in [
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"}}"#,
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":null}"#,
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":[{"t":"bad","v":"0"}]}"#,
    ] {
      let transport = MockTransport()
      let body = Data(raw.utf8)
      transport.setHandler(forPath: "/api/prod/datagetter") { _ in
        .success(MockTransport.Answer(Response(body: body, status: .ok)))
      }
      let error = await #expect(throws: TidesError.self) {
        try await TidesClient(transport: transport).latestWaterLevel(matching: Self.query())
      }
      guard case .decoding = error else { Issue.record("Expected decoding error"); continue }
      #expect(transport.requests.count == 1)
    }
  }

  @Test(
    "Plural success fails contextual access but the wire endpoint keeps every record",
    arguments: [0, 1, 2])
  func pluralSuccessFailsContextualAccessButTheWireEndpointKeepsEveryRecord(level: Int) async throws
  {
    let transport = MockTransport()
    var object = try #require(
      JSONSerialization.jsonObject(with: Fixture.latestMetric.data()) as? [String: Any])
    let samples = try #require(object["data"] as? [[String: Any]])
    object["data"] = samples + samples
    let body = try JSONSerialization.data(withJSONObject: object)
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let query = try Self.query()
    if level == 2 {
      #expect(try await client.send(.latestWaterLevel(matching: query)).observations.count == 2)
    } else {
      let error = await #expect(throws: TidesError.self) {
        if level == 0 {
          _ = try await client.latestWaterLevel(matching: query)
        } else {
          _ = try await client.value(for: .latestWaterLevel(matching: query))
        }
      }
      guard case .invalidLatestWaterLevelResponse(let count) = error else {
        Issue.record("Expected cardinality error"); return
      }
      #expect(count == 2)
    }
    #expect(transport.requests.count == 1)
  }

  @Test("Provider no-data remains an error at every level", arguments: [0, 1, 2])
  func providerNoDataRemainsAnErrorAtEveryLevel(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.latestNoData.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let query = try Self.query()
    let error = await #expect(throws: TidesError.self) {
      switch level {
      case 0: _ = try await client.latestWaterLevel(matching: query)
      case 1: _ = try await client.value(for: .latestWaterLevel(matching: query))
      default: _ = try await client.send(.latestWaterLevel(matching: query))
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

  @Test("Reused requests send again without caching or polling")
  func reusedRequestsSendAgainWithoutCachingOrPolling() async throws {
    let transport = MockTransport()
    let firstBody = try Fixture.latestMetric.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: firstBody, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let request = try TidesRequest.latestWaterLevel(matching: Self.query())
    #expect(try await client.value(for: request).observation?.height.rawValue == "0.861")
    let secondBody = Data(
      String(decoding: firstBody, as: UTF8.self).replacingOccurrences(of: "0.861", with: "0.900")
        .utf8)
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: secondBody, status: .ok)))
    }
    #expect(try await client.value(for: request).observation?.height.rawValue == "0.900")
    #expect(transport.requests.count == 2)
  }

  private static func query(units: TidesUnits = .metric) throws -> LatestWaterLevelQuery {
    try LatestWaterLevelQuery(
      datum: .meanLowerLowWater, stationIdentifier: CoastalStationIdentifier("9414290"),
      units: units)
  }
}

private struct LatestMetadata: Decodable {
  let metadata: CoastalDataMetadata
}

extension TidesRequest where Response == LatestMetadata {
  fileprivate static func latestMetadata(matching query: LatestWaterLevelQuery) throws -> Self {
    Self(
      endpoint: try #require(
        TidesEndpoint(path: TidesEndpoint.latestWaterLevel(matching: query).path)))
  }
}

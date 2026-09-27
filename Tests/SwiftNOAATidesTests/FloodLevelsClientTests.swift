import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Flood threshold client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct FloodLevelsClientTests {
  @Test(
    "All access levels preserve thresholds with exact units",
    arguments: [Fixture.floodlevelsMetric, .floodlevelsEnglish], [0, 1, 2])
  func allAccessLevelsPreserveThresholdsWithExactUnits(fixture: Fixture, level: Int) async throws {
    let transport = MockTransport()
    let body = try fixture.data()
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/9414290/floodlevels.json") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let station = try CoastalStationIdentifier("9414290")
    let units: TidesUnits = fixture == .floodlevelsMetric ? .metric : .english
    let request = try TidesRequest.floodLevels(stationIdentifier: station, units: units)
    #expect(transport.requests.isEmpty)
    let client = TidesClient(transport: transport)
    let result: CoastalFloodLevels
    switch level {
    case 0: result = try await client.floodLevels(stationIdentifier: station, units: units)
    case 1: result = try await client.value(for: request)
    default: result = try await client.send(.floodLevels(stationIdentifier: station, units: units))
    }
    #expect(result.nosMinor == (units == .metric ? 4.173 : 13.69))
    #expect(result.nwsMinor == (units == .metric ? 3.968 : 13.02))
    #expect(result.nwsMajor == nil)
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/mdapi/prod/webapi/stations/9414290/floodlevels.json?units=" + units.rawValue)
  }

  @Test("Cancelled metadata requests send nothing")
  @MainActor
  func cancelledMetadataRequestsSendNothing() async throws {
    let transport = MockTransport()
    let station = try CoastalStationIdentifier("9414290")
    let task = Task {
      await #expect(throws: TidesError.self) {
        try await TidesClient(transport: transport).floodLevels(
          stationIdentifier: station, units: .metric)
      }
    }
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected cancellation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Custom metadata factories retain the extension path")
  func customMetadataFactoriesRetainTheExtensionPath() async throws {
    let transport = MockTransport()
    let body = try Fixture.floodlevelsMetric.data()
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/9414290/floodlevels.json") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let request = try TidesRequest.floodLink(stationIdentifier: CoastalStationIdentifier("9414290"))
    #expect(
      try await TidesClient(transport: transport).value(for: request).selfLink.hasSuffix(
        "floodlevels.json") == true)
  }

  @Test("Invalid unit codes fail before sending")
  func invalidUnitCodesFailBeforeSending() async throws {
    let station = try CoastalStationIdentifier("9414290")
    let transport = MockTransport()
    for raw in ["", "\n"] {
      let units = TidesUnits(rawValue: raw)
      #expect(throws: TidesQueryError.invalidUnits(raw)) {
        try TidesEndpoint.floodLevels(stationIdentifier: station, units: units)
      }
      #expect(throws: TidesQueryError.invalidUnits(raw)) {
        try TidesRequest.floodLevels(stationIdentifier: station, units: units)
      }
      let error = await #expect(throws: TidesError.self) {
        try await TidesClient(transport: transport).floodLevels(
          stationIdentifier: station, units: units)
      }
      guard case .invalidQuery(.invalidUnits(let value)) = error else {
        Issue.record("Expected invalid units"); continue
      }
      #expect(value == raw)
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Provider refusal remains an error on successful HTTP status")
  func providerRefusalRemainsAnErrorOnSuccessfulHTTPStatus() async throws {
    let transport = MockTransport()
    let body = Data(#"{"errorCode":400,"errorMsg":"Constructed refusal"}"#.utf8)
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/9414290/floodlevels.json") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let error = await #expect(throws: TidesError.self) {
      try await TidesClient(transport: transport).floodLevels(
        stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric)
    }
    guard case .provider = error else { Issue.record("Expected provider refusal"); return }
  }

  @Test("Recorded unsupported station retains HTTP status and body", arguments: [0, 1, 2])
  func recordedUnsupportedStationRetainsHTTPStatusAndBody(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.floodlevelsInvalid.data()
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/9999999/floodlevels.json") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .notFound)))
    }
    let station = try CoastalStationIdentifier("9999999")
    let client = TidesClient(transport: transport)
    let error = await #expect(throws: TidesError.self) {
      switch level {
      case 0: _ = try await client.floodLevels(stationIdentifier: station, units: .metric)
      case 1:
        _ = try await client.value(for: .floodLevels(stationIdentifier: station, units: .metric))
      default: _ = try await client.send(.floodLevels(stationIdentifier: station, units: .metric))
      }
    }
    guard case .httpStatus(let reported, let code) = error else {
      Issue.record("Expected HTTP error"); return
    }
    #expect(code == 404)
    #expect(reported == body)
    #expect(transport.requests.count == 1)
  }
}

private struct FloodLink: Decodable {
  let selfLink: String
  private enum CodingKeys: String, CodingKey { case selfLink = "self" }
}

extension TidesRequest where Response == FloodLink {
  fileprivate static func floodLink(stationIdentifier: CoastalStationIdentifier) throws -> Self {
    Self(
      endpoint: try #require(
        TidesEndpoint(
          path: TidesEndpoint.floodLevels(stationIdentifier: stationIdentifier, units: .metric).path
        )))
  }
}

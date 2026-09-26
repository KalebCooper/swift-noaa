import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Sampled tides and datum client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct TidePredictionClientTests {
  @Test("Cancelled sampled predictions and datum requests send nothing", arguments: [false, true])
  @MainActor
  func cancelledSampledPredictionsAndDatumRequestsSendNothing(datums: Bool) async throws {
    let transport = MockTransport()
    let client = TidesClient(transport: transport)
    let query = try Self.query()
    let task = Task {
      await #expect(throws: TidesError.self) {
        if datums {
          _ = try await client.datums(stationIdentifier: query.stationIdentifier, units: .metric)
        } else {
          _ = try await client.tidePredictions(matching: query)
        }
      }
    }
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected cancellation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Datum access levels retain metadata without extra requests", arguments: [0, 1, 2])
  func datumAccessLevelsRetainMetadataWithoutExtraRequests(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.stationDatums.data()
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/9414290/datums.json") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let identifier = try CoastalStationIdentifier("9414290")
    let value: CoastalDatums
    switch level {
    case 0: value = try await client.datums(stationIdentifier: identifier, units: .metric)
    case 1:
      let request = try TidesRequest.datums(stationIdentifier: identifier, units: .metric)
      value = try await client.value(for: request)
    default: value = try await client.send(.datums(stationIdentifier: identifier, units: .metric))
    }
    #expect(value.units == "meters")
    #expect(value.datums.count == 15)
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/mdapi/prod/webapi/stations/9414290/datums.json?units=metric")
  }

  @Test("Invalid datum units fail before transport execution")
  func invalidDatumUnitsFailBeforeTransportExecution() async throws {
    let transport = MockTransport()
    let error = await #expect(throws: TidesError.self) {
      try await TidesClient(transport: transport).datums(
        stationIdentifier: CoastalStationIdentifier("9414290"), units: .init(rawValue: ""))
    }
    guard case .invalidQuery(.invalidUnits("")) = error else {
      Issue.record("Expected local validation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Sample access levels agree and retain requested context", arguments: [0, 1, 2])
  func sampleAccessLevelsAgreeAndRetainRequestedContext(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.tideHourly.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let query = try Self.query()
    let client = TidesClient(transport: transport)
    let samples: [TidePrediction]
    switch level {
    case 0:
      let result = try await client.tidePredictions(matching: query)
      #expect(result.requestedQuery == query); samples = result.predictions
    case 1:
      let request = TidesRequest.tidePredictions(matching: query)
      let result = try await client.value(for: request)
      #expect(result.requestedQuery == query); samples = result.predictions
    default: samples = try await client.send(.tidePredictions(matching: query)).predictions
    }
    #expect(samples.count == 24)
    #expect(samples.first?.height.value == 0.384)
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/api/prod/datagetter?begin_date=20260926%2000:00&datum=MLLW&end_date=20260926%2023:59&format=json&interval=60&product=predictions&station=9414290&time_zone=gmt&units=metric&application=swift-noaa"
    )
  }

  @Test("Subordinate sampled predictions preserve provider refusal", arguments: [0, 1, 2])
  func subordinateSampledPredictionsPreserveProviderRefusal(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.tideSubordinateSampled.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let query = try Self.query(station: "8557863")
    let error = await #expect(throws: TidesError.self) {
      switch level {
      case 0: _ = try await client.tidePredictions(matching: query)
      case 1: _ = try await client.value(for: .tidePredictions(matching: query))
      default: _ = try await client.send(.tidePredictions(matching: query))
      }
    }
    guard case .provider(let refusal) = error else {
      Issue.record("Expected provider refusal"); return
    }
    #expect(
      refusal.message == "No Predictions data was found. Please make sure the Datum input is valid."
    )
    #expect(transport.requests.count == 1)
  }

  private static func query(station: String = "9414290") throws -> TidePredictionQuery {
    try TidePredictionQuery(
      datum: .meanLowerLowWater, interval: .hourly,
      range: TidesDateRange(
        begin: TidesTimestamp("2026-09-26 00:00").date,
        end: TidesTimestamp("2026-09-26 23:59").date),
      stationIdentifier: CoastalStationIdentifier(station), units: .metric)
  }
}

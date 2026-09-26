import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Current prediction client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct CurrentPredictionClientTests {
  @Test("Cancelled current predictions send nothing", arguments: [false, true])
  @MainActor
  func cancelledCurrentPredictionsSendNothing(events: Bool) async throws {
    let transport = MockTransport()
    let task = Task {
      await #expect(throws: TidesError.self) {
        let client = TidesClient(transport: transport)
        if events {
          _ = try await client.currentEvents(matching: Self.eventQuery())
        } else {
          _ = try await client.currentPredictions(matching: Self.sampleQuery())
        }
      }
    }
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected cancellation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test(
    "Current event access levels preserve requested context and reported units",
    arguments: [0, 1, 2])
  func currentEventAccessLevelsPreserveRequestedContextAndReportedUnits(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.currentPredictions.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let query = try Self.eventQuery()
    let events: [CurrentEvent]
    switch level {
    case 0:
      let result = try await client.currentEvents(matching: query)
      #expect(result.requestedQuery == query); #expect(result.units == "meters, cm/s");
      events = result.events
    case 1:
      let request = TidesRequest.currentEvents(matching: query)
      let result = try await client.value(for: request)
      #expect(result.requestedQuery == query); events = result.events
    default: events = try await client.send(.currentEvents(matching: query)).events
    }
    #expect(events.first?.velocityMajor == 0.1)
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/api/prod/datagetter?begin_date=20260926%2000:00&bin=1&end_date=20260927%2000:00&format=json&interval=max_slack&product=currents_predictions&station=PCT1291&time_zone=gmt&units=metric&vel_type=default&application=swift-noaa"
    )
  }

  @Test("Current prediction errors remain identical at all access levels", arguments: [0, 1, 2])
  func currentPredictionErrorsRemainIdenticalAtAllAccessLevels(level: Int) async throws {
    for fixture in [
      Fixture.currentsInvalidMode, .currentPredictionInvalidBin, .currentEventsOverYear,
    ] {
      let transport = MockTransport()
      let body = try fixture.data()
      transport.setHandler(forPath: "/api/prod/datagetter") { _ in
        .success(MockTransport.Answer(Response(body: body, status: .ok)))
      }
      let client = TidesClient(transport: transport)
      let error = await #expect(throws: TidesError.self) {
        if fixture == .currentEventsOverYear {
          switch level {
          case 0: _ = try await client.currentEvents(matching: Self.eventQuery())
          case 1: _ = try await client.value(for: .currentEvents(matching: Self.eventQuery()))
          default: _ = try await client.send(.currentEvents(matching: Self.eventQuery()))
          }
        } else {
          switch level {
          case 0: _ = try await client.currentPredictions(matching: Self.sampleQuery())
          case 1: _ = try await client.value(for: .currentPredictions(matching: Self.sampleQuery()))
          default: _ = try await client.send(.currentPredictions(matching: Self.sampleQuery()))
          }
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

  @Test(
    "Current sample access levels preserve both representations", arguments: [0, 1, 2],
    [false, true])
  func currentSampleAccessLevelsPreserveBothRepresentations(level: Int, speed: Bool) async throws {
    let transport = MockTransport()
    let body = try (speed ? Fixture.currentsSpeedDirectionCurrent : .currentsMajor).data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let query = try Self.sampleQuery()
    let predictions: [CurrentPrediction]
    switch level {
    case 0:
      let result = try await client.currentPredictions(matching: query)
      #expect(result.requestedQuery == query)
      #expect(result.units == (speed ? "feet, knots" : "meters, cm/s"));
      predictions = result.predictions
    case 1:
      let request = TidesRequest.currentPredictions(matching: query)
      let result = try await client.value(for: request)
      #expect(result.requestedQuery.mode == .speedAndDirection); predictions = result.predictions
    default: predictions = try await client.send(.currentPredictions(matching: query)).predictions
    }
    #expect(predictions.count == 7)
    if speed {
      #expect(
        predictions.first?.velocity
          == .speedAndDirection(direction: 261, speed: try TidesNumericValue("2.246")))
    } else {
      #expect(
        predictions.first?.velocity
          == .major(meanEbbDirection: 90, meanFloodDirection: 260, velocity: -76.1))
    }
    #expect(transport.requests.count == 1)
    #expect(
      transport.requests.first?.request.path
        == "/api/prod/datagetter?begin_date=20260926%2000:00&bin=14&end_date=20260926%2001:00&format=json&interval=10&product=currents_predictions&station=EPT0003&time_zone=gmt&units=english&vel_type=speed_dir&application=swift-noaa"
    )
  }

  @Test("Custom current prediction responses use the shared executor")
  func customCurrentPredictionResponsesUseTheSharedExecutor() async throws {
    let transport = MockTransport()
    let body = try Fixture.currentPredictions.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let request = try TidesRequest<CurrentUnitsOnly>.currentUnits(matching: Self.eventQuery())
    let result = try await TidesClient(transport: transport).value(for: request)
    #expect(result.current_predictions.units == "meters, cm/s")
    #expect(transport.requests.count == 1)
  }

  @Test("Default current prediction bins remain requested choices and reported values")
  func defaultCurrentPredictionBinsRemainRequestedChoicesAndReportedValues() async throws {
    let transport = MockTransport()
    let body = try Fixture.currentsEventsDefaultBin.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let explicit = try Self.eventQuery()
    let query = try CurrentEventQuery(
      bin: .providerDefault, range: explicit.range, stationIdentifier: explicit.stationIdentifier,
      units: .metric)
    let result = try await TidesClient(transport: transport).currentEvents(matching: query)
    #expect(result.requestedQuery.bin == .providerDefault)
    #expect(result.events.first?.bin == "1")
    #expect(transport.requests.count == 1)
    #expect(transport.requests.first?.request.path?.contains("bin=") == false)
  }

  @Test("Subordinate events never masquerade as sampled predictions", arguments: [0, 1, 2])
  func subordinateEventsNeverMasqueradeAsSampledPredictions(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.currentSubordinateSamples.data()
    transport.setHandler(forPath: "/api/prod/datagetter") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let original = try Self.sampleQuery()
    let query = try CurrentPredictionQuery(
      bin: .explicit(1), interval: .everyTenMinutes, mode: .major, range: original.range,
      stationIdentifier: CoastalStationIdentifier("ACT0091"), units: .metric)
    let error = await #expect(throws: TidesError.self) {
      switch level {
      case 0: _ = try await client.currentPredictions(matching: query)
      case 1: _ = try await client.value(for: .currentPredictions(matching: query))
      default: _ = try await client.send(.currentPredictions(matching: query))
      }
    }
    guard case .decoding = error else {
      Issue.record("Expected mismatched representation failure"); return
    }
    #expect(transport.requests.count == 1)
  }

  private static func eventQuery() throws -> CurrentEventQuery {
    try CurrentEventQuery(
      bin: .explicit(1),
      range: TidesDateRange(
        begin: TidesTimestamp("2026-09-26 00:00").date, end: TidesTimestamp("2026-09-27 00:00").date
      ), stationIdentifier: CoastalStationIdentifier("PCT1291"), units: .metric)
  }

  private static func sampleQuery() throws -> CurrentPredictionQuery {
    try CurrentPredictionQuery(
      bin: .explicit(14), interval: .everyTenMinutes, mode: .speedAndDirection,
      range: TidesDateRange(
        begin: TidesTimestamp("2026-09-26 00:00").date, end: TidesTimestamp("2026-09-26 01:00").date
      ), stationIdentifier: CoastalStationIdentifier("EPT0003"), units: .english)
  }
}

private struct CurrentUnitsOnly: Decodable {
  struct Payload: Decodable { let units: String }
  let current_predictions: Payload
}

extension TidesRequest where Response == CurrentUnitsOnly {
  fileprivate static func currentUnits(matching query: CurrentEventQuery) throws -> Self {
    Self(
      endpoint: try #require(TidesEndpoint(path: TidesEndpoint.currentEvents(matching: query).path))
    )
  }
}

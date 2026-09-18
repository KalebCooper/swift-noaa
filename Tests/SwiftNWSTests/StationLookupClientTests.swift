import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Station and timed-observation client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct StationLookupClientTests {
  private static let observationPath = "/stations/KATT/observations/2026-09-18T01:51:00Z"

  // 2026-09-18T01:51:00Z, the instant recorded in Fixture.observationAtTimestamp.
  private let recordedTimestamp = Date(timeIntervalSince1970: 1_789_696_260)

  @Test("A cancelled lookup sends nothing", arguments: [false, true], [false, true])
  @MainActor
  func aCancelledLookupSendsNothing(station: Bool, useRequest: Bool) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let timestamp = recordedTimestamp
    let task = Task {
      await #expect(throws: NWSError.self) {
        switch (station, useRequest) {
        case (true, true): _ = try await client.value(for: .observationStation(identifier: "KATT"))
        case (true, false): _ = try await client.observationStation(identifier: "KATT")
        case (false, true):
          _ = try await client.value(
            for: .observation(stationIdentifier: "KATT", timestamp: timestamp))
        case (false, false):
          _ = try await client.observation(stationIdentifier: "KATT", timestamp: timestamp)
        }
      }
    }
    // The inherited main actor keeps the task from starting before cancellation.
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected transport cancellation")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("A consumer-defined station response decodes through a custom endpoint")
  func aConsumerDefinedStationResponseDecodesThroughACustomEndpoint() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/stations/KATT", with: .observationStation)
    let client = makeClient(transport)
    let request = WeatherRequest(
      endpoint: Endpoint<Feature<StationProvider>>(path: "/stations/KATT"))
    #expect(transport.requests.isEmpty)

    let result = try await client.value(for: request)

    #expect(result.properties == StationProvider(provider: "ASOS"))
    #expect(transport.requests.count == 1)
  }

  @Test("A consumer-defined factory and a stored request infer their responses")
  func aConsumerDefinedFactoryAndAStoredRequestInferTheirResponses() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/stations/KATT", with: .observationStation)
    try answer(transport, path: Self.observationPath, with: .observationAtTimestamp)
    let client = makeClient(transport)
    let stored = WeatherRequest.observationStation(identifier: "KATT")
    let timed = WeatherRequest.observation(stationIdentifier: "KATT", timestamp: recordedTimestamp)
    #expect(transport.requests.isEmpty)

    let station = try await client.value(for: stored)
    let named = try await client.value(for: .campMabry)
    let observation = try await client.value(for: timed)

    #expect(station == named)
    #expect(station.stationIdentifier == "KATT")
    #expect(observation.timestamp == recordedTimestamp)
    #expect(
      transport.requests.map(\.request.path) == [
        "/stations/KATT", "/stations/KATT", Self.observationPath,
      ])
  }

  @Test("An empty station identifier is rejected without sending", arguments: [0, 1, 2, 3])
  func anEmptyStationIdentifierIsRejectedWithoutSending(layer: Int) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)

    let failure = await #expect(throws: NWSError.self) {
      switch layer {
      case 0: _ = try await client.observationStation(identifier: "")
      case 1: _ = try await client.value(for: .observationStation(identifier: ""))
      case 2: _ = try await client.observation(stationIdentifier: "", timestamp: recordedTimestamp)
      default:
        _ = try await client.value(
          for: .observation(stationIdentifier: "", timestamp: recordedTimestamp))
      }
    }

    guard case .invalidStationIdentifier("") = failure else {
      Issue.record("Expected an invalid identifier, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test(
    "An instant with no observation is thrown as the service's problem without a fallback",
    arguments: [false, true])
  func anInstantWithNoObservationIsThrownAsTheServicesProblemWithoutAFallback(
    useRequest: Bool
  ) async throws {
    let transport = MockTransport()
    let path = "/stations/KATT/observations/2026-09-18T01:50:00Z"
    try answer(transport, path: path, status: .notFound, with: .observationNotFound)
    let client = makeClient(transport)
    let between = recordedTimestamp.addingTimeInterval(-60)

    let failure = await #expect(throws: NWSError.self) {
      if useRequest {
        _ = try await client.value(for: .observation(stationIdentifier: "KATT", timestamp: between))
      } else {
        _ = try await client.observation(stationIdentifier: "KATT", timestamp: between)
      }
    }

    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.status == 404)
    #expect(problem.type == "https://api.weather.gov/problems/NotFound")
    #expect(transport.requests.map(\.request.path) == [path])
  }

  @Test("Station access layers agree", arguments: [0, 1, 2])
  func stationAccessLayersAgree(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/stations/KATT", with: .observationStation)
    let client = makeClient(transport)
    let result: ObservationStation =
      switch layer {
      case 0: try await client.observationStation(identifier: "KATT")
      case 1: try await client.value(for: .observationStation(identifier: "KATT"))
      default: try await client.send(Endpoint.observationStation(identifier: "KATT")).properties
      }
    let recorded = try JSONDecoder().decode(
      Feature<ObservationStation>.self, from: Fixture.observationStation.data())
    #expect(result == recorded.properties)
    #expect(transport.requests.map(\.request.path) == ["/stations/KATT"])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/geo+json")
    #expect(transport.requests[0].request.headerFields[.userAgent] == "station-tests")
  }

  @Test("Timed observation access layers agree", arguments: [0, 1, 2])
  func timedObservationAccessLayersAgree(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: Self.observationPath, with: .observationAtTimestamp)
    let client = makeClient(transport)
    let timestamp = recordedTimestamp
    let result: WeatherObservation =
      switch layer {
      case 0: try await client.observation(stationIdentifier: "KATT", timestamp: timestamp)
      case 1:
        try await client.value(for: .observation(stationIdentifier: "KATT", timestamp: timestamp))
      default:
        try await client.send(Endpoint.observation(stationIdentifier: "KATT", timestamp: timestamp))
          .properties
      }
    let recorded = try JSONDecoder().decode(
      Feature<WeatherObservation>.self, from: Fixture.observationAtTimestamp.data())
    #expect(result == recorded.properties)
    #expect(transport.requests.map(\.request.path) == [Self.observationPath])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/geo+json")
    #expect(transport.requests[0].request.headerFields[.userAgent] == "station-tests")
  }

  private func answer(
    _ transport: MockTransport, path: String, status: HTTPResponse.Status = .ok,
    with fixture: Fixture
  ) throws {
    let body = try fixture.data()
    transport.setHandler(forPath: path) { _ in
      .success(MockTransport.Answer(Response(body: body, status: status)))
    }
  }

  private func makeClient(_ transport: MockTransport) -> NWSClient {
    NWSClient(configuration: .init(userAgent: "station-tests"), transport: transport)
  }
}

private struct StationProvider: Decodable, Equatable, Sendable {
  var provider: String
}

extension WeatherRequest where Response == ObservationStation {
  fileprivate static var campMabry: Self { .observationStation(identifier: "KATT") }
}

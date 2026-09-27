import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Coastal metadata execution", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct CoastalMetadataClientTests {

  @Test("Cancelled metadata requests send nothing")
  @MainActor
  func cancelledMetadataRequestsSendNothing() async throws {
    let transport = MockTransport()
    let id = try CoastalStationIdentifier("9414290")
    let task = Task {
      await #expect(throws: TidesError.self) {
        try await TidesClient(transport: transport).sensors(stationIdentifier: id, units: .metric)
      }
    }
    task.cancel()
    guard case .transport(.cancelled) = await task.value else {
      Issue.record("Expected cancellation"); return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Custom metadata responses retain constrained factory inference")
  func customMetadataResponsesRetainConstrainedFactoryInference() async throws {
    let transport = MockTransport()
    let body = try Fixture.sensorsEnglish.data()
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/9414290/sensors.json") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let request = try TidesRequest.sensorUnits(
      stationIdentifier: CoastalStationIdentifier("9414290"))
    #expect(transport.requests.isEmpty)
    let result = try await TidesClient(transport: transport).value(for: request)
    #expect(result.units == "feet")
    #expect(transport.requests.count == 1)
  }

  @Test("Invalid metadata arguments fail before sending")
  func invalidMetadataArgumentsFailBeforeSending() async throws {
    let transport = MockTransport()
    let client = TidesClient(transport: transport)
    let error = await #expect(throws: TidesError.self) {
      try await client.sensors(
        stationIdentifier: CoastalStationIdentifier("9414290"), units: .init(rawValue: ""))
    }
    guard case .invalidQuery(.invalidUnits("")) = error else {
      Issue.record("Expected invalid units"); return
    }
    #expect(throws: TidesQueryError.self) { try CoastalStationIdentifier("../station") }
    #expect(transport.requests.isEmpty)
  }

  @Test("Metadata access levels agree without implicit requests", arguments: [0, 1, 2])
  func metadataAccessLevelsAgreeWithoutImplicitRequests(level: Int) async throws {
    let transport = MockTransport()
    let notices = try Fixture.noticesPopulated.data()
    let sensors = try Fixture.sensorsMetric.data()
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/8638610/notices.json") { _ in
      .success(MockTransport.Answer(Response(body: notices, status: .ok)))
    }
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/8638610/sensors.json") { _ in
      .success(MockTransport.Answer(Response(body: sensors, status: .ok)))
    }
    let id = try CoastalStationIdentifier("8638610")
    let noticesRequest = TidesRequest.notices(stationIdentifier: id)
    let sensorsRequest = try TidesRequest.sensors(stationIdentifier: id, units: .metric)
    #expect(transport.requests.isEmpty)
    let client = TidesClient(transport: transport)
    let n: CoastalNotices
    let s: CoastalSensors
    switch level {
    case 0:
      n = try await client.notices(stationIdentifier: id)
      s = try await client.sensors(stationIdentifier: id, units: .metric)
    case 1:
      n = try await client.value(for: noticesRequest)
      s = try await client.value(for: sensorsRequest)
    default:
      n = try await client.send(.notices(stationIdentifier: id))
      s = try await client.send(.sensors(stationIdentifier: id, units: .metric))
    }
    #expect(n.notices.first?.name == "High Water Condition")
    #expect(s.sensors?.first?.identifier == "C1")
    #expect(transport.requests.count == 2)
    #expect(
      transport.requests.last?.request.path
        == "/mdapi/prod/webapi/stations/8638610/sensors.json?units=metric")
  }

  @Test("Metadata refusals and malformed envelopes remain errors")
  func metadataRefusalsAndMalformedEnvelopesRemainErrors() async throws {
    for body in [try Fixture.stationInvalidMDAPI.data(), Data("{}".utf8)] {
      let transport = MockTransport()
      transport.setHandler(forPath: "/mdapi/prod/webapi/stations/9414290/sensors.json") { _ in
        .success(MockTransport.Answer(Response(body: body, status: .ok)))
      }
      let error = await #expect(throws: TidesError.self) {
        try await TidesClient(transport: transport).sensors(
          stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric)
      }
      if body == Data("{}".utf8) {
        guard case .decoding = error else { Issue.record("Expected decoding failure"); continue }
      } else {
        guard case .provider = error else { Issue.record("Expected provider refusal"); continue }
      }
      #expect(transport.requests.count == 1)
    }
  }

  @Test("Unknown stations preserve successful null sensors at every level", arguments: [0, 1, 2])
  func unknownStationsPreserveSuccessfulNullSensorsAtEveryLevel(level: Int) async throws {
    let transport = MockTransport()
    let body = try Fixture.sensorsInvalid.data()
    transport.setHandler(forPath: "/mdapi/prod/webapi/stations/invalid/sensors.json") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = TidesClient(transport: transport)
    let id = try CoastalStationIdentifier("invalid")
    let result: CoastalSensors
    switch level {
    case 0: result = try await client.sensors(stationIdentifier: id, units: .metric)
    case 1: result = try await client.value(for: .sensors(stationIdentifier: id, units: .metric))
    default: result = try await client.send(.sensors(stationIdentifier: id, units: .metric))
    }
    #expect(result.sensors == nil)
    #expect(transport.requests.count == 1)
  }

}

private struct SensorUnitsOnly: Decodable {
  let units: String
}

extension TidesRequest where Response == SensorUnitsOnly {
  fileprivate static func sensorUnits(stationIdentifier: CoastalStationIdentifier) throws -> Self {
    Self(
      endpoint: try #require(
        TidesEndpoint(
          path: TidesEndpoint.sensors(stationIdentifier: stationIdentifier, units: .english).path)))
  }
}

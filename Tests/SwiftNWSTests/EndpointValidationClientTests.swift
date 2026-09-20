import Foundation
import HTTPCore
import HTTPTesting
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Endpoint validation during execution", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct EndpointValidationClientTests {
  private struct Reading: Decodable, Equatable, Sendable {
    let value: Int
  }

  @Test("Accepted custom paths reach the transport unchanged")
  func acceptedCustomPathsReachTheTransportUnchanged() async throws {
    let transport = MockTransport()
    let client = NWSClient(configuration: .init(userAgent: "tests"), transport: transport)
    let path = "/custom?api_key=allowed&id[]=A&id[]=B&cursor=a%2fb%3D"
    let endpoint = try #require(Endpoint<Reading>(path: path))
    let request = WeatherRequest(endpoint: endpoint)
    #expect(transport.requests.isEmpty)
    for _ in 0..<2 {
      transport.enqueue(
        .success(.init(Response(body: Data(#"{"value":7}"#.utf8), status: .ok))))
    }
    #expect(try await client.send(endpoint) == Reading(value: 7))
    #expect(try await client.value(for: request) == Reading(value: 7))
    #expect(transport.requests.map(\.request.path) == [path, path])
  }

  @Test(
    "Invalid identifiers never send a request",
    arguments: [".", "..", "A/../B", "A\\B", "A\nB"], [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
  func invalidIdentifiersNeverSendARequest(identifier: String, operation: Int) async throws {
    let transport = MockTransport()
    let client = NWSClient(configuration: .init(userAgent: "tests"), transport: transport)
    let timestamp = Date(timeIntervalSince1970: 0)
    let error = await #expect(throws: NWSError.self) {
      switch operation {
      case 0: _ = try await client.alert(identifier: identifier)
      case 1: _ = try await client.value(for: .alert(identifier: identifier))
      case 2: _ = try await client.observationStation(identifier: identifier)
      case 3: _ = try await client.value(for: .observationStation(identifier: identifier))
      case 4: _ = try await client.latestObservation(from: .station(identifier))
      case 5: _ = try await client.value(for: .latestObservation(from: .station(identifier)))
      case 6:
        _ = try await client.observation(stationIdentifier: identifier, timestamp: timestamp)
      case 7:
        _ = try await client.value(
          for: .observation(stationIdentifier: identifier, timestamp: timestamp))
      case 8: _ = try await client.activeAlerts(inArea: AreaCode(rawValue: identifier))
      case 9: _ = try await client.activeAlerts(inRegion: MarineRegionCode(rawValue: identifier))
      default: _ = try await client.activeAlerts(inZone: identifier)
      }
    }
    switch error {
    case .invalidAlertIdentifier(let value):
      #expect(operation < 2 && value == identifier)
    case .invalidStationIdentifier(let value):
      #expect((2...7).contains(operation) && value == identifier)
    case .invalidAlertLocation(let value):
      #expect(operation > 7 && value == identifier)
    default: Issue.record("Expected identifier validation, got \(String(describing: error))")
    }
    #expect(transport.requests.isEmpty)
  }

  @Test(
    "Invalid pagination paths fail before yielding the page",
    arguments: ["/stations/../other", "/%2fhost", "/stations/%2e%2e", "/stations/a%5Cb"])
  func invalidPaginationPathsFailBeforeYieldingThePage(path: String) async throws {
    let transport = MockTransport()
    var page = try JSONDecoder().decode(
      FeatureCollection<ObservationStation>.self, from: Fixture.observationStations.data())
    let link = "https://api.weather.gov" + path
    page.pagination = .init(next: link)
    transport.enqueue(
      .success(.init(Response(body: try JSONEncoder().encode(page), status: .ok))))
    let client = NWSClient(configuration: .init(userAgent: "tests"), transport: transport)
    var iterator = client.observationStationPages(query: try ObservationStationQuery())
      .makeAsyncIterator()
    let error = await #expect(throws: NWSError.self) { try await iterator.next() }
    guard case .pagination(.invalidNext(let raw)) = error else {
      Issue.record("Expected invalid continuation"); return
    }
    #expect(raw == link)
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.count == 1)
  }

  @Test(
    "Invalid point links fail before the linked request",
    arguments: ["/a/../b", "/a/%2e%2E", "/a%5Cb", "/%2fhost"], [0, 1, 2, 3])
  func invalidPointLinksFailBeforeTheLinkedRequest(path: String, operation: Int) async throws {
    let transport = MockTransport()
    var point = try JSONDecoder().decode(Feature<Point>.self, from: Fixture.point.data())
    let link = try #require(URL(string: "https://api.weather.gov" + path))
    point.properties.forecast = link
    point.properties.forecastHourly = link
    point.properties.forecastGridData = link
    point.properties.observationStations = link
    transport.enqueue(
      .success(.init(Response(body: try JSONEncoder().encode(point), status: .ok))))
    let client = NWSClient(configuration: .init(userAgent: "tests"), transport: transport)
    let home = try WeatherCoordinate(latitude: 30, longitude: -97)
    let error = await #expect(throws: NWSError.self) {
      switch operation {
      case 0: _ = try await client.forecast(for: home)
      case 1: _ = try await client.hourlyForecast(for: home)
      case 2: _ = try await client.forecastGrid(for: home)
      default: _ = try await client.observationStations(near: home)
      }
    }
    guard case .invalidLink(let actual) = error else {
      Issue.record("Expected invalid link"); return
    }
    #expect(actual == link)
    #expect(transport.requests.count == 1)
  }

  @Test(
    "Invalid redirect paths are rejected before resolution can normalize them",
    arguments: [
      "/a/../b", "../stations", "/a/%2e%2E/b", "/%2fhost", "/a%5Cb",
      "https://api.weather.gov/a/../b", "//api.weather.gov/stations",
    ], [false, true])
  func invalidRedirectPathsAreRejectedBeforeResolutionCanNormalizeThem(
    location: String, sequence: Bool
  ) async throws {
    let transport = MockTransport()
    transport.enqueue(
      .success(.init(Response(headers: [.location: location], status: .found))))
    let client = NWSClient(configuration: .init(userAgent: "tests"), transport: transport)
    let error: NWSError?
    if sequence {
      var iterator = client.activeAlertPages().makeAsyncIterator()
      error = await #expect(throws: NWSError.self) { try await iterator.next() }
      #expect(try await iterator.next() == nil)
    } else {
      error = await #expect(throws: NWSError.self) { try await client.activeAlerts() }
    }
    guard case .invalidLink = error else { Issue.record("Expected invalid link"); return }
    #expect(transport.requests.count == 1)
  }

  @Test(
    "Malformed redirects retain the invalid redirect error",
    arguments: ["/a%", "/a%2Z", "/raw space", "/raw\\path"])
  func malformedRedirectsRetainTheInvalidRedirectError(location: String) async throws {
    let transport = MockTransport()
    transport.enqueue(
      .success(.init(Response(headers: [.location: location], status: .found))))
    let client = NWSClient(configuration: .init(userAgent: "tests"), transport: transport)
    let error = await #expect(throws: NWSError.self) { try await client.activeAlerts() }
    guard case .invalidRedirect(let actual) = error else {
      Issue.record("Expected invalid redirect"); return
    }
    #expect(actual == location)
    #expect(transport.requests.count == 1)
  }
}

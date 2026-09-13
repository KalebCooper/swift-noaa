import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Alert client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct AlertClientTests {
  @Test("Alert access layers agree", arguments: [0, 1, 2], [0, 1, 2, 3])
  func accessLayersAgree(layer: Int, selection: Int) async throws {
    let location = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
    let endpoints: [Endpoint<FeatureCollection<WeatherAlert>>] = [
      .activeAlerts(for: location), .activeAlerts(inArea: "TX"),
      .activeAlerts(inZone: "TXZ192"), .activeAlerts(matching: .init(severity: [.moderate])),
    ]
    let requests: [WeatherRequest<FeatureCollection<WeatherAlert>>] = [
      .activeAlerts(for: location), .activeAlerts(inArea: "TX"),
      .activeAlerts(inZone: "TXZ192"), .activeAlerts(matching: .init(severity: [.moderate])),
    ]
    let body = try Fixture.activeAlerts.data()
    let transport = MockTransport()
    let endpoint = endpoints[selection]
    transport.setHandler(forPath: String(endpoint.path.split(separator: "?")[0])) { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = NWSClient(configuration: .init(userAgent: "alert-tests"), transport: transport)
    let result: FeatureCollection<WeatherAlert>
    if layer == 0 {
      switch selection {
      case 0: result = try await client.activeAlerts(for: location)
      case 1: result = try await client.activeAlerts(inArea: "TX")
      case 2: result = try await client.activeAlerts(inZone: "TXZ192")
      default: result = try await client.activeAlerts(matching: .init(severity: [.moderate]))
      }
    } else if layer == 1 {
      result = try await client.value(for: requests[selection])
    } else {
      result = try await client.send(endpoint)
    }
    #expect(result == (try JSONDecoder().decode(FeatureCollection<WeatherAlert>.self, from: body)))
    #expect(transport.requests.map(\.request.path) == [endpoint.path])
    #expect(transport.requests[0].request.headerFields[.userAgent] == "alert-tests")
    #expect(transport.requests[0].request.headerFields[.accept] == "application/geo+json")
  }

  @Test("Cancellation between redirect hops prevents another request")
  func cancellationBetweenHops() async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/alerts/active") { _ in
      withUnsafeCurrentTask { $0?.cancel() }
      return .success(
        MockTransport.Answer(
          Response(headers: [.location: "/alerts/active/area/TX"], status: .movedPermanently)))
    }
    let client = NWSClient(configuration: .init(userAgent: "test"), transport: transport)
    let work = Task {
      await #expect(throws: NWSError.self) { try await client.activeAlerts() }
    }
    guard case .transport(.cancelled) = await work.value else {
      Issue.record("Expected transport cancellation")
      return
    }
    #expect(transport.requests.count == 1)
  }

  @Test("Empty lists return immediately without following pagination")
  func emptyCollection() async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/alerts/active") { _ in
      .success(
        MockTransport.Answer(
          Response(
            body: Data(
              #"{"features":[],"pagination":{"next":"https://api.weather.gov/next"}}"#.utf8),
            status: .ok)))
    }
    let client = NWSClient(configuration: .init(userAgent: "test"), transport: transport)
    #expect(try await client.activeAlerts().features.isEmpty)
    #expect(transport.requests.count == 1)
  }

  @Test(
    "Redirects preserve headers and decode recorded canonical responses",
    arguments: [
      "/alerts/active/area/TX", "https://api.weather.gov/alerts/active/area/TX", "active/area/TX",
    ])
  func followsCanonicalRedirect(location: String) async throws {
    let transport = MockTransport()
    let body = try Fixture.areaAlerts.data()
    transport.setHandler(forPath: "/alerts/active") { _ in
      .success(
        MockTransport.Answer(Response(headers: [.location: location], status: .movedPermanently)))
    }
    transport.setHandler(forPath: "/alerts/active/area/TX") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = NWSClient(configuration: .init(userAgent: "test"), transport: transport)
    let result = try await client.activeAlerts(matching: .init(location: .areas(["TX"])))
    #expect(result.features.count == 12)
    #expect(
      transport.requests.map(\.request.path) == [
        "/alerts/active?area=TX", "/alerts/active/area/TX",
      ])
    #expect(transport.requests.allSatisfy { $0.request.headerFields[.userAgent] == "test" })
  }

  @Test("Redirect loops and hop limits terminate", arguments: [false, true])
  func redirectsAreBounded(loop: Bool) async throws {
    let transport = MockTransport()
    for index in 0...6 {
      let path = index == 0 ? "/alerts/active" : "/hop/\(index)"
      transport.setHandler(forPath: path) { _ in
        .success(
          MockTransport.Answer(
            Response(
              headers: [.location: loop ? "/alerts/active" : "/hop/\(index + 1)"],
              status: .movedPermanently)))
      }
    }
    let client = NWSClient(configuration: .init(userAgent: "test"), transport: transport)
    let error = await #expect(throws: NWSError.self) { try await client.activeAlerts() }
    guard case .tooManyRedirects = error else {
      Issue.record("Expected bounded redirects")
      return
    }
    #expect(transport.requests.count == (loop ? 1 : 6))
  }

  @Test(
    "Redirects cannot escape the API origin",
    arguments: [
      "https://example.com/alerts", "http://api.weather.gov/alerts",
      "https://user:password@api.weather.gov/alerts", "https://api.weather.gov:444/alerts",
      "https://api.weather.gov/alerts#fragment",
    ])
  func rejectsRedirectOrigin(location: String) async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/alerts/active") { _ in
      .success(
        MockTransport.Answer(Response(headers: [.location: location], status: .movedPermanently)))
    }
    let client = NWSClient(configuration: .init(userAgent: "test"), transport: transport)
    let error = await #expect(throws: NWSError.self) { try await client.activeAlerts() }
    guard case .invalidLink = error else { Issue.record("Expected invalid link"); return }
    #expect(transport.requests.count == 1)
  }

  @Test(
    "Single alert convenience and reusable request unwrap the same feature",
    arguments: [false, true])
  func singleAlert(useRequest: Bool) async throws {
    let transport = MockTransport()
    let body = try Fixture.alert.data()
    transport.setHandler(forPath: "/alerts/example") { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = NWSClient(configuration: .init(userAgent: "test"), transport: transport)
    let result =
      try await
      (useRequest
      ? client.value(for: .alert(identifier: "example")) : client.alert(identifier: "example"))
    #expect(result == (try JSONDecoder().decode(Feature<WeatherAlert>.self, from: body)).properties)
    let error = await #expect(throws: NWSError.self) { try await client.alert(identifier: "") }
    guard case .invalidAlertIdentifier("") = error else {
      Issue.record("Expected empty identifier error"); return
    }
    #expect(transport.requests.count == 1)
  }
}

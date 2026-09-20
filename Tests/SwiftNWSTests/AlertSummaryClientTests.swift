import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Alert count, type, and region client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct AlertSummaryClientTests {
  @Test("A cancelled count or type lookup sends nothing", arguments: [false, true])
  func aCancelledCountOrTypeLookupSendsNothing(types: Bool) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let task = Task {
      await #expect(throws: NWSError.self) {
        if types {
          _ = try await client.alertTypes()
        } else {
          _ = try await client.activeAlertCount()
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

  @Test("A consumer-defined count response decodes through a custom endpoint")
  func aConsumerDefinedCountResponseDecodesThroughACustomEndpoint() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/alerts/active/count", with: .activeAlertCount)
    let client = makeClient(transport)
    let request = WeatherRequest(
      endpoint: try #require(Endpoint<TotalOnly>(accept: .jsonLD, path: "/alerts/active/count")))
    #expect(try await client.value(for: request) == TotalOnly(total: 244))
  }

  @Test("Active alert count access layers agree", arguments: [0, 1, 2])
  func activeAlertCountAccessLayersAgree(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/alerts/active/count", with: .activeAlertCount)
    let client = makeClient(transport)
    let result: ActiveAlertCount =
      switch layer {
      case 0: try await client.activeAlertCount()
      case 1: try await client.value(for: .activeAlertCount)
      default: try await client.send(Endpoint.activeAlertCount)
      }
    #expect(
      result
        == (try JSONDecoder().decode(ActiveAlertCount.self, from: Fixture.activeAlertCount.data())))
    #expect(transport.requests.map(\.request.path) == ["/alerts/active/count"])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/ld+json")
    #expect(transport.requests[0].request.headerFields[.userAgent] == "summary-tests")
  }

  @Test("Alert type access layers agree", arguments: [0, 1, 2])
  func alertTypeAccessLayersAgree(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/alerts/types", with: .alertTypes)
    let client = makeClient(transport)
    let result: AlertTypes =
      switch layer {
      case 0: try await client.alertTypes()
      case 1: try await client.value(for: .alertTypes)
      default: try await client.send(Endpoint.alertTypes)
      }
    #expect(
      result == (try JSONDecoder().decode(AlertTypes.self, from: Fixture.alertTypes.data())))
    #expect(transport.requests.map(\.request.path) == ["/alerts/types"])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/ld+json")
    #expect(transport.requests[0].request.headerFields[.userAgent] == "summary-tests")
  }

  @Test("An unrecognized region is thrown as the service's problem", arguments: [false, true])
  func anUnrecognizedRegionIsThrownAsTheServicesProblem(useRequest: Bool) async throws {
    let transport = MockTransport()
    try answer(
      transport, path: "/alerts/active/region/XX", status: .notFound, with: .unknownRegionProblem)
    let client = makeClient(transport)
    let region = MarineRegionCode(rawValue: "XX")
    let failure = await #expect(throws: NWSError.self) {
      if useRequest {
        _ = try await client.value(for: try #require(.activeAlerts(inRegion: region)))
      } else {
        _ = try await client.activeAlerts(inRegion: region)
      }
    }
    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.status == 404)
    #expect(
      problem.parameterErrors == [
        ProblemDetail.ParameterError(
          message: #"Does not have a value in the enumeration ["AL","AT","GL","GM","PA","PI"]"#,
          parameter: "path.region")
      ])
    #expect(transport.requests.map(\.request.path) == ["/alerts/active/region/XX"])
  }

  @Test("Region access layers agree", arguments: [0, 1, 2, 3])
  func regionAccessLayersAgree(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/alerts/active/region/AT", with: .regionAlerts)
    let client = makeClient(transport)
    let result: FeatureCollection<WeatherAlert> =
      switch layer {
      case 0: try await client.activeAlerts(inRegion: .atlantic)
      case 1: try await client.activeAlerts(inRegion: ConsumerRegion.atlantic)
      case 2: try await client.value(for: try #require(.activeAlerts(inRegion: .atlantic)))
      default: try await client.send(try #require(Endpoint.activeAlerts(inRegion: .atlantic)))
      }
    #expect(
      result
        == (try JSONDecoder().decode(
          FeatureCollection<WeatherAlert>.self, from: Fixture.regionAlerts.data())))
    #expect(transport.requests.map(\.request.path) == ["/alerts/active/region/AT"])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/geo+json")
  }

  @Test("Region sequences end after a page without pagination")
  func regionSequencesEndAfterAPageWithoutPagination() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/alerts/active/region/AT", with: .regionAlerts)
    let client = makeClient(transport)
    var pages = 0
    for try await page in client.activeAlertPages(
      for: try #require(.activeAlerts(inRegion: .atlantic)))
    {
      pages += 1
      #expect(page.features.count == 2)
    }
    var events: [String] = []
    for try await alert in client.activeAlerts(
      for: try #require(.activeAlerts(inRegion: .atlantic)))
    {
      events.append(alert.properties.event)
    }
    #expect(pages == 1)
    #expect(events == ["Marine Weather Statement", "Small Craft Advisory"])
    #expect(
      transport.requests.map(\.request.path)
        == Array(repeating: "/alerts/active/region/AT", count: 2))
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
    NWSClient(configuration: .init(userAgent: "summary-tests"), transport: transport)
  }
}

private enum ConsumerRegion: String {
  case atlantic = "AT"
}

private struct TotalOnly: Decodable, Equatable, Sendable {
  var total: Int
}

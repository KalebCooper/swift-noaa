import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Office client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct OfficeClientTests {
  @Test("A cancelled office lookup sends nothing", arguments: [0, 1, 2, 3])
  func aCancelledOfficeLookupSendsNothing(operation: Int) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let task = Task {
      await #expect(throws: NWSError.self) {
        switch operation {
        case 0: _ = try await client.office(identifier: "EWX")
        case 1: _ = try await client.officeHeadlines(officeIdentifier: "EWX")
        case 2: _ = try await client.officeBriefing(officeIdentifier: "LWX")
        default:
          _ = try await client.officeHeadline(identifier: "a", officeIdentifier: "EWX")
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

  @Test("A consumer-defined office response decodes through a custom endpoint")
  func aConsumerDefinedOfficeResponseDecodesThroughACustomEndpoint() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/offices/EWX", with: .office)
    let client = makeClient(transport)
    let request = WeatherRequest(
      endpoint: try #require(Endpoint<OfficeContact>(accept: .jsonLD, path: "/offices/EWX")))
    let contact = try await client.value(for: request)
    #expect(contact == OfficeContact(email: "sr-ewx.webmaster@noaa.gov", faxNumber: ""))
    #expect(transport.requests.count == 1)
  }

  @Test("An empty headline identifier sends nothing")
  func anEmptyHeadlineIdentifierSendsNothing() async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      try await client.officeHeadline(identifier: "", officeIdentifier: "EWX")
    }
    guard case .invalidHeadlineIdentifier(let identifier) = failure else {
      Issue.record("Expected an invalid headline identifier, got \(String(describing: failure))")
      return
    }
    #expect(identifier.isEmpty)
    #expect(transport.requests.isEmpty)
  }

  @Test("An empty office identifier is reported before an empty headline identifier")
  func anEmptyOfficeIdentifierIsReportedBeforeAnEmptyHeadlineIdentifier() async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      try await client.officeHeadline(identifier: "", officeIdentifier: "")
    }
    guard case .invalidOfficeIdentifier(let identifier) = failure else {
      Issue.record("Expected an invalid office identifier, got \(String(describing: failure))")
      return
    }
    #expect(identifier.isEmpty)
    #expect(transport.requests.isEmpty)
  }

  @Test("An empty office identifier sends nothing", arguments: [0, 1, 2, 3])
  func anEmptyOfficeIdentifierSendsNothing(operation: Int) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      switch operation {
      case 0: _ = try await client.office(identifier: "")
      case 1: _ = try await client.officeHeadlines(officeIdentifier: "")
      case 2: _ = try await client.officeBriefing(officeIdentifier: "")
      default: _ = try await client.value(for: .officeBriefing(officeIdentifier: ""))
      }
    }
    guard case .invalidOfficeIdentifier(let identifier) = failure else {
      Issue.record("Expected an invalid office identifier, got \(String(describing: failure))")
      return
    }
    #expect(identifier.isEmpty)
    #expect(transport.requests.isEmpty)
  }

  @Test("An unknown office stays the service's problem")
  func anUnknownOfficeStaysTheServicesProblem() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/offices/XXX", status: .notFound, with: .problemDetail)
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      try await client.office(identifier: "XXX")
    }
    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.status == 404)
    #expect(transport.requests.map(\.request.path) == ["/offices/XXX"])
  }

  @Test("Headline access layers agree", arguments: [0, 1, 2])
  func headlineAccessLayersAgree(layer: Int) async throws {
    let path = "/offices/EWX/headlines/ab45482ca5f57ff412eb1320721d5ac9"
    let transport = MockTransport()
    try answer(transport, path: path, with: .officeHeadline)
    let client = makeClient(transport)
    let identifier = "ab45482ca5f57ff412eb1320721d5ac9"
    let result: OfficeHeadline =
      switch layer {
      case 0: try await client.officeHeadline(identifier: identifier, officeIdentifier: "EWX")
      case 1:
        try await client.value(
          for: .officeHeadline(identifier: identifier, officeIdentifier: "EWX"))
      default:
        try await client.send(
          try #require(
            Endpoint.officeHeadline(identifier: identifier, officeIdentifier: "EWX")))
      }
    #expect(
      result
        == (try JSONDecoder().decode(OfficeHeadline.self, from: Fixture.officeHeadline.data())))
    #expect(result.summary == nil)
    #expect(transport.requests.map(\.request.path) == [path])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/ld+json")
    #expect(transport.requests[0].request.headerFields[.userAgent] == "office-tests")
  }

  @Test("Headline list access layers agree", arguments: [0, 1, 2])
  func headlineListAccessLayersAgree(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/offices/EWX/headlines", with: .officeHeadlines)
    let client = makeClient(transport)
    let result: OfficeHeadlines =
      switch layer {
      case 0: try await client.officeHeadlines(officeIdentifier: "EWX")
      case 1: try await client.value(for: .officeHeadlines(officeIdentifier: "EWX"))
      default:
        try await client.send(try #require(Endpoint.officeHeadlines(officeIdentifier: "EWX")))
      }
    #expect(result.headlines.count == 2)
    #expect(
      result
        == (try JSONDecoder().decode(OfficeHeadlines.self, from: Fixture.officeHeadlines.data())))
    #expect(transport.requests.map(\.request.path) == ["/offices/EWX/headlines"])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/ld+json")
  }

  @Test("Office access layers agree", arguments: [0, 1, 2])
  func officeAccessLayersAgree(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/offices/EWX", with: .office)
    let client = makeClient(transport)
    let result: WeatherOffice =
      switch layer {
      case 0: try await client.office(identifier: "EWX")
      case 1: try await client.value(for: .office(identifier: "EWX"))
      default: try await client.send(try #require(Endpoint.office(identifier: "EWX")))
      }
    #expect(result == (try JSONDecoder().decode(WeatherOffice.self, from: Fixture.office.data())))
    #expect(result.faxNumber == "")
    #expect(transport.requests.map(\.request.path) == ["/offices/EWX"])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/ld+json")
    #expect(transport.requests[0].request.headerFields[.userAgent] == "office-tests")
  }

  @Test("An empty headline list answers without a second request")
  func anEmptyHeadlineListAnswersWithoutASecondRequest() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/offices/OUN/headlines", with: .officeHeadlinesEmpty)
    let client = makeClient(transport)
    let headlines = try await client.officeHeadlines(officeIdentifier: "OUN")
    #expect(headlines.headlines.isEmpty)
    #expect(transport.requests.map(\.request.path) == ["/offices/OUN/headlines"])
  }

  @Test("Office identifiers keep their case and stay one path segment")
  func officeIdentifiersKeepTheirCaseAndStayOnePathSegment() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/offices/ewx", with: .office)
    try answer(transport, path: "/offices/E%2FX/headlines", with: .officeHeadlinesEmpty)
    let client = makeClient(transport)
    _ = try await client.office(identifier: "ewx")
    _ = try await client.officeHeadlines(officeIdentifier: "E/X")
    #expect(
      transport.requests.map(\.request.path) == ["/offices/ewx", "/offices/E%2FX/headlines"])
  }

  @Test(
    "Office redirects cannot escape the API origin",
    arguments: [
      "https://example.com/offices/EWX", "http://api.weather.gov/offices/EWX",
      "https://user:password@api.weather.gov/offices/EWX",
      "https://api.weather.gov/offices/EWX#staff",
    ])
  func officeRedirectsCannotEscapeTheAPIOrigin(location: String) async throws {
    let transport = MockTransport()
    redirect(transport, from: "/offices/EWX", to: location)
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      try await client.office(identifier: "EWX")
    }
    guard case .invalidLink = failure else {
      Issue.record("Expected an invalid link, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.count == 1)
  }

  @Test(
    "Office redirects inside the API keep their headers",
    arguments: ["/offices/EWX/", "https://api.weather.gov/offices/EWX/"])
  func officeRedirectsInsideTheAPIKeepTheirHeaders(location: String) async throws {
    let transport = MockTransport()
    redirect(transport, from: "/offices/EWX", to: location)
    try answer(transport, path: "/offices/EWX/", with: .office)
    let client = makeClient(transport)
    let office = try await client.office(identifier: "EWX")
    #expect(office.id == "EWX")
    #expect(transport.requests.map(\.request.path) == ["/offices/EWX", "/offices/EWX/"])
    #expect(transport.requests.allSatisfy { $0.request.headerFields[.userAgent] == "office-tests" })
    #expect(
      transport.requests.allSatisfy { $0.request.headerFields[.accept] == "application/ld+json" })
  }

  @Test("The headline's editorial link is never requested")
  func theHeadlinesEditorialLinkIsNeverRequested() async throws {
    let transport = MockTransport()
    try answer(
      transport, path: "/offices/EWX/headlines/ab45482ca5f57ff412eb1320721d5ac9",
      with: .officeHeadline)
    let client = makeClient(transport)
    let headline = try await client.officeHeadline(
      identifier: "ab45482ca5f57ff412eb1320721d5ac9", officeIdentifier: "EWX")
    #expect(
      headline.link == "https://storymaps.arcgis.com/stories/c211dd9f2fb84c918f2c1e7753e76eb0")
    #expect(
      transport.requests.map(\.request.path)
        == ["/offices/EWX/headlines/ab45482ca5f57ff412eb1320721d5ac9"])
  }

  @Test("Briefing access layers agree", arguments: [0, 1])
  func briefingAccessLayersAgree(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/offices/LWX/briefing", with: .officeBriefing)
    let client = makeClient(transport)
    let result: OfficeBriefing? =
      switch layer {
      case 0: try await client.officeBriefing(officeIdentifier: "LWX")
      default: try await client.value(for: .officeBriefing(officeIdentifier: "LWX"))
      }
    let expected = try JSONDecoder().decode(
      OfficeBriefingResponse.self, from: Fixture.officeBriefing.data())
    #expect(result == expected.briefing)
    #expect(result?.title == "Click to view briefing")
    #expect(result?.id == "3913ad35-9342-46fb-b8ab-5f148277426c")
    #expect(result?.officeId == "LWX")
    #expect(transport.requests.map(\.request.path) == ["/offices/LWX/briefing"])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/ld+json")
    #expect(transport.requests[0].request.headerFields[.userAgent] == "office-tests")
  }

  @Test("A null briefing is nil after exactly one request", arguments: [0, 1])
  func aNullBriefingIsNilAfterExactlyOneRequest(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/offices/EWX/briefing", with: .officeBriefingAbsent)
    let client = makeClient(transport)
    let result: OfficeBriefing? =
      switch layer {
      case 0: try await client.officeBriefing(officeIdentifier: "EWX")
      default: try await client.value(for: .officeBriefing(officeIdentifier: "EWX"))
      }
    #expect(result == nil)
    #expect(transport.requests.map(\.request.path) == ["/offices/EWX/briefing"])
  }

  @Test("A stored briefing request executes without a type annotation")
  func aStoredBriefingRequestExecutesWithoutATypeAnnotation() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/offices/LWX/briefing", with: .officeBriefing)
    let client = makeClient(transport)
    let stored = WeatherRequest.officeBriefing(officeIdentifier: "LWX")
    let briefing = try await client.value(for: stored)
    #expect(briefing?.title == "Click to view briefing")
  }

  @Test("Sending the briefing endpoint returns the whole response", arguments: [0, 1])
  func sendingTheBriefingEndpointReturnsTheWholeResponse(recorded: Int) async throws {
    let fixture: Fixture = recorded == 0 ? .officeBriefing : .officeBriefingAbsent
    let office = recorded == 0 ? "LWX" : "EWX"
    let transport = MockTransport()
    try answer(transport, path: "/offices/\(office)/briefing", with: fixture)
    let client = makeClient(transport)
    let response = try await client.send(
      try #require(Endpoint.officeBriefing(officeIdentifier: office)))
    #expect(
      response == (try JSONDecoder().decode(OfficeBriefingResponse.self, from: fixture.data())))
    if recorded == 0 {
      #expect(response.briefing?.title == "Click to view briefing")
      #expect(response.briefing?.id == "3913ad35-9342-46fb-b8ab-5f148277426c")
      #expect(response.briefing?.officeId == "LWX")
    } else {
      #expect(response.briefing == nil)
    }
    #expect(transport.requests.count == 1)
  }

  @Test("An unknown office's briefing stays the service's problem")
  func anUnknownOfficesBriefingStaysTheServicesProblem() async throws {
    let transport = MockTransport()
    try answer(
      transport, path: "/offices/XXX/briefing", status: .notFound, with: .problemDetail)
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      try await client.officeBriefing(officeIdentifier: "XXX")
    }
    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.status == 404)
    #expect(transport.requests.map(\.request.path) == ["/offices/XXX/briefing"])
  }

  @Test("The briefing's download link is never requested")
  func theBriefingsDownloadLinkIsNeverRequested() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/offices/LWX/briefing", with: .officeBriefing)
    let client = makeClient(transport)
    let briefing = try await client.officeBriefing(officeIdentifier: "LWX")
    #expect(
      briefing?.download
        == URL(
          string:
            "https://api.weather.gov/offices/LWX/briefing/download/3913ad35-9342-46fb-b8ab-5f148277426c"
        ))
    #expect(transport.requests.map(\.request.path) == ["/offices/LWX/briefing"])
  }

  @Test("Briefing office identifiers keep their case and stay one path segment")
  func briefingOfficeIdentifiersKeepTheirCaseAndStayOnePathSegment() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/offices/lwx/briefing", with: .officeBriefingAbsent)
    try answer(transport, path: "/offices/L%2FX/briefing", with: .officeBriefingAbsent)
    let client = makeClient(transport)
    _ = try await client.officeBriefing(officeIdentifier: "lwx")
    _ = try await client.officeBriefing(officeIdentifier: "L/X")
    #expect(
      transport.requests.map(\.request.path)
        == ["/offices/lwx/briefing", "/offices/L%2FX/briefing"])
  }

  @Test(
    "Briefing redirects cannot escape the API origin",
    arguments: [
      "https://example.com/offices/LWX/briefing", "http://api.weather.gov/offices/LWX/briefing",
      "https://user:password@api.weather.gov/offices/LWX/briefing",
      "https://api.weather.gov/offices/LWX/briefing#latest",
    ])
  func briefingRedirectsCannotEscapeTheAPIOrigin(location: String) async throws {
    let transport = MockTransport()
    redirect(transport, from: "/offices/LWX/briefing", to: location)
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      try await client.officeBriefing(officeIdentifier: "LWX")
    }
    guard case .invalidLink = failure else {
      Issue.record("Expected an invalid link, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.count == 1)
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
    NWSClient(configuration: .init(userAgent: "office-tests"), transport: transport)
  }

  private func redirect(_ transport: MockTransport, from path: String, to location: String) {
    transport.setHandler(forPath: path) { _ in
      .success(
        MockTransport.Answer(Response(headers: [.location: location], status: .movedPermanently)))
    }
  }
}

private struct OfficeContact: Decodable, Equatable, Sendable {
  var email: String
  var faxNumber: String
}

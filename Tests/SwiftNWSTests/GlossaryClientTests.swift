import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Glossary client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct GlossaryClientTests {
  @Test("A cancelled glossary lookup sends nothing", arguments: [false, true])
  func aCancelledGlossaryLookupSendsNothing(useRequest: Bool) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let task = Task {
      await #expect(throws: NWSError.self) {
        if useRequest {
          _ = try await client.value(for: .glossary)
        } else {
          _ = try await client.glossary()
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

  @Test("A consumer-defined glossary response decodes through a custom endpoint")
  func aConsumerDefinedGlossaryResponseDecodesThroughACustomEndpoint() async throws {
    let transport = MockTransport()
    try answer(transport)
    let client = makeClient(transport)
    let request = WeatherRequest(
      endpoint: try #require(Endpoint<GlossarySize>(accept: .jsonLD, path: "/glossary")))
    let size = try await client.value(for: request)
    #expect(size.glossary.count == 3183)
    #expect(size.glossary.first == GlossarySize.Term(term: "1-2-3 Rule"))
    #expect(transport.requests.count == 1)
  }

  @Test("A glossary body that does not decode is a transport failure", arguments: [false, true])
  func aGlossaryBodyThatDoesNotDecodeIsATransportFailure(useRequest: Bool) async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/glossary") { _ in
      .success(MockTransport.Answer(Response(body: Data(#"{"@context":[]}"#.utf8), status: .ok)))
    }
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      try await (useRequest ? client.value(for: .glossary) : client.glossary())
    }
    guard case .transport(.decode) = failure else {
      Issue.record("Expected a decoding failure, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.count == 1)
  }

  @Test("A refused glossary request is thrown as the service's problem", arguments: [false, true])
  func aRefusedGlossaryRequestIsThrownAsTheServicesProblem(useRequest: Bool) async throws {
    let transport = MockTransport()
    try answer(transport, status: .notFound, with: .problemDetail)
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      try await (useRequest ? client.value(for: .glossary) : client.glossary())
    }
    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.status == 404)
    #expect(problem.title == "Data Unavailable For Requested Point")
    #expect(transport.requests.map(\.request.path) == ["/glossary"])
  }

  @Test("Glossary access layers agree", arguments: [0, 1, 2])
  func glossaryAccessLayersAgree(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport)
    let client = makeClient(transport)
    let result: WeatherGlossary =
      switch layer {
      case 0: try await client.glossary()
      case 1: try await client.value(for: .glossary)
      default: try await client.send(Endpoint.glossary)
      }
    #expect(
      result == (try JSONDecoder().decode(WeatherGlossary.self, from: Fixture.glossary.data())))
    #expect(transport.requests.map(\.request.path) == ["/glossary"])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/ld+json")
    #expect(transport.requests[0].request.headerFields[.userAgent] == "glossary-tests")
  }

  @Test(
    "Glossary redirects cannot escape the API origin",
    arguments: [
      "https://example.com/glossary", "http://api.weather.gov/glossary",
      "https://user:password@api.weather.gov/glossary", "https://api.weather.gov/glossary#terms",
    ])
  func glossaryRedirectsCannotEscapeTheAPIOrigin(location: String) async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/glossary") { _ in
      .success(
        MockTransport.Answer(Response(headers: [.location: location], status: .movedPermanently)))
    }
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) { try await client.glossary() }
    guard case .invalidLink = failure else { Issue.record("Expected invalid link"); return }
    #expect(transport.requests.count == 1)
  }

  @Test(
    "Glossary redirects inside the API keep their headers and decode the recording",
    arguments: ["/glossary/", "https://api.weather.gov/glossary/", "glossary/"])
  func glossaryRedirectsInsideTheAPIKeepTheirHeadersAndDecodeTheRecording(location: String)
    async throws
  {
    let transport = MockTransport()
    transport.setHandler(forPath: "/glossary") { _ in
      .success(
        MockTransport.Answer(Response(headers: [.location: location], status: .movedPermanently)))
    }
    try answer(transport, path: "/glossary/")
    let client = makeClient(transport)
    let glossary = try await client.glossary()
    #expect(glossary.entries.count == 3183)
    #expect(transport.requests.map(\.request.path) == ["/glossary", "/glossary/"])
    #expect(
      transport.requests.allSatisfy { $0.request.headerFields[.userAgent] == "glossary-tests" })
    #expect(
      transport.requests.allSatisfy { $0.request.headerFields[.accept] == "application/ld+json" })
  }

  @Test("Glossary requests send a bare path")
  func glossaryRequestsSendABarePath() async throws {
    let transport = MockTransport()
    try answer(transport)
    let client = makeClient(transport)
    _ = try await client.glossary()
    _ = try await client.value(for: .glossary)
    #expect(transport.requests.map(\.request.path) == ["/glossary", "/glossary"])
    #expect(transport.requests.allSatisfy { $0.request.path?.contains("?") == false })
  }

  private func answer(
    _ transport: MockTransport, path: String = "/glossary", status: HTTPResponse.Status = .ok,
    with fixture: Fixture = .glossary
  ) throws {
    let body = try fixture.data()
    transport.setHandler(forPath: path) { _ in
      .success(MockTransport.Answer(Response(body: body, status: status)))
    }
  }

  private func makeClient(_ transport: MockTransport) -> NWSClient {
    NWSClient(configuration: .init(userAgent: "glossary-tests"), transport: transport)
  }
}

private struct GlossarySize: Decodable, Equatable, Sendable {
  var glossary: [Term]

  struct Term: Decodable, Equatable, Sendable {
    var term: String
  }
}

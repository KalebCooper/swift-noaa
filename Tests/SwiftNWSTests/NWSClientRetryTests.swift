import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Retry policy", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct NWSClientRetryTests {
  private let configuration = NWSConfiguration(userAgent: "retry-tests")

  @Test("A cancelled wait sends nothing more and throws a transport cancellation")
  func aCancelledWaitSendsNothingMoreAndThrowsATransportCancellation() async throws {
    let clock = RecordingClock()
    let transport = MockTransport(answers: [problemAnswer(503)])
    let client = makeClient(transport, clock: clock)

    let task = Task { try await client.alertTypes() }
    await clock.waitForPendingSleep()
    task.cancel()
    let failure = await thrownError(by: task)

    guard case .transport(.cancelled) = failure else {
      Issue.record("Expected transport cancellation, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.count == 1)
  }

  @Test("A client-error problem is thrown after one attempt", arguments: [400, 404])
  func aClientErrorProblemIsThrownAfterOneAttempt(status: Int) async throws {
    let clock = RecordingClock()
    let transport = MockTransport(answers: [problemAnswer(status), try success()])
    let client = makeClient(transport, clock: clock)

    let failure = await #expect(throws: NWSError.self) { try await client.alertTypes() }

    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.status == status)
    #expect(transport.requests.count == 1)
    #expect(clock.sleeps.isEmpty)
  }

  @Test("A disabled policy sends a transient failure once")
  func aDisabledPolicySendsATransientFailureOnce() async throws {
    let clock = RecordingClock()
    let transport = MockTransport(answers: [problemAnswer(503), try success()])
    let client = NWSClient(
      clock: clock, configuration: configuration, transport: transport)

    let failure = await #expect(throws: NWSError.self) { try await client.alertTypes() }

    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.status == 503)
    #expect(transport.requests.count == 1)
    #expect(clock.sleeps.isEmpty)
  }

  @Test("A page that fails transiently is sent again and the sequence continues")
  func aPageThatFailsTransientlyIsSentAgainAndTheSequenceContinues() async throws {
    let clock = RecordingClock()
    let transport = MockTransport(answers: [
      try page(next: "https://api.weather.gov/stations?cursor=2"),
      problemAnswer(503),
      try page(),
    ])
    let client = makeClient(transport, clock: clock)
    let query = try ObservationStationQuery()

    let task = Task {
      var count = 0
      for try await _ in client.observationStationPages(matching: query) { count += 1 }
      return count
    }
    await clock.waitForPendingSleep()
    clock.advanceAll()
    let pages = try await task.value

    #expect(pages == 2)
    #expect(
      transport.requests.map(\.request.path) == [
        "/stations?limit=500", "/stations?cursor=2", "/stations?cursor=2",
      ])
    #expect(clock.sleeps == [.seconds(1)])
  }

  @Test("A redirect hop has its own attempt budget")
  func aRedirectHopHasItsOwnAttemptBudget() async throws {
    let clock = RecordingClock()
    let redirect = Response(
      headers: [.location: "/alerts/types?canonical=true"], status: .movedPermanently)
    let transport = MockTransport(answers: [
      problemAnswer(503), .success(MockTransport.Answer(redirect)), problemAnswer(503),
      try success(),
    ])
    let client = makeClient(transport, clock: clock)

    let task = Task { try await client.alertTypes() }
    await clock.waitForPendingSleep()
    clock.advanceAll()
    await clock.waitForPendingSleep()
    clock.advanceAll()
    let result = try await task.value

    #expect(result.eventTypes.count == 111)
    #expect(
      transport.requests.map(\.request.path) == [
        "/alerts/types", "/alerts/types", "/alerts/types?canonical=true",
        "/alerts/types?canonical=true",
      ])
    #expect(clock.sleeps == [.seconds(1), .seconds(1)])
  }

  @Test(
    "A retried status succeeds on the next attempt after one second",
    arguments: [429, 500, 502, 503, 504])
  func aRetriedStatusSucceedsOnTheNextAttemptAfterOneSecond(status: Int) async throws {
    let clock = RecordingClock()
    let transport = MockTransport(answers: [problemAnswer(status), try success()])
    let client = makeClient(transport, clock: clock)

    let task = Task { try await client.alertTypes() }
    await clock.waitForPendingSleep()
    clock.advanceAll()
    let result = try await task.value

    #expect(result.eventTypes.count == 111)
    #expect(transport.requests.count == 2)
    #expect(clock.sleeps == [.seconds(1)])
  }

  @Test("A timeout is sent again")
  func aTimeoutIsSentAgain() async throws {
    let clock = RecordingClock()
    let transport = MockTransport(answers: [
      .failure(.transport(kind: .timedOut, underlying: nil)), try success(),
    ])
    let client = makeClient(transport, clock: clock)

    let task = Task { try await client.alertTypes() }
    await clock.waitForPendingSleep()
    clock.advanceAll()
    let result = try await task.value

    #expect(result.eventTypes.count == 111)
    #expect(transport.requests.count == 2)
  }

  @Test("A two-second Retry-After replaces the scheduled one-second wait")
  func aTwoSecondRetryAfterReplacesTheScheduledOneSecondWait() async throws {
    let clock = RecordingClock()
    let transport = MockTransport(answers: [
      problemAnswer(503, headers: [.retryAfter: "2"]), try success(),
    ])
    let client = makeClient(transport, clock: clock)

    let task = Task { try await client.alertTypes() }
    await clock.waitForPendingSleep()
    clock.advanceAll()
    _ = try await task.value

    #expect(clock.sleeps == [.seconds(2)])
  }

  @Test("The last attempt's problem is thrown after three attempts")
  func theLastAttemptsProblemIsThrownAfterThreeAttempts() async throws {
    let clock = RecordingClock()
    let transport = MockTransport(answers: [
      problemAnswer(503), problemAnswer(503), problemAnswer(503), try success(),
    ])
    let client = makeClient(transport, clock: clock)

    let task = Task { try await client.alertTypes() }
    await clock.waitForPendingSleep()
    clock.advanceAll()
    await clock.waitForPendingSleep()
    clock.advanceAll()
    let failure = await thrownError(by: task)

    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.title == "Service Unavailable")
    #expect(transport.requests.count == 3)
    #expect(clock.sleeps == [.seconds(1), .seconds(5)])
  }

  @Test("Two transient failures wait one second and then five")
  func twoTransientFailuresWaitOneSecondAndThenFive() async throws {
    let clock = RecordingClock()
    let transport = MockTransport(answers: [problemAnswer(503), problemAnswer(503), try success()])
    let client = makeClient(transport, clock: clock)

    let task = Task { try await client.alertTypes() }
    await clock.waitForPendingSleep()
    clock.advanceAll()
    await clock.waitForPendingSleep()
    clock.advanceAll()
    let result = try await task.value

    #expect(result.eventTypes.count == 111)
    #expect(transport.requests.count == 3)
    #expect(clock.sleeps == [.seconds(1), .seconds(5)])
  }

  #if canImport(Darwin)
  @Test("The session initializer retries through its session")
  func theSessionInitializerRetriesThroughItsSession() async throws {
    let clock = RecordingClock()
    let script = StubURLProtocol.Script(answers: [
      .response(
        body: Self.problem(status: 503), headers: ["Content-Type": "application/problem+json"],
        status: 503),
      .response(
        body: try Fixture.alertTypes.data(), headers: ["Content-Type": "application/ld+json"],
        status: 200),
    ])
    let client = NWSClient(
      clock: clock, configuration: configuration, retryPolicy: .nwsTransientFailures,
      session: URLSession(configuration: script.makeSessionConfiguration()))

    let task = Task { try await client.alertTypes() }
    await clock.waitForPendingSleep()
    clock.advanceAll()
    let result = try await task.value

    #expect(result.eventTypes.count == 111)
    #expect(script.requests.count == 2)
    #expect(clock.sleeps == [.seconds(1)])
  }
  #endif

  // A literal problem document in the shape the service sends; not a live recording.
  private static func problem(status: Int) -> Data {
    let title = status == 503 ? "Service Unavailable" : "Request Refused"
    return Data(
      """
      {"correlationId":"0","detail":"Literal test body.","instance":"https://api.weather.gov/requests/0",\
      "status":\(status),"title":"\(title)","type":"https://api.weather.gov/problems/Test"}
      """.utf8)
  }

  private func problemAnswer(
    _ status: Int, headers: HTTPFields = [:]
  ) -> Result<MockTransport.Answer, TransportError> {
    var fields = headers
    fields[.contentType] = "application/problem+json"
    let response = Response(
      body: Self.problem(status: status), headers: fields,
      status: HTTPResponse.Status(code: status))
    return .success(MockTransport.Answer(response))
  }

  private func makeClient(_ transport: MockTransport, clock: RecordingClock) -> NWSClient {
    NWSClient(
      clock: clock, configuration: configuration, retryPolicy: .nwsTransientFailures,
      transport: transport)
  }

  // Variants derive from the recorded station collection; they are not live response captures.
  private func page(next: String? = nil) throws -> Result<MockTransport.Answer, TransportError> {
    var page = try JSONDecoder().decode(
      FeatureCollection<ObservationStation>.self, from: Fixture.observationStations.data())
    page.pagination = next.map { PaginationInfo(next: $0) }
    let body = try JSONEncoder().encode(page)
    return .success(MockTransport.Answer(Response(body: body, status: .ok)))
  }

  private func thrownError<Success>(by task: Task<Success, any Error>) async -> NWSError? {
    guard case .failure(let error) = await task.result else { return nil }
    return error as? NWSError
  }

  private func success() throws -> Result<MockTransport.Answer, TransportError> {
    .success(MockTransport.Answer(Response(body: try Fixture.alertTypes.data(), status: .ok)))
  }
}

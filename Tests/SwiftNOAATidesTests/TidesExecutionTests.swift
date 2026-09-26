import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Synchronization
import Testing

@Suite("Tides execution budgets", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct TidesExecutionTests {
  @Test("Application identification can be omitted independently of User Agent")
  func applicationIdentificationCanBeOmittedIndependentlyOfUserAgent() async throws {
    let transport = MockTransport(answers: [
      .success(MockTransport.Answer(Response(body: Data("1".utf8), status: .ok)))
    ])
    let client = TidesClient(
      configuration: .init(application: nil, userAgent: "consumer"), transport: transport)
    #expect(
      try await client.send(
        #require(TidesEndpoint<Int>(path: "/api/prod/datagetter?product=custom"))) == 1)
    #expect(transport.requests.first?.request.path == "/api/prod/datagetter?product=custom")
    #expect(transport.requests.first?.request.headerFields[.userAgent] == "consumer")
  }

  @Test("Cancellation from a retry wait prevents another attempt")
  func cancellationFromARetryWaitPreventsAnotherAttempt() async throws {
    let clock = ImmediateTidesClock(cancelSleep: true)
    let transport = MockTransport(answers: [
      .success(MockTransport.Answer(Response(status: .serviceUnavailable)))
    ])
    let client = TidesClient(clock: clock, retryPolicy: Self.policy, transport: transport)
    let error = await #expect(throws: TidesError.self) {
      try await client.send(#require(TidesEndpoint<Int>(path: "/test")))
    }
    guard case .transport(.cancelled) = error else { Issue.record("Expected cancellation"); return }
    #expect(transport.requests.count == 1)
    #expect(clock.sleeps == [.seconds(1)])
  }

  @Test("Default retries remain disabled for transient failures")
  func defaultRetriesRemainDisabledForTransientFailures() async throws {
    let clock = ImmediateTidesClock()
    let transport = MockTransport(answers: [
      .success(MockTransport.Answer(Response(status: .serviceUnavailable)))
    ])
    let error = await #expect(throws: TidesError.self) {
      try await TidesClient(clock: clock, transport: transport).send(
        #require(TidesEndpoint<Int>(path: "/test")))
    }
    guard case .httpStatus(_, 503) = error else { Issue.record("Expected HTTP failure"); return }
    #expect(transport.requests.count == 1)
    #expect(clock.sleeps.isEmpty)
  }

  @Test("Each of six redirect hops has its own bounded retry budget")
  func eachOfSixRedirectHopsHasItsOwnBoundedRetryBudget() async throws {
    let clock = ImmediateTidesClock()
    let transport = MockTransport()
    for hop in 0...5 {
      let calls = Mutex(0)
      transport.setHandler(forPath: "/hop/\(hop)") { _ in
        let attempt = calls.withLock { value in
          value += 1; return value
        }
        if attempt == 1 {
          return .success(MockTransport.Answer(Response(status: .serviceUnavailable)))
        }
        if hop < 5 {
          return .success(
            MockTransport.Answer(Response(headers: [.location: "/hop/\(hop + 1)"], status: .found)))
        }
        return .success(MockTransport.Answer(Response(body: Data("7".utf8), status: .ok)))
      }
    }
    let value = try await TidesClient(clock: clock, retryPolicy: Self.policy, transport: transport)
      .send(#require(TidesEndpoint<Int>(path: "/hop/0")))
    #expect(value == 7)
    #expect(transport.requests.count == 12)
    #expect(
      transport.requests.map(\.request.path) == [
        "/hop/0", "/hop/0", "/hop/1", "/hop/1", "/hop/2", "/hop/2", "/hop/3", "/hop/3", "/hop/4",
        "/hop/4", "/hop/5", "/hop/5",
      ])
    #expect(clock.sleeps == Array(repeating: .seconds(1), count: 6))
  }

  @Test("Redirect chains stop after six sends without following a seventh hop")
  func redirectChainsStopAfterSixSendsWithoutFollowingASeventhHop() async throws {
    let transport = MockTransport()
    for hop in 0...6 {
      transport.setHandler(forPath: "/hop/\(hop)") { _ in
        .success(
          MockTransport.Answer(Response(headers: [.location: "/hop/\(hop + 1)"], status: .found)))
      }
    }
    let error = await #expect(throws: TidesError.self) {
      try await TidesClient(transport: transport).send(#require(TidesEndpoint<Int>(path: "/hop/0")))
    }
    guard case .tooManyRedirects = error else { Issue.record("Expected bounded redirects"); return }
    #expect(transport.requests.count == 6)
    #expect(transport.requests.last?.request.path == "/hop/5")
  }

  private static let policy = RetryPolicy(
    backoff: BackoffSchedule(delays: [.seconds(1)]), maxAttempts: 2,
    retryable: { $0.failure.statusCode == 503 })
}

private final class ImmediateTidesClock: Clock {
  let cancelSleep: Bool
  let minimumResolution: Duration = .nanoseconds(1)
  let now = ContinuousClock().now
  var sleeps: [Duration] { storage.withLock { $0 } }

  private let storage = Mutex<[Duration]>([])

  init(cancelSleep: Bool = false) { self.cancelSleep = cancelSleep }

  func sleep(until deadline: ContinuousClock.Instant, tolerance: Duration?) async throws {
    storage.withLock { $0.append(now.duration(to: deadline)) }
    if cancelSleep { throw CancellationError() }
    try Task.checkCancellation()
  }
}

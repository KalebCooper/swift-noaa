import Foundation
import HTTPCore
import HTTPTesting
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Iterator isolation", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct IteratorIsolationTests {
  private actor Consumer {
    func consume() async throws {
      try await IteratorIsolationTests().checkAllSequences(isolation: self)
    }
  }

  @Test("All sequence views can be consumed from a custom actor")
  func allSequenceViewsCanBeConsumedFromACustomActor() async throws {
    try await Consumer().consume()
  }

  @Test("All sequence views can be consumed from MainActor")
  @MainActor
  func allSequenceViewsCanBeConsumedFromMainActor() async throws {
    try await checkAllSequences(isolation: MainActor.shared)
  }

  @Test("All sequence views can be consumed without actor isolation")
  nonisolated func allSequenceViewsCanBeConsumedWithoutActorIsolation() async throws {
    try await checkAllSequences(isolation: nil)
  }

  @Test("Explicit isolation survives a redirect and buffered feature reads")
  @MainActor
  func explicitIsolationSurvivesARedirectAndBufferedFeatureReads() async throws {
    let transport = MockTransport()
    transport.enqueue(
      .success(.init(Response(body: Data(), headers: [.location: "/canonical"], status: .found))))
    let body = try Fixture.observationStations.data()
    transport.enqueue(.success(.init(Response(body: body, status: .ok))))
    let client = NWSClient(configuration: .init(userAgent: "tests"), transport: transport)
    var iterator = client.observationStations(matching: try ObservationStationQuery())
      .makeAsyncIterator()
    #expect(try await iterator.next(isolation: MainActor.shared) != nil)
    #expect(try await iterator.next(isolation: MainActor.shared) != nil)
    #expect(transport.requests.map(\.request.path) == ["/stations?limit=500", "/canonical"])
  }

  private func check<S: AsyncSequence>(
    _ sequence: S, count: Int, isolation actor: isolated (any Actor)?
  ) async throws {
    var iterator = sequence.makeAsyncIterator()
    var explicitCount = 0
    while try await iterator.next(isolation: actor) != nil { explicitCount += 1 }
    #expect(explicitCount == count)
    var loopCount = 0
    for try await _ in sequence { loopCount += 1 }
    #expect(loopCount == count)
  }

  private func checkAllSequences(isolation actor: isolated (any Actor)?) async throws {
    let transport = MockTransport()
    let client = NWSClient(configuration: .init(userAgent: "tests"), transport: transport)
    let alerts = try prepare(transport, fixture: .activeAlerts, as: WeatherAlert.self)
    try await check(client.activeAlertPages(), count: 1, isolation: actor)
    try await check(client.activeAlerts(), count: alerts, isolation: actor)
    let history = try prepare(transport, fixture: .alertHistory, as: WeatherAlert.self)
    let alertQuery = try AlertQuery()
    try await check(client.alertPages(matching: alertQuery), count: 1, isolation: actor)
    try await check(client.alerts(matching: alertQuery), count: history, isolation: actor)
    let observations = try prepare(
      transport, fixture: .observationHistory, as: WeatherObservation.self)
    let observationQuery = try ObservationQuery(stationIdentifier: "KATT")
    try await check(client.observationPages(matching: observationQuery), count: 1, isolation: actor)
    try await check(
      client.observations(matching: observationQuery), count: observations, isolation: actor)
    let stations = try prepare(
      transport, fixture: .observationStations, as: ObservationStation.self)
    let stationQuery = try ObservationStationQuery()
    try await check(
      client.observationStationPages(matching: stationQuery), count: 1, isolation: actor)
    try await check(
      client.observationStations(matching: stationQuery), count: stations, isolation: actor)
    #expect(transport.requests.count == 16)
  }

  private func prepare<P: Codable & Sendable>(
    _ transport: MockTransport, fixture: Fixture, as type: P.Type
  ) throws -> Int {
    var page = try JSONDecoder().decode(FeatureCollection<P>.self, from: fixture.data())
    page.pagination = nil
    let body = try JSONEncoder().encode(page)
    for _ in 0..<4 { transport.enqueue(.success(.init(Response(body: body, status: .ok)))) }
    return page.features.count
  }
}

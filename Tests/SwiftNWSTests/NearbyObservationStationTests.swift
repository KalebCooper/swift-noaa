import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Nearby observation stations", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct NearbyObservationStationTests {
  private static let pointPath = "/points/30.2672,-97.7431"
  private static let stationsPath = "/gridpoints/EWX/156,91/stations"

  @Test(
    "A nearby station lookup returns one page and never follows its next link",
    arguments: [false, true])
  func aNearbyStationLookupReturnsOnePageAndNeverFollowsItsNextLink(useRequest: Bool)
    async throws
  {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let location = try home()
    let page =
      useRequest
      ? try await client.value(for: .observationStations(near: location))
      : try await client.observationStations(near: location)
    // The recorded page carries a continuation link.
    #expect(page.pagination?.next != nil)
    #expect(page == (try recorded()))
    #expect(transport.requests.map(\.request.path) == [Self.pointPath, Self.stationsPath])
    #expect(
      transport.requests.allSatisfy {
        $0.request.headerFields[.accept] == "application/geo+json"
          && $0.request.headerFields[.userAgent] == "(example.com, contact@example.com)"
      })
  }

  @Test("Nearby station sequences send nothing until iterated")
  func nearbyStationSequencesSendNothingUntilIterated() throws {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let request = WeatherRequest.observationStations(near: try home())
    let pages = client.observationStationPages(for: request)
    let stations = client.observationStations(for: request)
    _ = pages.makeAsyncIterator()
    _ = stations.makeAsyncIterator()
    #expect(transport.requests.isEmpty)
  }

  @Test("Nearby station page sequences yield one page and then finish")
  func nearbyStationPageSequencesYieldOnePageAndThenFinish() async throws {
    let transport = try preparedTransport()
    var iterator = makeClient(transport).observationStationPages(
      for: .observationStations(near: try home())
    ).makeAsyncIterator()
    #expect(try await iterator.next() == (try recorded()))
    #expect(try await iterator.next() == nil)
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.map(\.request.path) == [Self.pointPath, Self.stationsPath])
  }

  @Test(
    "Nearby station item sequences yield every station on the page in service order and then finish"
  )
  func nearbyStationItemSequencesYieldEveryStationOnThePageInServiceOrderAndThenFinish()
    async throws
  {
    let transport = try preparedTransport()
    var identifiers: [String] = []
    for try await station in makeClient(transport).observationStations(
      for: .observationStations(near: try home()))
    {
      identifiers.append(station.properties.stationIdentifier)
    }
    let expected = try recorded().features.map(\.properties.stationIdentifier)
    #expect(identifiers == expected)
    #expect(identifiers.count == 64)
    #expect(transport.requests.map(\.request.path) == [Self.pointPath, Self.stationsPath])
  }

  @Test("Each nearby station iterator starts its own lookup")
  func eachNearbyStationIteratorStartsItsOwnLookup() async throws {
    let transport = try preparedTransport()
    let client = NWSClient(
      configuration: .init(userAgent: "(example.com, contact@example.com)"), pointCache: nil,
      transport: transport)
    let sequence = client.observationStationPages(for: .observationStations(near: try home()))
    var first = sequence.makeAsyncIterator()
    var second = sequence.makeAsyncIterator()
    #expect(try await first.next() == second.next())
    #expect(
      transport.requests.map(\.request.path) == [
        Self.pointPath, Self.stationsPath, Self.pointPath, Self.stationsPath,
      ])
  }

  @Test("Cancellation before a nearby station page sends nothing")
  @MainActor
  func cancellationBeforeANearbyStationPageSendsNothing() async throws {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let location = try home()
    let task = Task { () throws -> NWSError? in
      var iterator = client.observationStationPages(for: .observationStations(near: location))
        .makeAsyncIterator()
      let error = await #expect(throws: NWSError.self) { try await iterator.next() }
      #expect(try await iterator.next() == nil)
      return error
    }
    // The inherited main actor keeps the task from starting before cancellation.
    task.cancel()
    guard case .transport(.cancelled) = try await task.value else {
      Issue.record("Expected cancellation")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Cancellation after the point prevents the station request", arguments: [false, true])
  func cancellationAfterThePointPreventsTheStationRequest(sequence: Bool) async throws {
    let transport = MockTransport()
    let body = try Fixture.point.data()
    transport.setHandler(forPath: Self.pointPath) { _ in
      unsafe withUnsafeCurrentTask { unsafe $0?.cancel() }
      return .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = makeClient(transport)
    let location = try home()
    let work = Task {
      await #expect(throws: NWSError.self) {
        if sequence {
          var iterator = client.observationStationPages(for: .observationStations(near: location))
            .makeAsyncIterator()
          _ = try await iterator.next()
        } else {
          _ = try await client.observationStations(near: location)
        }
      }
    }
    guard case .transport(.cancelled) = await work.value else {
      Issue.record("Expected cancellation")
      return
    }
    #expect(transport.requests.map(\.request.path) == [Self.pointPath])
  }

  @Test(
    "A disallowed station link ends the nearby sequence with an invalid link error",
    arguments: [false, true])
  func aDisallowedStationLinkEndsTheNearbySequenceWithAnInvalidLinkError(useValue: Bool)
    async throws
  {
    let transport = MockTransport()
    var point = try JSONDecoder().decode(Feature<WeatherPoint>.self, from: Fixture.point.data())
    let link = try #require(URL(string: "https://example.com/gridpoints/EWX/156,91/stations"))
    point.properties.observationStations = link
    let body = try JSONEncoder().encode(point)
    transport.setHandler(forPath: Self.pointPath) { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
    let client = makeClient(transport)
    let request = WeatherRequest.observationStations(near: try home())
    var iterator = client.observationStations(for: request).makeAsyncIterator()
    let failure = await #expect(throws: NWSError.self) {
      if useValue {
        _ = try await client.value(for: request)
      } else {
        _ = try await iterator.next()
      }
    }
    guard case .invalidLink(let actual) = failure else {
      Issue.record("Expected an invalid link, got \(String(describing: failure))")
      return
    }
    #expect(actual == link)
    if !useValue {
      #expect(try await iterator.next() == nil)
    }
    #expect(transport.requests.map(\.request.path) == [Self.pointPath])
  }

  @Test("Nearby stations reuse a cached point")
  func nearbyStationsReuseACachedPoint() async throws {
    let transport = try preparedTransport()
    try answer(transport, path: "/gridpoints/EWX/156,91", with: .forecastGrid)
    let client = makeClient(transport)
    let location = try home()
    _ = try await client.forecastGrid(for: location)
    _ = try await client.observationStations(near: location)
    for try await _ in client.observationStationPages(for: .observationStations(near: location)) {}
    #expect(
      transport.requests.map(\.request.path) == [
        Self.pointPath, "/gridpoints/EWX/156,91", Self.stationsPath, Self.stationsPath,
      ])
  }

  @Test("Nearby station factories infer their response without sending")
  func nearbyStationFactoriesInferTheirResponseWithoutSending() throws {
    let location = try home()
    let stored = WeatherRequest.observationStations(near: location)
    guard case .nearbyObservationStations(let actual) = stored.resolution else {
      Issue.record("Expected a nearby-station resolution")
      return
    }
    #expect(actual == location)
    #expect(stored == .observationStations(near: location))
    #expect(stored != .observationStations(matching: try ObservationStationQuery()))
  }

  private func callSites(_ client: NWSClient, location: WeatherCoordinate) async throws {
    let _: FeatureCollection<ObservationStation> = try await client.observationStations(
      near: location)
    let _: FeatureCollection<ObservationStation> = try await client.value(
      for: .observationStations(near: location))
    let _: FeatureCollection<ObservationStation> = try await client.value(for: .austinStations)
    for try await station in client.observationStations(for: .observationStations(near: location)) {
      let _: ObservationStation = station.properties
    }
  }

  private func answer(_ transport: MockTransport, path: String, with fixture: Fixture) throws {
    let body = try fixture.data()
    transport.setHandler(forPath: path) { _ in
      .success(MockTransport.Answer(Response(body: body, status: .ok)))
    }
  }

  private func home() throws -> WeatherCoordinate {
    try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
  }

  private func makeClient(_ transport: MockTransport) -> NWSClient {
    NWSClient(
      configuration: .init(userAgent: "(example.com, contact@example.com)"), transport: transport)
  }

  private func preparedTransport() throws -> MockTransport {
    let transport = MockTransport()
    try answer(transport, path: Self.pointPath, with: .point)
    try answer(transport, path: Self.stationsPath, with: .observationStations)
    return transport
  }

  private func recorded() throws -> FeatureCollection<ObservationStation> {
    try JSONDecoder().decode(
      FeatureCollection<ObservationStation>.self, from: Fixture.observationStations.data())
  }
}

extension WeatherRequest where Response == FeatureCollection<ObservationStation> {
  fileprivate static var austinStations: Self {
    get throws {
      .observationStations(near: try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431))
    }
  }
}

import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Forecast zone stations", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ForecastZoneStationTests {
  private static let observationsPath = "/zones/forecast/TXZ192/observations?limit=2"
  private static let stationsPath = "/zones/forecast/TXZ192/stations"

  @Test(
    "A forecast zone station lookup returns one page and never follows its next link",
    arguments: [0, 1, 2])
  func aForecastZoneStationLookupReturnsOnePageAndNeverFollowsItsNextLink(layer: Int)
    async throws
  {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let page =
      switch layer {
      case 0: try await client.observationStations(inForecastZone: "TXZ192")
      case 1: try await client.value(for: .observationStations(inForecastZone: "TXZ192"))
      default:
        try await client.send(
          try #require(Endpoint.observationStations(inForecastZone: "TXZ192")))
      }
    // The recorded page carries a continuation link that leads only to empty pages.
    #expect(page.pagination?.next != nil)
    #expect(page == (try recorded()))
    #expect(page.features.count == 24)
    #expect(transport.requests.map(\.request.path) == [Self.stationsPath])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/geo+json")
    #expect(transport.requests[0].request.headerFields[.userAgent] == "zone-station-tests")
    let flags = try #require(HTTPField.Name("Feature-Flags"))
    #expect(transport.requests[0].request.headerFields[flags] == nil)
  }

  @Test("Forecast zone station sequences send nothing until iterated")
  func forecastZoneStationSequencesSendNothingUntilIterated() throws {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let request = WeatherRequest.observationStations(inForecastZone: "TXZ192")
    let pages = client.observationStationPages(for: request)
    let stations = client.observationStations(for: request)
    _ = pages.makeAsyncIterator()
    _ = stations.makeAsyncIterator()
    #expect(transport.requests.isEmpty)
  }

  @Test("Forecast zone station page sequences yield one page and then finish")
  func forecastZoneStationPageSequencesYieldOnePageAndThenFinish() async throws {
    let transport = try preparedTransport()
    var iterator = makeClient(transport).observationStationPages(
      for: .observationStations(inForecastZone: "TXZ192")
    ).makeAsyncIterator()
    #expect(try await iterator.next() == (try recorded()))
    #expect(try await iterator.next() == nil)
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.map(\.request.path) == [Self.stationsPath])
  }

  @Test("Forecast zone station item sequences yield every station in order and then finish")
  func forecastZoneStationItemSequencesYieldEveryStationInOrderAndThenFinish() async throws {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    var identifiers: [String] = []
    for try await station in client.observationStations(
      for: .observationStations(inForecastZone: "TXZ192"))
    {
      identifiers.append(station.properties.stationIdentifier)
    }
    #expect(identifiers == (try recorded()).features.map(\.properties.stationIdentifier))
    #expect(identifiers.count == 24)
    #expect(transport.requests.map(\.request.path) == [Self.stationsPath])
  }

  @Test("Each forecast zone station iterator starts its own request")
  func eachForecastZoneStationIteratorStartsItsOwnRequest() async throws {
    let transport = try preparedTransport()
    let sequence = makeClient(transport).observationStationPages(
      for: .observationStations(inForecastZone: "TXZ192"))
    var first = sequence.makeAsyncIterator()
    var second = sequence.makeAsyncIterator()
    #expect(try await first.next() == second.next())
    #expect(transport.requests.map(\.request.path) == [Self.stationsPath, Self.stationsPath])
  }

  @Test(
    "An empty zone identifier fails on the first read without sending", arguments: [false, true])
  func anEmptyZoneIdentifierFailsOnTheFirstReadWithoutSending(items: Bool) async throws {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let request = WeatherRequest.observationStations(inForecastZone: "")
    let failure: NWSError?
    if items {
      var iterator = client.observationStations(for: request).makeAsyncIterator()
      failure = await #expect(throws: NWSError.self) { try await iterator.next() }
      #expect(try await iterator.next() == nil)
    } else {
      var iterator = client.observationStationPages(for: request).makeAsyncIterator()
      failure = await #expect(throws: NWSError.self) { try await iterator.next() }
      #expect(try await iterator.next() == nil)
    }
    guard case .invalidZoneIdentifier("") = failure else {
      Issue.record("Expected an invalid identifier, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test(
    "An empty zone identifier is rejected before a single-response station lookup",
    arguments: [false, true])
  func anEmptyZoneIdentifierIsRejectedBeforeASingleResponseStationLookup(useRequest: Bool)
    async throws
  {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      if useRequest {
        _ = try await client.value(for: .observationStations(inForecastZone: ""))
      } else {
        _ = try await client.observationStations(inForecastZone: "")
      }
    }
    guard case .invalidZoneIdentifier("") = failure else {
      Issue.record("Expected an invalid identifier, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Cancellation before a forecast zone station page sends nothing", arguments: [false, true])
  @MainActor
  func cancellationBeforeAForecastZoneStationPageSendsNothing(items: Bool) async throws {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let task = Task { () throws -> NWSError? in
      // An empty identifier proves cancellation is checked before validation.
      let request = WeatherRequest.observationStations(inForecastZone: "")
      // The item sequence checks cancellation itself, so only the pages arm proves that order.
      if items {
        var iterator = client.observationStations(for: request).makeAsyncIterator()
        let error = await #expect(throws: NWSError.self) { try await iterator.next() }
        #expect(try await iterator.next() == nil)
        return error
      } else {
        var iterator = client.observationStationPages(for: request).makeAsyncIterator()
        let error = await #expect(throws: NWSError.self) { try await iterator.next() }
        #expect(try await iterator.next() == nil)
        return error
      }
    }
    // The inherited main actor keeps the task from starting before cancellation.
    task.cancel()
    guard case .transport(.cancelled) = try await task.value else {
      Issue.record("Expected cancellation")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("Cancellation between buffered station reads ends the item iterator")
  func cancellationBetweenBufferedStationReadsEndsTheItemIterator() async throws {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let started = AsyncStream<Void>.makeStream()
    let resume = AsyncStream<Void>.makeStream()
    let task = Task {
      defer { started.continuation.finish() }
      var iterator = client.observationStations(
        for: .observationStations(inForecastZone: "TXZ192")
      ).makeAsyncIterator()
      _ = try await iterator.next()
      started.continuation.yield()
      for await _ in resume.stream {}
      let error = await #expect(throws: NWSError.self) { try await iterator.next() }
      #expect(try await iterator.next() == nil)
      return error
    }
    for await _ in started.stream { break }
    task.cancel()
    resume.continuation.finish()
    guard case .transport(.cancelled) = try await task.value else {
      Issue.record("Expected cancellation")
      return
    }
    #expect(transport.requests.map(\.request.path) == [Self.stationsPath])
  }

  @Test(
    "A zone observation request yields one page through the observation sequences",
    arguments: [false, true])
  func aZoneObservationRequestYieldsOnePageThroughTheObservationSequences(items: Bool)
    async throws
  {
    let transport = try preparedTransport()
    let client = makeClient(transport)
    let request = WeatherRequest.observations(
      inForecastZone: try ZoneObservationQuery(limit: 2, zoneIdentifier: "TXZ192"))
    let recorded = try JSONDecoder().decode(
      FeatureCollection<WeatherObservation>.self, from: Fixture.zoneObservations.data())
    if items {
      var stations: [URL?] = []
      for try await observation in client.observations(for: request) {
        stations.append(observation.properties.station)
      }
      #expect(stations == recorded.features.map(\.properties.station))
    } else {
      var iterator = client.observationPages(for: request).makeAsyncIterator()
      #expect(try await iterator.next() == recorded)
      #expect(try await iterator.next() == nil)
    }
    #expect(transport.requests.map(\.request.path) == [Self.observationsPath])
  }

  @Test("A forecast zone station request problem ends the sequence with its details")
  func aForecastZoneStationRequestProblemEndsTheSequenceWithItsDetails() async throws {
    let transport = MockTransport()
    let body = try Fixture.unknownRegionProblem.data()
    transport.setHandler(forPath: Self.stationsPath) { _ in
      .success(MockTransport.Answer(Response(body: body, status: .notFound)))
    }
    var iterator = makeClient(transport).observationStations(
      for: .observationStations(inForecastZone: "TXZ192")
    ).makeAsyncIterator()
    let failure = await #expect(throws: NWSError.self) { try await iterator.next() }
    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.status == 404)
    #expect(try await iterator.next() == nil)
    #expect(transport.requests.map(\.request.path) == [Self.stationsPath])
  }

  private func makeClient(_ transport: MockTransport) -> NWSClient {
    NWSClient(configuration: .init(userAgent: "zone-station-tests"), transport: transport)
  }

  private func preparedTransport() throws -> MockTransport {
    let transport = MockTransport()
    let stations = try Fixture.zoneStations.data()
    transport.setHandler(forPath: Self.stationsPath) { _ in
      .success(MockTransport.Answer(Response(body: stations, status: .ok)))
    }
    let observations = try Fixture.zoneObservations.data()
    // The mock transport matches a handler on the path without its query.
    transport.setHandler(forPath: "/zones/forecast/TXZ192/observations") { _ in
      .success(MockTransport.Answer(Response(body: observations, status: .ok)))
    }
    // A followed continuation would reach one of these paths; neither answers.
    return transport
  }

  private func recorded() throws -> FeatureCollection<ObservationStation> {
    try JSONDecoder().decode(
      FeatureCollection<ObservationStation>.self, from: Fixture.zoneStations.data())
  }
}

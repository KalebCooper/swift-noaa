import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Zone client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ZoneClientTests {
  private static let continuation = "https://api.weather.gov/zones?area=TX&limit=2&cursor=cGFnZQ"
  private static let detailPath = "/zones/forecast/TXZ192"
  private static let rootPath = "/zones?area=TX&limit=2"
  private static let typedPath = "/zones/forecast?area=TX&limit=2"

  private let texas = try! ZoneQuery(areas: [.texas], limit: 2)

  @Test("A cancelled lookup sends nothing", arguments: [0, 1, 2], [false, true])
  @MainActor
  func aCancelledLookupSendsNothing(operation: Int, useRequest: Bool) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let query = texas
    let task = Task {
      await #expect(throws: NWSError.self) {
        switch (operation, useRequest) {
        case (0, true):
          _ = try await client.value(for: .zone(identifier: "TXZ192", type: .forecast))
        case (0, false): _ = try await client.zone(identifier: "TXZ192", type: .forecast)
        case (1, true): _ = try await client.value(for: .zones(matching: query, ofType: .forecast))
        case (1, false): _ = try await client.zones(matching: query, ofType: .forecast)
        case (_, true): _ = try await client.value(for: .zones(matching: query))
        case (_, false): _ = try await client.zones(matching: query)
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

  @Test(
    "Zone detail access layers agree and send GeoJSON without feature flags",
    arguments: [0, 1, 2, 3])
  func zoneDetailAccessLayersAgreeAndSendGeoJSONWithoutFeatureFlags(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: Self.detailPath, with: .zone)
    let client = makeClient(transport)
    let result: WeatherZone =
      switch layer {
      case 0: try await client.zone(identifier: "TXZ192", type: .forecast)
      case 1: try await client.value(for: .zone(identifier: "TXZ192", type: .forecast))
      case 2: try await client.zone(identifier: "TXZ192", type: AppZoneType.forecast)
      default:
        try await client.send(
          try #require(Endpoint.zone(identifier: "TXZ192", type: .forecast))
        ).properties
      }
    let recorded = try JSONDecoder().decode(Feature<WeatherZone>.self, from: Fixture.zone.data())
    #expect(result == recorded.properties)
    #expect(result.id == "TXZ192")
    #expect(transport.requests.map(\.request.path) == [Self.detailPath])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/geo+json")
    #expect(transport.requests[0].request.headerFields[.userAgent] == "zone-tests")
    let flags = try #require(HTTPField.Name("Feature-Flags"))
    #expect(transport.requests[0].request.headerFields[flags] == nil)
  }

  @Test("The direct endpoint keeps the zone's polygon that the everyday method drops")
  func theDirectEndpointKeepsTheZonesPolygonThatTheEverydayMethodDrops() async throws {
    let transport = MockTransport()
    try answer(transport, path: Self.detailPath, with: .zone)
    let client = makeClient(transport)

    let feature = try await client.send(
      try #require(Endpoint.zone(identifier: "TXZ192", type: .forecast)))

    guard case .object(let geometry) = feature.geometry else {
      Issue.record("Expected the recorded polygon")
      return
    }
    #expect(geometry["type"] == .string("Polygon"))
    #expect(feature.id == URL(string: "https://api.weather.gov/zones/forecast/TXZ192"))
  }

  @Test("An effective instant is sent with whole-second precision", arguments: [false, true])
  func anEffectiveInstantIsSentWithWholeSecondPrecision(useRequest: Bool) async throws {
    let transport = MockTransport()
    let path = "/zones/forecast/TXZ192?effective=2026-09-20T00:00:00Z"
    try answer(transport, path: path, with: .zone)
    let client = makeClient(transport)
    // 2026-09-20T00:00:00.25Z
    let effective = Date(timeIntervalSince1970: 1_789_862_400.25)

    let zone: WeatherZone =
      if useRequest {
        try await client.value(
          for: .zone(effective: effective, identifier: "TXZ192", type: .forecast))
      } else {
        try await client.zone(effective: effective, identifier: "TXZ192", type: .forecast)
      }

    #expect(zone.id == "TXZ192")
    #expect(transport.requests.map(\.request.path) == [path])
  }

  @Test("Typed directory access layers agree and send one request", arguments: [0, 1, 2, 3])
  func typedDirectoryAccessLayersAgreeAndSendOneRequest(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: Self.typedPath, with: .zonesOfType)
    let client = makeClient(transport)
    let query = texas
    let result: FeatureCollection<WeatherZone> =
      switch layer {
      case 0: try await client.zones(matching: query, ofType: .forecast)
      case 1: try await client.value(for: .zones(matching: query, ofType: .forecast))
      case 2: try await client.zones(matching: query, ofType: AppZoneType.forecast)
      default:
        try await client.send(try #require(Endpoint.zones(matching: query, ofType: .forecast)))
      }
    let recorded = try JSONDecoder().decode(
      FeatureCollection<WeatherZone>.self, from: Fixture.zonesOfType.data())
    #expect(result == recorded)
    #expect(result.features.map(\.properties.id) == ["TXZ001", "TXZ002"])
    #expect(transport.requests.map(\.request.path) == [Self.typedPath])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/geo+json")
  }

  @Test("Root directory access layers agree and send one request", arguments: [0, 1, 2, 3])
  func rootDirectoryAccessLayersAgreeAndSendOneRequest(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: Self.rootPath, with: .zones)
    let client = makeClient(transport)
    let query = texas
    let result: FeatureCollection<WeatherZone> =
      switch layer {
      case 0: try await client.zones(matching: query)
      case 1: try await client.value(for: .zones(matching: query))
      case 2: try await client.value(for: .texasZones)
      default: try await client.send(Endpoint.zones(matching: query))
      }
    let recorded = try JSONDecoder().decode(
      FeatureCollection<WeatherZone>.self, from: Fixture.zones.data())
    #expect(result == recorded)
    #expect(result.features.map(\.properties.id) == ["TXC001", "TXC003"])
    #expect(transport.requests.map(\.request.path) == [Self.rootPath])
  }

  @Test("A root directory type filter is sent as a query", arguments: [false, true])
  func aRootDirectoryTypeFilterIsSentAsAQuery(useRequest: Bool) async throws {
    let transport = MockTransport()
    let path = "/zones?area=TX&limit=2&type=county,fire"
    try answer(transport, path: path, with: .zones)
    let client = makeClient(transport)
    let query = texas

    let result: FeatureCollection<WeatherZone> =
      if useRequest {
        try await client.value(
          for: .zones(matching: query, types: [AppZoneType.county, .fire] as [AppZoneType]))
      } else {
        try await client.zones(matching: query, types: [.county, .fire])
      }

    #expect(result.features.count == 2)
    #expect(transport.requests.map(\.request.path) == [path])
  }

  @Test(
    "A directory list sends one request even when its body carries a continuation",
    arguments: [0, 1, 2], [false, true])
  func aDirectoryListSendsOneRequestEvenWhenItsBodyCarriesAContinuation(
    layer: Int, ofType: Bool
  ) async throws {
    let transport = MockTransport()
    let path = ofType ? Self.typedPath : Self.rootPath
    answer(transport, path: path, with: try continued(ofType ? .zonesOfType : .zones))
    let client = makeClient(transport)
    let query = texas

    let result: FeatureCollection<WeatherZone> =
      switch (layer, ofType) {
      case (0, true): try await client.zones(matching: query, ofType: .forecast)
      case (0, false): try await client.zones(matching: query)
      case (1, true): try await client.value(for: .zones(matching: query, ofType: .forecast))
      case (1, false): try await client.value(for: .zones(matching: query))
      case (_, true):
        try await client.send(try #require(Endpoint.zones(matching: query, ofType: .forecast)))
      case (_, false): try await client.send(Endpoint.zones(matching: query))
      }

    #expect(result.pagination?.next == Self.continuation)
    #expect(transport.requests.map(\.request.path) == [path])
  }

  @Test("The marine route decodes a coastal zone through every layer", arguments: [false, true])
  func theMarineRouteDecodesACoastalZoneThroughEveryLayer(useRequest: Bool) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/zones/marine/GMZ330", with: .zoneMarine)
    let client = makeClient(transport)

    let zone: WeatherZone =
      if useRequest {
        try await client.value(for: .zone(identifier: "GMZ330", type: .marine))
      } else {
        try await client.zone(identifier: "GMZ330", type: .marine)
      }

    #expect(zone.type == .coastal)
    #expect(zone.state == nil)
    #expect(transport.requests.map(\.request.path) == ["/zones/marine/GMZ330"])
  }

  @Test("An empty zone identifier is rejected without sending", arguments: [false, true])
  func anEmptyZoneIdentifierIsRejectedWithoutSending(useRequest: Bool) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)

    let failure = await #expect(throws: NWSError.self) {
      if useRequest {
        _ = try await client.value(for: .zone(identifier: "", type: .forecast))
      } else {
        _ = try await client.zone(identifier: "", type: .forecast)
      }
    }

    guard case .invalidZoneIdentifier("") = failure else {
      Issue.record("Expected an invalid identifier, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test(
    "An unusable identifier is rejected as an identifier, not a type",
    arguments: ["..", "\\"])
  func anUnusableIdentifierIsRejectedAsAnIdentifierNotAType(identifier: String) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)

    let failure = await #expect(throws: NWSError.self) {
      _ = try await client.zone(identifier: identifier, type: .forecast)
    }

    guard case .invalidZoneIdentifier(let reported) = failure, reported == identifier else {
      Issue.record("Expected an invalid identifier, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test(
    "An empty or unusable zone type is rejected without sending",
    arguments: ["", ".", "\\"], [0, 1, 2, 3])
  func anEmptyOrUnusableZoneTypeIsRejectedWithoutSending(type: String, layer: Int) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let query = texas
    let zoneType = ZoneType(rawValue: type)

    let failure = await #expect(throws: NWSError.self) {
      switch layer {
      case 0: _ = try await client.zone(identifier: "TXZ192", type: zoneType)
      case 1: _ = try await client.value(for: .zone(identifier: "TXZ192", type: zoneType))
      case 2: _ = try await client.zones(matching: query, ofType: zoneType)
      default: _ = try await client.value(for: .zones(matching: query, ofType: zoneType))
      }
    }

    guard case .invalidZoneType(let reported) = failure, reported == type else {
      Issue.record("Expected an invalid type, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("An unknown zone type reaches the service and its problem details are preserved")
  func anUnknownZoneTypeReachesTheServiceAndItsProblemDetailsArePreserved() async throws {
    let transport = MockTransport()
    try answer(
      transport, path: "/zones/future/TXZ192", status: .notFound, with: .unknownRegionProblem)
    let client = makeClient(transport)

    let failure = await #expect(throws: NWSError.self) {
      _ = try await client.zone(identifier: "TXZ192", type: ZoneType(rawValue: "future"))
    }

    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.status == 404)
    #expect(problem.parameterErrors?.isEmpty == false)
    #expect(transport.requests.map(\.request.path) == ["/zones/future/TXZ192"])
  }

  @Test("A same-origin redirect preserves headers and decodes the recorded zone")
  func aSameOriginRedirectPreservesHeadersAndDecodesTheRecordedZone() async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: "/zones/forecast/txz192") { _ in
      .success(
        MockTransport.Answer(
          Response(headers: [.location: Self.detailPath], status: .movedPermanently)))
    }
    try answer(transport, path: Self.detailPath, with: .zone)
    let client = makeClient(transport)

    let zone = try await client.zone(identifier: "txz192", type: .forecast)

    #expect(zone.id == "TXZ192")
    #expect(transport.requests.map(\.request.path) == ["/zones/forecast/txz192", Self.detailPath])
    #expect(transport.requests.allSatisfy { $0.request.headerFields[.userAgent] == "zone-tests" })
    #expect(
      transport.requests.allSatisfy { $0.request.headerFields[.accept] == "application/geo+json" })
  }

  @Test("A redirect outside the API origin is not followed")
  func aRedirectOutsideTheAPIOriginIsNotFollowed() async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: Self.detailPath) { _ in
      .success(
        MockTransport.Answer(
          Response(
            headers: [.location: "https://example.com/zones/forecast/TXZ192"],
            status: .movedPermanently)))
    }
    let client = makeClient(transport)

    let failure = await #expect(throws: NWSError.self) {
      _ = try await client.zone(identifier: "TXZ192", type: .forecast)
    }

    guard case .invalidLink = failure else {
      Issue.record("Expected an invalid link, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.count == 1)
  }

  @Test("A malformed zone body is a transport decoding failure", arguments: [false, true])
  func aMalformedZoneBodyIsATransportDecodingFailure(useRequest: Bool) async throws {
    let transport = MockTransport()
    transport.setHandler(forPath: Self.detailPath) { _ in
      .success(MockTransport.Answer(Response(body: Data("{\"id\":".utf8), status: .ok)))
    }
    let client = makeClient(transport)

    let failure = await #expect(throws: NWSError.self) {
      if useRequest {
        _ = try await client.value(for: .zone(identifier: "TXZ192", type: .forecast))
      } else {
        _ = try await client.zone(identifier: "TXZ192", type: .forecast)
      }
    }

    guard case .transport(.decode) = failure else {
      Issue.record("Expected a decoding failure, got \(String(describing: failure))")
      return
    }
  }

  @Test("A consumer-defined zone response decodes through a followed link")
  func aConsumerDefinedZoneResponseDecodesThroughAFollowedLink() async throws {
    let transport = MockTransport()
    try answer(transport, path: Self.detailPath, with: .zone)
    let client = makeClient(transport)
    let link = try #require(URL(string: "https://api.weather.gov/zones/forecast/TXZ192"))
    let endpoint = try #require(Endpoint<Feature<ConsumerZone>>(link: link))
    let request = WeatherRequest(endpoint: endpoint)
    #expect(transport.requests.isEmpty)

    let result = try await client.value(for: request)

    #expect(result.properties == ConsumerZone(name: "Travis", radarStation: "GRK"))
    #expect(result.geometry != nil)
    #expect(transport.requests.map(\.request.path) == [Self.detailPath])
  }


  @Test("Stored zone requests infer their responses without I/O")
  func storedZoneRequestsInferTheirResponsesWithoutIO() async throws {
    let transport = MockTransport()
    try answer(transport, path: Self.detailPath, with: .zone)
    try answer(transport, path: Self.typedPath, with: .zonesOfType)
    let client = makeClient(transport)
    let detail = WeatherRequest.zone(identifier: "TXZ192", type: .forecast)
    let typed = WeatherRequest.zones(matching: texas, ofType: .forecast)
    #expect(transport.requests.isEmpty)

    let zone = try await client.value(for: detail)
    let zones = try await client.value(for: typed)
    let named = try await client.value(for: .travis)

    #expect(zone == named)
    #expect(zones.features.count == 2)
    #expect(
      transport.requests.map(\.request.path) == [Self.detailPath, Self.typedPath, Self.detailPath])
  }

  private func answer(
    _ transport: MockTransport, path: String, status: HTTPResponse.Status = .ok, with body: Data
  ) {
    // The mock transport matches a handler on the path without its query; the query is asserted
    // through the recorded request.
    let key = String(path.split(separator: "?", maxSplits: 1)[0])
    transport.setHandler(forPath: key) { _ in
      .success(MockTransport.Answer(Response(body: body, status: status)))
    }
  }

  private func answer(
    _ transport: MockTransport, path: String, status: HTTPResponse.Status = .ok,
    with fixture: Fixture
  ) throws {
    answer(transport, path: path, status: status, with: try fixture.data())
  }

  // The recorded directory bodies carry no continuation, so a list that stops after one response
  // proves nothing against them. This variant adds one and is not a live capture.
  private func continued(_ fixture: Fixture) throws -> Data {
    var collection = try JSONDecoder().decode(
      FeatureCollection<WeatherZone>.self, from: fixture.data())
    collection.pagination = PaginationInfo(next: Self.continuation)
    return try JSONEncoder().encode(collection)
  }

  private func makeClient(_ transport: MockTransport) -> NWSClient {
    NWSClient(configuration: .init(userAgent: "zone-tests"), transport: transport)
  }
}

private struct ConsumerZone: Decodable, Equatable, Sendable {
  var name: String
  var radarStation: String?
}

private enum AppZoneType: String {
  case county
  case fire
  case forecast
}

extension WeatherRequest where Response == WeatherZone {
  fileprivate static var travis: Self { .zone(identifier: "TXZ192", type: .forecast) }
}

extension WeatherRequest where Response == FeatureCollection<WeatherZone> {
  fileprivate static var texasZones: Self {
    .zones(matching: try! ZoneQuery(areas: [.texas], limit: 2))
  }
}

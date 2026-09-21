import Foundation
import HTTPCore
import HTTPTesting
import HTTPTypes
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Product client", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ProductClientTests {
  @Test("A cancelled product lookup sends nothing", arguments: [0, 1, 2, 3])
  func aCancelledProductLookupSendsNothing(operation: Int) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let task = Task {
      await #expect(throws: NWSError.self) {
        switch operation {
        case 0: _ = try await client.productTypes()
        case 1: _ = try await client.productLocations()
        case 2: _ = try await client.productLocations(for: .areaForecastDiscussion)
        default: _ = try await client.productTypes(at: "EWX")
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

  @Test("A consumer-defined product code reaches the recorded route", arguments: [0, 1, 2])
  func aConsumerDefinedProductCodeReachesTheRecordedRoute(layer: Int) async throws {
    let transport = MockTransport()
    try answer(transport, path: "/products/types/AFD/locations", with: .productLocationsForType)
    let client = makeClient(transport)
    let locations: ProductLocations =
      switch layer {
      case 0: try await client.productLocations(for: DemoProductCode.areaForecastDiscussion)
      case 1:
        try await client.value(for: .productLocations(for: DemoProductCode.areaForecastDiscussion))
      default:
        try await client.send(
          try #require(Endpoint.productLocations(for: DemoProductCode.areaForecastDiscussion)))
      }

    #expect(locations.locations.count == 123)
    #expect(transport.requests.map(\.request.path) == ["/products/types/AFD/locations"])
  }

  @Test("An empty product code sends nothing", arguments: [0, 1, 2])
  func anEmptyProductCodeSendsNothing(layer: Int) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let empty = ProductCode(rawValue: "")
    let failure = await #expect(throws: NWSError.self) {
      switch layer {
      case 0: _ = try await client.productLocations(for: empty)
      case 1: _ = try await client.value(for: .productLocations(for: empty))
      default: _ = try await client.productLocations(for: UnnamedProductCode.blank)
      }
    }
    guard case .invalidProductCode(let code) = failure else {
      Issue.record("Expected an invalid product code, got \(String(describing: failure))")
      return
    }
    #expect(code.isEmpty)
    #expect(transport.requests.isEmpty)
  }

  @Test("An empty product location sends nothing", arguments: [0, 1])
  func anEmptyProductLocationSendsNothing(layer: Int) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      switch layer {
      case 0: _ = try await client.productTypes(at: "")
      default: _ = try await client.value(for: .productTypes(at: ""))
      }
    }
    guard case .invalidProductLocation(let location) = failure else {
      Issue.record("Expected an invalid product location, got \(String(describing: failure))")
      return
    }
    #expect(location.isEmpty)
    #expect(transport.requests.isEmpty)
  }

  @Test("An uncatalogued product code stays the service's problem")
  func anUncataloguedProductCodeStaysTheServicesProblem() async throws {
    let transport = MockTransport()
    try answer(
      transport, path: "/products/types/XXX/locations", status: .notFound, with: .problemDetail)
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      try await client.productLocations(for: ProductCode(rawValue: "XXX"))
    }
    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.status == 404)
    #expect(transport.requests.map(\.request.path) == ["/products/types/XXX/locations"])
  }

  @Test(
    "Product access layers agree", arguments: [0, 1, 2, 3], [0, 1, 2])
  func productAccessLayersAgree(operation: Int, layer: Int) async throws {
    let path = [
      "/products/types", "/products/locations", "/products/types/AFD/locations",
      "/products/locations/EWX/types",
    ][operation]
    let transport = MockTransport()
    try answer(
      transport, path: path,
      with: [
        Fixture.productTypes, .productLocations, .productLocationsForType, .productTypesAtLocation,
      ][operation])
    let client = makeClient(transport)
    let count: Int
    switch operation {
    case 0:
      let types: ProductTypes =
        switch layer {
        case 0: try await client.productTypes()
        case 1: try await client.value(for: .productTypes)
        default: try await client.send(Endpoint.productTypes)
        }
      count = types.types.count
    case 1:
      let locations: ProductLocations =
        switch layer {
        case 0: try await client.productLocations()
        case 1: try await client.value(for: .productLocations)
        default: try await client.send(Endpoint.productLocations)
        }
      count = locations.locations.count
    case 2:
      let locations: ProductLocations =
        switch layer {
        case 0: try await client.productLocations(for: .areaForecastDiscussion)
        case 1: try await client.value(for: .productLocations(for: .areaForecastDiscussion))
        default:
          try await client.send(
            try #require(Endpoint.productLocations(for: ProductCode.areaForecastDiscussion)))
        }
      count = locations.locations.count
    default:
      let types: ProductTypes =
        switch layer {
        case 0: try await client.productTypes(at: "EWX")
        case 1: try await client.value(for: .productTypes(at: "EWX"))
        default: try await client.send(try #require(Endpoint.productTypes(at: "EWX")))
        }
      count = types.types.count
    }

    #expect(count == [338, 1693, 123, 20][operation])
    #expect(transport.requests.map(\.request.path) == [path])
    #expect(transport.requests[0].request.headerFields[.accept] == "application/ld+json")
    #expect(transport.requests[0].request.headerFields[.userAgent] == "product-tests")
  }

  @Test(
    "Product redirects cannot escape the API origin",
    arguments: [
      "https://example.com/products/types", "http://api.weather.gov/products/types",
      "https://user:password@api.weather.gov/products/types",
      "https://api.weather.gov/products/types#catalog",
    ])
  func productRedirectsCannotEscapeTheAPIOrigin(location: String) async throws {
    let transport = MockTransport()
    redirect(transport, from: "/products/types", to: location)
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      try await client.productTypes()
    }
    guard case .invalidLink = failure else {
      Issue.record("Expected an invalid link, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.map(\.request.path) == ["/products/types"])
  }

  @Test("Product locations are sent as one segment with their case preserved")
  func productLocationsAreSentAsOneSegmentWithTheirCasePreserved() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/products/locations/ewx/types", with: .productTypesAtLocation)
    try answer(transport, path: "/products/locations/E%2FX/types", with: .productTypesAtLocation)
    let client = makeClient(transport)

    _ = try await client.productTypes(at: "ewx")
    _ = try await client.productTypes(at: "E/X")

    #expect(
      transport.requests.map(\.request.path)
        == ["/products/locations/ewx/types", "/products/locations/E%2FX/types"])
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
    NWSClient(configuration: .init(userAgent: "product-tests"), transport: transport)
  }

  private func redirect(_ transport: MockTransport, from path: String, to location: String) {
    transport.setHandler(forPath: path) { _ in
      .success(
        MockTransport.Answer(Response(headers: [.location: location], status: .movedPermanently)))
    }
  }
}

private enum DemoProductCode: String {
  case areaForecastDiscussion = "AFD"
}

private enum UnnamedProductCode: String {
  case blank = ""
}

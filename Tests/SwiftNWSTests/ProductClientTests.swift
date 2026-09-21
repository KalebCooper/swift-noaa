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

  @Test(
    "Product text access layers agree", arguments: [0, 1, 2, 3, 4], [0, 1, 2])
  func productTextAccessLayersAgree(operation: Int, layer: Int) async throws {
    let path = [
      "/products", "/products/a6addd61-6620-4718-9d53-effd7d8c2560", "/products/types/AFD",
      "/products/types/AFD/locations/EWX", "/products/types/AFD/locations/EWX/latest",
    ][operation]
    let transport = MockTransport()
    try answer(
      transport, path: path,
      with: [
        Fixture.products, .product, .productsOfType, .productsAtLocation, .productLatest,
      ][operation])
    let client = makeClient(transport)
    let query = try ProductQuery(limit: 2, locations: ["EWX"], types: [.areaForecastDiscussion])
    let identifier = "a6addd61-6620-4718-9d53-effd7d8c2560"
    switch operation {
    case 0:
      let products: TextProducts =
        switch layer {
        case 0: try await client.products(matching: query)
        case 1: try await client.value(for: .products(matching: query))
        default: try await client.send(Endpoint.products(matching: query))
        }
      #expect(products.products.count == 2)
      #expect(products.products.first?.id == identifier)
    case 1:
      let product: TextProduct =
        switch layer {
        case 0: try await client.product(identifier: identifier)
        case 1: try await client.value(for: .product(identifier: identifier))
        default: try await client.send(try #require(Endpoint.product(identifier: identifier)))
        }
      #expect(product.id == identifier)
      #expect(product.productText?.hasPrefix("\n000\nFXUS64 KEWX 200518\nAFDEWX\n") == true)
    case 2:
      let products: TextProducts =
        switch layer {
        case 0: try await client.products(ofType: .areaForecastDiscussion)
        case 1: try await client.value(for: .products(ofType: .areaForecastDiscussion))
        default:
          try await client.send(
            try #require(Endpoint.products(ofType: ProductCode.areaForecastDiscussion)))
        }
      #expect(products.products.count == 4567)
      #expect(products.products.contains { $0.id == identifier })
    case 3:
      let products: TextProducts =
        switch layer {
        case 0: try await client.products(at: "EWX", ofType: .areaForecastDiscussion)
        case 1: try await client.value(for: .products(at: "EWX", ofType: .areaForecastDiscussion))
        default:
          try await client.send(
            try #require(
              Endpoint.products(at: "EWX", ofType: ProductCode.areaForecastDiscussion)))
        }
      #expect(products.products.count == 33)
      #expect(products.products.first?.id == identifier)
    default:
      let product: TextProduct =
        switch layer {
        case 0: try await client.latestProduct(at: "EWX", ofType: .areaForecastDiscussion)
        case 1:
          try await client.value(for: .latestProduct(at: "EWX", ofType: .areaForecastDiscussion))
        default:
          try await client.send(
            try #require(
              Endpoint.latestProduct(at: "EWX", ofType: ProductCode.areaForecastDiscussion)))
        }
      #expect(product.id == identifier)
      #expect(product.productText?.hasPrefix("\n000\nFXUS64 KEWX 200518\nAFDEWX\n") == true)
    }

    #expect(transport.requests.count == 1)
    #expect(transport.requests[0].request.path?.hasPrefix(path) == true)
    #expect(transport.requests[0].request.headerFields[.accept] == "application/ld+json")
    #expect(transport.requests[0].request.headerFields[.userAgent] == "product-tests")
  }

  @Test("A product query reaches the service as the parameters it documents")
  func aProductQueryReachesTheServiceAsTheParametersItDocuments() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/products", with: .products)
    let client = makeClient(transport)
    let query = try ProductQuery(limit: 2, locations: ["EWX"], types: [.areaForecastDiscussion])

    let products = try await client.products(matching: query)

    #expect(products.products.count == 2)
    #expect(
      transport.requests.map(\.request.path) == ["/products?limit=2&location=EWX&type=AFD"])
  }

  @Test("A cancelled product text lookup sends nothing", arguments: [0, 1, 2, 3, 4])
  func aCancelledProductTextLookupSendsNothing(operation: Int) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let query = try ProductQuery()
    let task = Task {
      await #expect(throws: NWSError.self) {
        switch operation {
        case 0: _ = try await client.products(matching: query)
        case 1: _ = try await client.product(identifier: "a6addd61-6620-4718-9d53-effd7d8c2560")
        case 2: _ = try await client.products(ofType: .areaForecastDiscussion)
        case 3: _ = try await client.products(at: "EWX", ofType: .areaForecastDiscussion)
        default: _ = try await client.latestProduct(at: "EWX", ofType: .areaForecastDiscussion)
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

  @Test("An empty product identifier sends nothing", arguments: [0, 1])
  func anEmptyProductIdentifierSendsNothing(layer: Int) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      switch layer {
      case 0: _ = try await client.product(identifier: "")
      default: _ = try await client.value(for: .product(identifier: ""))
      }
    }
    guard case .invalidProductIdentifier(let identifier) = failure else {
      Issue.record("Expected an invalid product identifier, got \(String(describing: failure))")
      return
    }
    #expect(identifier.isEmpty)
    #expect(transport.requests.isEmpty)
  }

  @Test("An empty code on a product text route sends nothing", arguments: [0, 1, 2])
  func anEmptyCodeOnAProductTextRouteSendsNothing(operation: Int) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let empty = ProductCode(rawValue: "")
    let failure = await #expect(throws: NWSError.self) {
      switch operation {
      case 0: _ = try await client.products(ofType: empty)
      case 1: _ = try await client.products(at: "EWX", ofType: empty)
      default: _ = try await client.latestProduct(at: "EWX", ofType: empty)
      }
    }
    guard case .invalidProductCode(let code) = failure else {
      Issue.record("Expected an invalid product code, got \(String(describing: failure))")
      return
    }
    #expect(code.isEmpty)
    #expect(transport.requests.isEmpty)
  }

  @Test("An empty location on a product text route sends nothing", arguments: [0, 1])
  func anEmptyLocationOnAProductTextRouteSendsNothing(operation: Int) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      switch operation {
      case 0: _ = try await client.products(at: "", ofType: .areaForecastDiscussion)
      default: _ = try await client.latestProduct(at: "", ofType: .areaForecastDiscussion)
      }
    }
    guard case .invalidProductLocation(let location) = failure else {
      Issue.record("Expected an invalid product location, got \(String(describing: failure))")
      return
    }
    #expect(location.isEmpty)
    #expect(transport.requests.isEmpty)
  }

  @Test("An unusable product code is reported before an unusable location", arguments: [0, 1])
  func anUnusableProductCodeIsReportedBeforeAnUnusableLocation(operation: Int) async throws {
    let transport = MockTransport()
    let client = makeClient(transport)
    let empty = ProductCode(rawValue: "")
    let failure = await #expect(throws: NWSError.self) {
      switch operation {
      case 0: _ = try await client.products(at: "", ofType: empty)
      default: _ = try await client.latestProduct(at: "", ofType: empty)
      }
    }
    guard case .invalidProductCode = failure else {
      Issue.record("Expected an invalid product code, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.isEmpty)
  }

  @Test("An unknown product identifier stays the service's problem")
  func anUnknownProductIdentifierStaysTheServicesProblem() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/products/missing", status: .notFound, with: .problemDetail)
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      try await client.product(identifier: "missing")
    }
    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.status == 404)
    #expect(transport.requests.map(\.request.path) == ["/products/missing"])
  }

  @Test(
    "An uncatalogued product code on a text route stays the service's problem",
    arguments: [0, 1])
  func anUncataloguedProductCodeOnATextRouteStaysTheServicesProblem(operation: Int) async throws {
    let path = ["/products/types/XXX", "/products/types/XXX/locations/EWX/latest"][operation]
    let transport = MockTransport()
    try answer(transport, path: path, status: .notFound, with: .problemDetail)
    let client = makeClient(transport)
    let uncatalogued = ProductCode(rawValue: "XXX")
    let failure = await #expect(throws: NWSError.self) {
      switch operation {
      case 0: _ = try await client.products(ofType: uncatalogued)
      default: _ = try await client.latestProduct(at: "EWX", ofType: uncatalogued)
      }
    }
    guard case .problem(let problem) = failure else {
      Issue.record("Expected problem details, got \(String(describing: failure))")
      return
    }
    #expect(problem.status == 404)
    #expect(transport.requests.map(\.request.path) == [path])
  }

  @Test("A malformed product body is a transport decoding failure", arguments: [0, 1])
  func aMalformedProductBodyIsATransportDecodingFailure(operation: Int) async throws {
    let identifier = "a6addd61-6620-4718-9d53-effd7d8c2560"
    let path = ["/products/" + identifier, "/products/types/AFD"][operation]
    let transport = MockTransport()
    transport.setHandler(forPath: path) { _ in
      .success(MockTransport.Answer(Response(body: Data("not json at all".utf8), status: .ok)))
    }
    let client = makeClient(transport)

    let failure = await #expect(throws: NWSError.self) {
      switch operation {
      case 0: _ = try await client.product(identifier: identifier)
      default: _ = try await client.products(ofType: .areaForecastDiscussion)
      }
    }

    guard case .transport(.decode) = failure else {
      Issue.record("Expected a decoding failure, got \(String(describing: failure))")
      return
    }
    #expect(transport.requests.map(\.request.path) == [path])
  }

  @Test(
    "A product text redirect cannot escape the API origin",
    arguments: [
      "https://example.com/products/types/AFD/locations/EWX/latest",
      "http://api.weather.gov/products/types/AFD/locations/EWX/latest",
      "https://user:password@api.weather.gov/products/types/AFD/locations/EWX/latest",
      "https://api.weather.gov/products/types/AFD/locations/EWX/latest#text",
    ])
  func aProductTextRedirectCannotEscapeTheAPIOrigin(location: String) async throws {
    let transport = MockTransport()
    redirect(transport, from: "/products/types/AFD/locations/EWX/latest", to: location)
    let client = makeClient(transport)
    let failure = await #expect(throws: NWSError.self) {
      try await client.latestProduct(at: "EWX", ofType: .areaForecastDiscussion)
    }
    guard case .invalidLink = failure else {
      Issue.record("Expected an invalid link, got \(String(describing: failure))")
      return
    }
    #expect(
      transport.requests.map(\.request.path) == ["/products/types/AFD/locations/EWX/latest"])
  }

  @Test("A listed product's identity link retrieves that product")
  func aListedProductsIdentityLinkRetrievesThatProduct() async throws {
    let transport = MockTransport()
    try answer(transport, path: "/products", with: .products)
    try answer(
      transport, path: "/products/a6addd61-6620-4718-9d53-effd7d8c2560", with: .product)
    let client = makeClient(transport)
    let listed = try await client.products(matching: try ProductQuery(limit: 2))

    let link = try #require(listed.products.first?.url)
    let product = try await client.send(
      try #require(Endpoint<TextProduct>(accept: .jsonLD, link: link)))

    #expect(listed.products.first?.productText == nil)
    #expect(product.id == "a6addd61-6620-4718-9d53-effd7d8c2560")
    #expect(product.productText?.hasPrefix("\n000\nFXUS64 KEWX 200518\n") == true)
    #expect(
      transport.requests.map(\.request.path)
        == ["/products?limit=2", "/products/a6addd61-6620-4718-9d53-effd7d8c2560"])
  }

  @Test("A consumer-defined product code reaches the recorded text route", arguments: [0, 1, 2])
  func aConsumerDefinedProductCodeReachesTheRecordedTextRoute(layer: Int) async throws {
    let transport = MockTransport()
    try answer(
      transport, path: "/products/types/AFD/locations/EWX", with: .productsAtLocation)
    let client = makeClient(transport)
    let products: TextProducts =
      switch layer {
      case 0: try await client.products(at: "EWX", ofType: DemoProductCode.areaForecastDiscussion)
      case 1:
        try await client.value(
          for: .products(at: "EWX", ofType: DemoProductCode.areaForecastDiscussion))
      default:
        try await client.send(
          try #require(
            Endpoint.products(at: "EWX", ofType: DemoProductCode.areaForecastDiscussion)))
      }

    #expect(products.products.count == 33)
    #expect(transport.requests.map(\.request.path) == ["/products/types/AFD/locations/EWX"])
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

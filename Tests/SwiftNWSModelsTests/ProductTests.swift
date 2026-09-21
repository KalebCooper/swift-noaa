import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Product catalogs", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ProductTests {
  @Test("A location catalog keeps the locations the service left undescribed")
  func aLocationCatalogKeepsTheLocationsTheServiceLeftUndescribed() throws {
    let catalog = try JSONDecoder().decode(
      ProductLocations.self, from: Fixture.productLocations.data())

    let undescribed = try #require(catalog.locations["tmp"])
    let unnamed = try #require(catalog.locations["XXX"])
    let described = try #require(catalog.locations["EWX"])

    #expect(catalog.locations.count == 1693)
    #expect(catalog.locations.values.count { $0 == nil } == 1562)
    #expect(undescribed == nil)
    #expect(unnamed == nil)
    #expect(described == "Austin/San Antonio, TX")
  }

  @Test("A location catalog survives an encode and decode round trip")
  func aLocationCatalogSurvivesAnEncodeAndDecodeRoundTrip() throws {
    let catalog = try JSONDecoder().decode(
      ProductLocations.self, from: Fixture.productLocations.data())

    let encoded = try JSONEncoder().encode(catalog)
    let decoded = try JSONDecoder().decode(ProductLocations.self, from: encoded)

    let undescribed = try #require(decoded.locations["tmp"])
    let described = try #require(decoded.locations["EWX"])

    #expect(decoded == catalog)
    #expect(decoded.locations.count == 1693)
    #expect(undescribed == nil)
    #expect(described == "Austin/San Antonio, TX")
  }

  @Test("A location description that is not a string fails to decode")
  func aLocationDescriptionThatIsNotAStringFailsToDecode() throws {
    let body = try #require(#"{"locations":{"EWX":3}}"#.data(using: .utf8))

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ProductLocations.self, from: body)
    }
  }

  @Test(
    "A location catalog without a locations object fails to decode",
    arguments: [#"{}"#, #"{"locations":[]}"#, #"{"locations":"EWX"}"#])
  func aLocationCatalogWithoutALocationsObjectFailsToDecode(body: String) throws {
    let data = try #require(body.data(using: .utf8))

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ProductLocations.self, from: data)
    }
  }

  @Test("A product type catalog decodes every kind in service order")
  func aProductTypeCatalogDecodesEveryKindInServiceOrder() throws {
    let catalog = try JSONDecoder().decode(ProductTypes.self, from: Fixture.productTypes.data())

    #expect(catalog.types.count == 338)
    #expect(
      catalog.types.first
        == ProductType(
          productCode: ProductCode(rawValue: "ABV"),
          productName: "Rawinsonde Data Above 100 Millibars"))
    #expect(
      catalog.types.last
        == ProductType(productCode: .publicZoneForecast, productName: "Zone Forecast Product"))
    #expect(catalog.types.contains { $0.productCode == .areaForecastDiscussion })
    #expect(catalog.types.contains { $0.productCode == .specialWeatherStatement })
  }

  @Test(
    "A product type catalog without a graph array fails to decode",
    arguments: [#"{}"#, #"{"@graph":{}}"#])
  func aProductTypeCatalogWithoutAGraphArrayFailsToDecode(body: String) throws {
    let data = try #require(body.data(using: .utf8))

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ProductTypes.self, from: data)
    }
  }

  @Test("A product type without a name fails to decode")
  func aProductTypeWithoutANameFailsToDecode() throws {
    let data = try #require(#"{"@graph":[{"productCode":"AFD"}]}"#.data(using: .utf8))

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ProductTypes.self, from: data)
    }
  }

  @Test("A type's locations keep the descriptions the service published")
  func aTypesLocationsKeepTheDescriptionsTheServicePublished() throws {
    let catalog = try JSONDecoder().decode(
      ProductLocations.self, from: Fixture.productLocationsForType.data())

    let albuquerque = try #require(catalog.locations["ABQ"])
    let lasVegas = try #require(catalog.locations["VEF"])

    #expect(catalog.locations.count == 123)
    #expect(catalog.locations.values.allSatisfy { $0 != nil })
    #expect(albuquerque == "Albuquerque, NM")
    #expect(lasVegas == "Las Vegas, NV")
  }

  @Test("An empty product code or location has no endpoint")
  func anEmptyProductCodeOrLocationHasNoEndpoint() {
    #expect(Endpoint<ProductLocations>.productLocations(for: ProductCode(rawValue: "")) == nil)
    #expect(Endpoint<ProductTypes>.productTypes(at: "") == nil)
  }

  @Test("An unknown product code keeps the service's exact value")
  func anUnknownProductCodeKeepsTheServicesExactValue() throws {
    let body = try #require(
      #"{"productCode":"XYZ","productName":"Experimental"}"#.data(using: .utf8))

    let type = try JSONDecoder().decode(ProductType.self, from: body)

    let encoded = try JSONEncoder().encode(type.productCode)

    #expect(type.productCode.rawValue == "XYZ")
    #expect(type.productCode == ProductCode(rawValue: "XYZ"))
    #expect(String(decoding: encoded, as: UTF8.self) == #""XYZ""#)
  }

  @Test("Every product endpoint names the route it was recorded from", arguments: [0, 1, 2, 3])
  func everyProductEndpointNamesTheRouteItWasRecordedFrom(operation: Int) throws {
    let accept: MediaType
    let featureFlags: [NWSFeatureFlag]
    let path: String
    switch operation {
    case 0:
      let endpoint = Endpoint<ProductTypes>.productTypes
      (accept, featureFlags, path) = (endpoint.accept, endpoint.featureFlags, endpoint.path)
    case 1:
      let endpoint = Endpoint<ProductLocations>.productLocations
      (accept, featureFlags, path) = (endpoint.accept, endpoint.featureFlags, endpoint.path)
    case 2:
      let endpoint = try #require(
        Endpoint<ProductLocations>.productLocations(for: .areaForecastDiscussion))
      (accept, featureFlags, path) = (endpoint.accept, endpoint.featureFlags, endpoint.path)
    default:
      let endpoint = try #require(Endpoint<ProductTypes>.productTypes(at: "EWX"))
      (accept, featureFlags, path) = (endpoint.accept, endpoint.featureFlags, endpoint.path)
    }

    #expect(
      path
        == [
          "/products/types", "/products/locations", "/products/types/AFD/locations",
          "/products/locations/EWX/types",
        ][operation])
    #expect(accept == .jsonLD)
    #expect(featureFlags.isEmpty)
    #expect(!path.contains("?"))
  }

  @Test("The named product codes are the codes the service issues products under")
  func theNamedProductCodesAreTheCodesTheServiceIssuesProductsUnder() {
    #expect(ProductCode.areaForecastDiscussion.rawValue == "AFD")
    #expect(ProductCode.publicZoneForecast.rawValue == "ZFP")
    #expect(ProductCode.specialWeatherStatement.rawValue == "SPS")
  }

  @Test("The product types of a location decode in service order")
  func theProductTypesOfALocationDecodeInServiceOrder() throws {
    let catalog = try JSONDecoder().decode(
      ProductTypes.self, from: Fixture.productTypesAtLocation.data())

    #expect(
      catalog.types.map(\.productCode.rawValue) == [
        "AFD", "ESG", "FWF", "FWS", "HML", "HYD", "LCO", "NPW", "PFM", "PFW", "RFD", "RRM", "RRS",
        "RVA", "RVF", "RWR", "SFT", "STQ", "VFT", "ZFP",
      ])
    #expect(catalog.types.first?.productName == "Area Forecast Discussion")
    #expect(catalog.types.last?.productName == "Zone Forecast Product")
  }

  @Test("A product segment is encoded once and its case preserved")
  func aProductSegmentIsEncodedOnceAndItsCasePreserved() throws {
    let encoded = try #require(
      Endpoint<ProductLocations>.productLocations(for: ProductCode(rawValue: "A/D")))
    let lowercased = try #require(Endpoint<ProductTypes>.productTypes(at: "ewx"))

    #expect(encoded.path == "/products/types/A%2FD/locations")
    #expect(lowercased.path == "/products/locations/ewx/types")
  }

  @Test("A consumer-defined product code names the same route")
  func aConsumerDefinedProductCodeNamesTheSameRoute() throws {
    let endpoint = try #require(
      Endpoint<ProductLocations>.productLocations(for: DemoProductCode.areaForecastDiscussion))

    #expect(endpoint.path == "/products/types/AFD/locations")
    #expect(ProductCode(DemoProductCode.areaForecastDiscussion) == .areaForecastDiscussion)
  }

  @Test("A product decodes every field the detail route sends")
  func aProductDecodesEveryFieldTheDetailRouteSends() throws {
    let product = try JSONDecoder().decode(TextProduct.self, from: Fixture.product.data())

    let text = try #require(product.productText)

    #expect(product.id == "a6addd61-6620-4718-9d53-effd7d8c2560")
    #expect(product.issuanceTime == Date(timeIntervalSince1970: 1_789_881_480))
    #expect(product.issuingOffice == "KEWX")
    #expect(product.productCode == .areaForecastDiscussion)
    #expect(product.productName == "Area Forecast Discussion")
    #expect(
      product.url
        == URL(string: "https://api.weather.gov/products/a6addd61-6620-4718-9d53-effd7d8c2560"))
    #expect(product.wmoCollectiveId == "FXUS64")
    #expect(text.hasPrefix("\n000\nFXUS64 KEWX 200518\nAFDEWX\n\n"))
    #expect(text.hasSuffix("\nAVIATION...MMM\n"))
    #expect(text.contains("\n$$\n"))
  }

  @Test("The latest route answers the same product the detail route does")
  func theLatestRouteAnswersTheSameProductTheDetailRouteDoes() throws {
    let decoder = JSONDecoder()

    let latest = try decoder.decode(TextProduct.self, from: Fixture.productLatest.data())
    let detail = try decoder.decode(TextProduct.self, from: Fixture.product.data())

    #expect(latest == detail)
  }

  @Test("A product survives an encode and decode round trip")
  func aProductSurvivesAnEncodeAndDecodeRoundTrip() throws {
    let product = try JSONDecoder().decode(TextProduct.self, from: Fixture.product.data())

    let encoded = try JSONEncoder().encode(product)
    let decoded = try JSONDecoder().decode(TextProduct.self, from: encoded)

    #expect(decoded == product)
    #expect(decoded.productText == product.productText)
    #expect(decoded.url == product.url)
  }

  @Test("A queried product list leaves out product text entirely")
  func aQueriedProductListLeavesOutProductTextEntirely() throws {
    let products = try JSONDecoder().decode(TextProducts.self, from: Fixture.products.data())

    #expect(products.products.count == 2)
    #expect(products.products.allSatisfy { $0.productText == nil })
    #expect(
      products.products.map(\.id) == [
        "a6addd61-6620-4718-9d53-effd7d8c2560", "61631879-faf8-4587-a7db-c691ae14e1ef",
      ])
    #expect(products.products.first?.issuanceTime == Date(timeIntervalSince1970: 1_789_881_480))
    #expect(products.products.last?.issuanceTime == Date(timeIntervalSince1970: 1_789_860_300))
    #expect(products.products.allSatisfy { $0.productCode == .areaForecastDiscussion })
    #expect(products.products.allSatisfy { $0.issuingOffice == "KEWX" })
  }

  @Test("A location's products decode in service order without text")
  func aLocationsProductsDecodeInServiceOrderWithoutText() throws {
    let products = try JSONDecoder().decode(
      TextProducts.self, from: Fixture.productsAtLocation.data())

    #expect(products.products.count == 33)
    #expect(products.products.allSatisfy { $0.productText == nil })
    #expect(products.products.first?.id == "a6addd61-6620-4718-9d53-effd7d8c2560")
    #expect(products.products.allSatisfy { $0.productCode == .areaForecastDiscussion })
  }

  @Test("Every product of one kind decodes in service order")
  func everyProductOfOneKindDecodesInServiceOrder() throws {
    let products = try JSONDecoder().decode(TextProducts.self, from: Fixture.productsOfType.data())

    #expect(products.products.count == 4567)
    #expect(products.products.allSatisfy { $0.productText == nil })
    // The route lists every office's discussions, so the first entry is not Austin/San Antonio's.
    #expect(products.products.first?.id == "2b399f51-368f-4e66-9d4f-beecf652e323")
    #expect(products.products.first?.issuingOffice == "KRIW")
    #expect(products.products.contains { $0.id == "a6addd61-6620-4718-9d53-effd7d8c2560" })
  }

  @Test(
    "Product text is kept exactly as the bytes on the wire spell it",
    arguments: zip(
      [
        #"{"id":"one","productText":"\r\n000\r\nFXUS64 KEWX 200518\r\n"}"#,
        #"{"id":"one","productText":"\n\n\n"}"#,
        #"{"id":"one","productText":"$$\n&&\n"}"#,
        #"{"id":"one","productText":"Sea deés – 30°C"}"#,
        #"{"id":"one","productText":" leading and trailing  "}"#,
      ],
      [
        "\r\n000\r\nFXUS64 KEWX 200518\r\n", "\n\n\n", "$$\n&&\n",
        "Sea de\u{00E9}s \u{2013} 30\u{00B0}C", " leading and trailing  ",
      ]))
  func productTextIsKeptExactlyAsTheBytesOnTheWireSpellIt(body: String, text: String) throws {
    let data = try #require(body.data(using: .utf8))

    let product = try JSONDecoder().decode(TextProduct.self, from: data)

    #expect(product.productText == text)
  }

  @Test("Product text survives an encode and decode round trip", arguments: ["", "\n$$\n", "  "])
  func productTextSurvivesAnEncodeAndDecodeRoundTrip(text: String) throws {
    let body = try JSONEncoder().encode(TextProduct(id: "one", productText: text))

    let product = try JSONDecoder().decode(TextProduct.self, from: body)

    #expect(product.productText == text)
  }

  @Test("Empty, omitted, and null product text stay distinct")
  func emptyOmittedAndNullProductTextStayDistinct() throws {
    let decoder = JSONDecoder()
    let empty = try #require(#"{"id":"one","productText":""}"#.data(using: .utf8))
    let omitted = try #require(#"{"id":"one"}"#.data(using: .utf8))
    let null = try #require(#"{"id":"one","productText":null}"#.data(using: .utf8))

    #expect(try decoder.decode(TextProduct.self, from: empty).productText == "")
    #expect(try decoder.decode(TextProduct.self, from: omitted).productText == nil)
    #expect(try decoder.decode(TextProduct.self, from: null).productText == nil)
  }

  @Test(
    "A product list without a graph array fails to decode",
    arguments: [#"{}"#, #"{"@graph":{}}"#, #"{"@graph":"AFD"}"#])
  func aProductListWithoutAGraphArrayFailsToDecode(body: String) throws {
    let data = try #require(body.data(using: .utf8))

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(TextProducts.self, from: data)
    }
  }

  @Test(
    "A product that is missing or malformed where the schema is strict fails to decode",
    arguments: [
      #"{"productCode":"AFD"}"#, #"{"id":"one","issuanceTime":"yesterday"}"#,
      #"{"id":"one","issuanceTime":"2026-09-20"}"#, #"{"id":"one","@id":""}"#,
      #"{"id":1}"#,
    ])
  func aProductThatIsMissingOrMalformedWhereTheSchemaIsStrictFailsToDecode(body: String) throws {
    let data = try #require(body.data(using: .utf8))

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(TextProduct.self, from: data)
    }
  }

  @Test("A product list entry's identity link becomes a product endpoint")
  func aProductListEntrysIdentityLinkBecomesAProductEndpoint() throws {
    let products = try JSONDecoder().decode(TextProducts.self, from: Fixture.products.data())

    let link = try #require(products.products.first?.url)
    let endpoint = try #require(Endpoint<TextProduct>(accept: .jsonLD, link: link))

    #expect(endpoint.path == "/products/a6addd61-6620-4718-9d53-effd7d8c2560")
    #expect(endpoint.accept == .jsonLD)
  }

  @Test(
    "Every product text endpoint names the route it was recorded from", arguments: [0, 1, 2, 3])
  func everyProductTextEndpointNamesTheRouteItWasRecordedFrom(operation: Int) throws {
    let accept: MediaType
    let featureFlags: [NWSFeatureFlag]
    let path: String
    switch operation {
    case 0:
      let endpoint = try #require(
        Endpoint<TextProduct>.product(identifier: "a6addd61-6620-4718-9d53-effd7d8c2560"))
      (accept, featureFlags, path) = (endpoint.accept, endpoint.featureFlags, endpoint.path)
    case 1:
      let endpoint = try #require(Endpoint<TextProducts>.products(ofType: .areaForecastDiscussion))
      (accept, featureFlags, path) = (endpoint.accept, endpoint.featureFlags, endpoint.path)
    case 2:
      let endpoint = try #require(
        Endpoint<TextProducts>.products(at: "EWX", ofType: .areaForecastDiscussion))
      (accept, featureFlags, path) = (endpoint.accept, endpoint.featureFlags, endpoint.path)
    default:
      let endpoint = try #require(
        Endpoint<TextProduct>.latestProduct(at: "EWX", ofType: .areaForecastDiscussion))
      (accept, featureFlags, path) = (endpoint.accept, endpoint.featureFlags, endpoint.path)
    }

    #expect(
      path
        == [
          "/products/a6addd61-6620-4718-9d53-effd7d8c2560", "/products/types/AFD",
          "/products/types/AFD/locations/EWX", "/products/types/AFD/locations/EWX/latest",
        ][operation])
    #expect(accept == .jsonLD)
    #expect(featureFlags.isEmpty)
    #expect(!path.contains("?"))
  }

  @Test("An empty product identifier, code, or location has no text endpoint")
  func anEmptyProductIdentifierCodeOrLocationHasNoTextEndpoint() {
    let empty = ProductCode(rawValue: "")

    #expect(Endpoint<TextProduct>.product(identifier: "") == nil)
    #expect(Endpoint<TextProducts>.products(ofType: empty) == nil)
    #expect(Endpoint<TextProducts>.products(at: "EWX", ofType: empty) == nil)
    #expect(Endpoint<TextProducts>.products(at: "", ofType: .areaForecastDiscussion) == nil)
    #expect(Endpoint<TextProduct>.latestProduct(at: "EWX", ofType: empty) == nil)
    #expect(Endpoint<TextProduct>.latestProduct(at: "", ofType: .areaForecastDiscussion) == nil)
  }

  @Test("A consumer-defined product code names the same text routes")
  func aConsumerDefinedProductCodeNamesTheSameTextRoutes() throws {
    let list = try #require(
      Endpoint<TextProducts>.products(ofType: DemoProductCode.areaForecastDiscussion))
    let located = try #require(
      Endpoint<TextProducts>.products(at: "EWX", ofType: DemoProductCode.areaForecastDiscussion))
    let latest = try #require(
      Endpoint<TextProduct>.latestProduct(at: "EWX", ofType: DemoProductCode.areaForecastDiscussion)
    )

    #expect(list.path == "/products/types/AFD")
    #expect(located.path == "/products/types/AFD/locations/EWX")
    #expect(latest.path == "/products/types/AFD/locations/EWX/latest")
  }

  @Test("A product segment in a text route is encoded once and its case preserved")
  func aProductSegmentInATextRouteIsEncodedOnceAndItsCasePreserved() throws {
    let identifier = try #require(Endpoint<TextProduct>.product(identifier: "a/b"))
    let located = try #require(
      Endpoint<TextProducts>.products(at: "ewx", ofType: .publicZoneForecast))

    #expect(identifier.path == "/products/a%2Fb")
    #expect(located.path == "/products/types/ZFP/locations/ewx")
  }

  @Test(
    "Every product text request carries the resolution its route needs",
    arguments: [0, 1, 2, 3, 4])
  func everyProductTextRequestCarriesTheResolutionItsRouteNeeds(operation: Int) throws {
    let identifier = "a6addd61-6620-4718-9d53-effd7d8c2560"
    switch operation {
    case 0:
      #expect(
        WeatherRequest.product(identifier: identifier).resolution
          == .product(identifier: identifier))
    case 1:
      #expect(
        WeatherRequest.products(ofType: .areaForecastDiscussion).resolution
          == .productsOfType(location: nil, type: .areaForecastDiscussion))
    case 2:
      #expect(
        WeatherRequest.products(at: "EWX", ofType: .areaForecastDiscussion).resolution
          == .productsOfType(location: "EWX", type: .areaForecastDiscussion))
    case 3:
      #expect(
        WeatherRequest.latestProduct(at: "EWX", ofType: .areaForecastDiscussion).resolution
          == .latestProduct(location: "EWX", type: .areaForecastDiscussion))
    default:
      let query = try ProductQuery(limit: 2, locations: ["EWX"], types: [.areaForecastDiscussion])
      #expect(
        WeatherRequest.products(matching: query).resolution
          == .endpoint(.products(matching: query)))
    }
  }

  @Test("Every product catalog request carries the resolution its route needs")
  func everyProductCatalogRequestCarriesTheResolutionItsRouteNeeds() {
    #expect(
      WeatherRequest.productLocations(for: .areaForecastDiscussion).resolution
        == .productLocations(type: .areaForecastDiscussion))
    #expect(WeatherRequest.productTypes(at: "EWX").resolution == .productTypes(location: "EWX"))
  }

  @Test("A consumer-defined product code makes the same product request")
  func aConsumerDefinedProductCodeMakesTheSameProductRequest() {
    let list: WeatherRequest<TextProducts> = .products(
      ofType: DemoProductCode.areaForecastDiscussion)
    let located: WeatherRequest<TextProducts> = .products(
      at: "EWX", ofType: DemoProductCode.areaForecastDiscussion)
    let latest: WeatherRequest<TextProduct> = .latestProduct(
      at: "EWX", ofType: DemoProductCode.areaForecastDiscussion)
    let locations: WeatherRequest<ProductLocations> = .productLocations(
      for: DemoProductCode.areaForecastDiscussion)

    #expect(list == .products(ofType: .areaForecastDiscussion))
    #expect(located == .products(at: "EWX", ofType: .areaForecastDiscussion))
    #expect(latest == .latestProduct(at: "EWX", ofType: .areaForecastDiscussion))
    #expect(locations == .productLocations(for: .areaForecastDiscussion))
  }

  @Test("An unannotated product request infers its concrete response type")
  func anUnannotatedProductRequestInfersItsConcreteResponseType() {
    let storedProduct = WeatherRequest.product(identifier: "a6addd61-6620-4718-9d53-effd7d8c2560")
    let contextualProduct: WeatherRequest<TextProduct> = .product(
      identifier: "a6addd61-6620-4718-9d53-effd7d8c2560")
    let storedList = WeatherRequest.products(at: "EWX", ofType: .areaForecastDiscussion)
    let contextualList: WeatherRequest<TextProducts> = .products(
      at: "EWX", ofType: .areaForecastDiscussion)

    #expect(storedProduct == contextualProduct)
    #expect(storedList == contextualList)
  }
}

private enum DemoProductCode: String {
  case areaForecastDiscussion = "AFD"
}

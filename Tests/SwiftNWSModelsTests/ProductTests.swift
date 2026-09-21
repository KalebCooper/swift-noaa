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
}

private enum DemoProductCode: String {
  case areaForecastDiscussion = "AFD"
}

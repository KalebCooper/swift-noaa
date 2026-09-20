import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Pagination metadata", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct PaginationInfoTests {
  @Test("A malformed next link remains available for validation")
  func aMalformedNextLinkRemainsAvailableForValidation() throws {
    let body = Data(
      #"{"features":[],"pagination":{"next":"not a valid link %"}}"#.utf8)

    let collection = try JSONDecoder().decode(
      FeatureCollection<ObservationStation>.self, from: body)

    #expect(collection.pagination?.next == "not a valid link %")
  }

  @Test("A missing next value remains distinguishable from a terminal collection")
  func aMissingNextValueRemainsDistinguishableFromATerminalCollection() throws {
    let body = Data(#"{"features":[],"pagination":{}}"#.utf8)

    let collection = try JSONDecoder().decode(
      FeatureCollection<ObservationStation>.self, from: body)

    #expect(collection.pagination != nil)
    #expect(collection.pagination?.next == nil)
  }

  @Test("A terminal collection decodes without pagination metadata")
  func aTerminalCollectionDecodesWithoutPaginationMetadata() throws {
    let body = Data(#"{"features":[]}"#.utf8)

    let collection = try JSONDecoder().decode(
      FeatureCollection<ObservationStation>.self, from: body)

    #expect(collection.pagination == nil)
    #expect(FeatureCollection<ObservationStation>(features: []).pagination == nil)
  }

  @Test("A valid next link is preserved exactly")
  func aValidNextLinkIsPreservedExactly() throws {
    let next = "https://api.weather.gov/stations?cursor=abc%2B123"
    let body = Data(#"{"features":[],"pagination":{"next":"\#(next)"}}"#.utf8)

    let collection = try JSONDecoder().decode(
      FeatureCollection<ObservationStation>.self, from: body)

    #expect(collection.pagination?.next == next)
  }

  @Test("Next endpoints preserve encoded paths and representation headers")
  func nextEndpointsPreserveEncodedPathsAndRepresentationHeaders() throws {
    let endpoint = try #require(
      Endpoint<FeatureCollection<ObservationStation>>(
        accept: .init(rawValue: "application/ld+json"), featureFlags: [.init(rawValue: "future")],
        path: "/stations"))
    let next = try PaginationInfo(next: "https://api.weather.gov:443/stations?cursor=a%2Fb%3D")
      .nextEndpoint(after: endpoint)
    #expect(next.path == "/stations?cursor=a%2Fb%3D")
    #expect(next.accept == endpoint.accept)
    #expect(next.featureFlags == endpoint.featureFlags)
  }

  @Test(
    "Next endpoints reject missing and disallowed links",
    arguments: [
      nil, "", "bad link %", "/stations", "http://api.weather.gov/stations",
      "https://example.com/stations", "https://user@api.weather.gov/stations",
      "https://api.weather.gov:444/stations", "https://api.weather.gov/stations#part",
    ] as [String?])
  func nextEndpointsRejectMissingAndDisallowedLinks(raw: String?) throws {
    let expected = raw.map { NWSPaginationError.invalidNext($0) } ?? .missingNext
    #expect(throws: expected) {
      try PaginationInfo(next: raw).nextEndpoint(
        after: try #require(Endpoint<Int>(path: "/stations")))
    }
  }
}

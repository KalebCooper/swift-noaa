import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Glossary decoding and description", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct GlossaryTests {
  @Test("A consumer-defined glossary response decodes through a request endpoint")
  func aConsumerDefinedGlossaryResponseDecodesThroughARequestEndpoint() throws {
    let endpoint = try #require(Endpoint<GlossaryTerms>(accept: .jsonLD, path: "/glossary"))
    let request = WeatherRequest(endpoint: endpoint)
    #expect(request.resolution == .endpoint(endpoint))
    let terms = try JSONDecoder().decode(GlossaryTerms.self, from: Fixture.glossary.data())
    #expect(terms.glossary.count == 3183)
    #expect(terms.glossary.first == GlossaryTerms.Term(term: "1-2-3 Rule"))
  }

  @Test(
    "A glossary body without an entry array fails to decode",
    arguments: [
      #"{"@context":[]}"#, #"{"@context":[],"glossary":null}"#,
      #"{"@context":[],"glossary":{}}"#, #"{"@context":[],"glossary":["AGL"]}"#,
    ])
  func aGlossaryBodyWithoutAnEntryArrayFailsToDecode(body: String) {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(WeatherGlossary.self, from: Data(body.utf8))
    }
  }

  @Test(
    "A glossary entry missing a required field fails to decode",
    arguments: [#"{"term":"AGL"}"#, #"{"definition":"Above Ground Level"}"#, "{}"])
  func aGlossaryEntryMissingARequiredFieldFailsToDecode(entry: String) {
    let body = Data(#"{"@context":[],"glossary":[\#(entry)]}"#.utf8)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(WeatherGlossary.self, from: body)
    }
  }

  @Test("A recorded glossary decodes every entry in service order")
  func aRecordedGlossaryDecodesEveryEntryInServiceOrder() throws {
    let glossary = try JSONDecoder().decode(WeatherGlossary.self, from: Fixture.glossary.data())
    #expect(glossary.entries.count == 3183)
    #expect(glossary.entries.first?.term == "1-2-3 Rule")
    #expect(glossary.entries[81].term == "Agglomerate")
    #expect(glossary.entries[84].term == "AGN")
    #expect(glossary.entries.last?.term == "Z\\/R Relationship")
    #expect(
      glossary.entries.last?.definition
        == "An empirical relationship between radar reflectivity factor z (in mm^6 / m^3 ) and "
        + "rain rate ( in mm / hr ), usually expressed as Z = A R^b; A and b are empirical "
        + "constants. ")
  }

  @Test("A recorded glossary round-trips through its encoded form")
  func aRecordedGlossaryRoundTripsThroughItsEncodedForm() throws {
    let glossary = try JSONDecoder().decode(WeatherGlossary.self, from: Fixture.glossary.data())
    let encoded = try JSONEncoder().encode(glossary)
    #expect(try JSONDecoder().decode(WeatherGlossary.self, from: encoded) == glossary)
    let object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect((object["glossary"] as? [Any])?.count == 3183)
  }

  @Test("An explicitly empty glossary array decodes as no entries")
  func anExplicitlyEmptyGlossaryArrayDecodesAsNoEntries() throws {
    let body = Data(#"{"@context":[],"glossary":[]}"#.utf8)
    #expect(
      try JSONDecoder().decode(WeatherGlossary.self, from: body) == WeatherGlossary(entries: []))
  }

  @Test("Duplicate glossary terms keep the service's order and spacing")
  func duplicateGlossaryTermsKeepTheServicesOrderAndSpacing() throws {
    let glossary = try JSONDecoder().decode(WeatherGlossary.self, from: Fixture.glossary.data())
    #expect(
      glossary.entries.enumerated().filter { $0.element.term == "AGL" }.map(\.offset) == [82, 83])
    #expect(
      glossary.entries[82] == GlossaryEntry(definition: "Above Ground Level", term: "AGL"))
    #expect(
      glossary.entries[83] == GlossaryEntry(definition: "Above Ground Level ", term: "AGL"))
    #expect(Set(glossary.entries.map(\.term)).count == 3175)
  }

  @Test("Glossary definitions keep their markup, entities, and line endings")
  func glossaryDefinitionsKeepTheirMarkupEntitiesAndLineEndings() throws {
    let glossary = try JSONDecoder().decode(WeatherGlossary.self, from: Fixture.glossary.data())
    #expect(glossary.entries[6].term == "A")
    #expect(
      glossary.entries[6].definition
        == """
        1. Abbrevation for hail in weather observations.\r
        <br>\r
        <br>\r
        2. Symbol used on long-term climate outlooks issued by CPC to indicate areas that are \
        likely to be above normal for the specified parameter (temperature, precipitation, etc.).
        """)
    #expect(glossary.entries[293].term == "Base Reflectivity")
    #expect(glossary.entries[293].definition.contains("(&frac12;&deg; elevation)"))
    #expect(glossary.entries.count(where: { $0.definition.contains("\r\n") }) == 594)
  }

  @Test("The glossary endpoint and request describe one path without a query")
  func theGlossaryEndpointAndRequestDescribeOnePathWithoutAQuery() {
    #expect(Endpoint.glossary.path == "/glossary")
    #expect(!Endpoint.glossary.path.contains("?"))
    #expect(Endpoint.glossary.accept == .jsonLD)
    #expect(Endpoint.glossary.featureFlags.isEmpty)
    let stored = WeatherRequest.glossary
    #expect(stored.resolution == .endpoint(.glossary))
    #expect(WeatherRequest.weatherTerms == stored)
  }
}

private struct GlossaryTerms: Decodable, Equatable, Sendable {
  var glossary: [Term]

  struct Term: Decodable, Equatable, Sendable {
    var term: String
  }
}

extension WeatherRequest where Response == WeatherGlossary {
  fileprivate static var weatherTerms: Self { .glossary }
}

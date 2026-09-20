import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Office and headline decoding", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct OfficeTests {
  @Test("A consumer-defined office response decodes through a request endpoint")
  func aConsumerDefinedOfficeResponseDecodesThroughARequestEndpoint() throws {
    let endpoint = try #require(Endpoint<OfficeName>(accept: .jsonLD, path: "/offices/EWX"))
    let request = WeatherRequest(endpoint: endpoint)
    #expect(request.resolution == .endpoint(endpoint))
    let office = try JSONDecoder().decode(OfficeName.self, from: Fixture.office.data())
    #expect(office == OfficeName(id: "EWX", name: "Austin/San Antonio, TX"))
  }

  @Test(
    "A headline body missing a required field fails to decode",
    arguments: [
      #"{"title":"Update on ENSO"}"#, #"{"id":"ab45482ca5f57ff412eb1320721d5ac9"}"#, "{}",
    ])
  func aHeadlineBodyMissingARequiredFieldFailsToDecode(body: String) {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(OfficeHeadline.self, from: Data(body.utf8))
    }
  }

  @Test("A headline with a malformed issuance time fails to decode")
  func aHeadlineWithAMalformedIssuanceTimeFailsToDecode() {
    let body = #"{"id":"a","title":"t","issuanceTime":"the end of June"}"#
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(OfficeHeadline.self, from: Data(body.utf8))
    }
  }

  @Test(
    "A headline keeps an empty or plain text link exactly as sent",
    arguments: ["", "Visit ready.gov for more"])
  func aHeadlineKeepsAnEmptyOrPlainTextLinkExactlyAsSent(link: String) throws {
    let linkJSON = String(decoding: try JSONEncoder().encode(link), as: UTF8.self)
    let body = Data(
      (#"{"@context":[],"@graph":[{"id":"a","title":"Update","link":"#
        + linkJSON
        + #"},{"id":"b","title":"Preparedness","link":"https://www.ready.gov/"}]}"#).utf8)
    let headlines = try JSONDecoder().decode(OfficeHeadlines.self, from: body)
    #expect(headlines.headlines.map(\.id) == ["a", "b"])
    #expect(headlines.headlines.first?.link == link)
    #expect(headlines.headlines.last?.link == "https://www.ready.gov/")
  }

  @Test(
    "A headline list without a headline array fails to decode",
    arguments: [
      #"{"@context":[]}"#, #"{"@context":[],"@graph":null}"#, #"{"@context":[],"@graph":{}}"#,
      #"{"@context":[],"@graph":["ensostorymap"]}"#,
    ])
  func aHeadlineListWithoutAHeadlineArrayFailsToDecode(body: String) {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(OfficeHeadlines.self, from: Data(body.utf8))
    }
  }

  @Test("A headline's identity URL becomes a validated endpoint and its link does not")
  func aHeadlinesIdentityURLBecomesAValidatedEndpointAndItsLinkDoesNot() throws {
    let headline = try JSONDecoder().decode(
      OfficeHeadline.self, from: Fixture.officeHeadline.data())
    let identity = try #require(headline.url)
    let endpoint = try #require(Endpoint<OfficeHeadline>(accept: .jsonLD, link: identity))
    #expect(endpoint.path == "/offices/EWX/headlines/ab45482ca5f57ff412eb1320721d5ac9")
    #expect(endpoint.accept == .jsonLD)
    #expect(
      headline.link == "https://storymaps.arcgis.com/stories/c211dd9f2fb84c918f2c1e7753e76eb0")
    let editorial = try #require(headline.link.flatMap { URL(string: $0) })
    #expect(Endpoint<OfficeHeadline>(accept: .jsonLD, link: editorial) == nil)
  }

  @Test(
    "An office body missing a required field fails to decode",
    arguments: [#"{"name":"Austin/San Antonio, TX"}"#, #"{"id":"EWX"}"#, "{}"])
  func anOfficeBodyMissingARequiredFieldFailsToDecode(body: String) {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(WeatherOffice.self, from: Data(body.utf8))
    }
  }

  @Test("A recorded headline decodes its null summary, markup, and external link")
  func aRecordedHeadlineDecodesItsNullSummaryMarkupAndExternalLink() throws {
    let headline = try JSONDecoder().decode(
      OfficeHeadline.self, from: Fixture.officeHeadline.data())
    #expect(headline.id == "ab45482ca5f57ff412eb1320721d5ac9")
    #expect(headline.title == "Update on ENSO and Impacts on South-Central Texas")
    #expect(headline.name == "ensostorymap")
    #expect(headline.important == false)
    #expect(headline.summary == nil)
    #expect(headline.issuanceTime == Date(timeIntervalSince1970: 1_782_851_340))
    #expect(headline.office == URL(string: "https://api.weather.gov/offices/EWX"))
    #expect(
      headline.url
        == URL(
          string: "https://api.weather.gov/offices/EWX/headlines/ab45482ca5f57ff412eb1320721d5ac9"))
    #expect(
      headline.link == "https://storymaps.arcgis.com/stories/c211dd9f2fb84c918f2c1e7753e76eb0")
    #expect(
      headline.content
        == #"<a href="storymaps.arcgis.com%2Fstories%2Fc211dd9f2fb84c918f2c1e7753e76eb0">"#
        + "Update on ENSO and Impacts on South-Central Texas</a>")
  }

  @Test("A recorded headline round-trips through its encoded form")
  func aRecordedHeadlineRoundTripsThroughItsEncodedForm() throws {
    let headline = try JSONDecoder().decode(
      OfficeHeadline.self, from: Fixture.officeHeadline.data())
    let encoded = try JSONEncoder().encode(headline)
    #expect(try JSONDecoder().decode(OfficeHeadline.self, from: encoded) == headline)
    let object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(object["@id"] as? String == headline.url?.absoluteString)
    #expect(object["summary"] == nil)
  }

  @Test(
    "A recorded headline list decodes the count the service sent",
    arguments: [(Fixture.officeHeadlines, 2), (Fixture.officeHeadlinesEmpty, 0)])
  func aRecordedHeadlineListDecodesTheCountTheServiceSent(fixture: Fixture, count: Int) throws {
    let headlines = try JSONDecoder().decode(OfficeHeadlines.self, from: fixture.data())
    #expect(headlines.headlines.count == count)
  }

  @Test("A recorded headline list keeps the service's order")
  func aRecordedHeadlineListKeepsTheServicesOrder() throws {
    let headlines = try JSONDecoder().decode(
      OfficeHeadlines.self, from: Fixture.officeHeadlines.data())
    #expect(headlines.headlines.map(\.name) == ["ensostorymap", "nationalpreparednessmonth"])
    #expect(headlines.headlines.first?.id == "ab45482ca5f57ff412eb1320721d5ac9")
    let second = try #require(headlines.headlines.last)
    #expect(second.id == "315e4d30d129260546d5cd18017ab76e")
    #expect(second.title == "September is National Preparedness Month")
    #expect(second.issuanceTime == Date(timeIntervalSince1970: 1_788_318_000))
    #expect(second.link == "https://www.ready.gov/")
    #expect(second.summary == nil)
    #expect(
      second.content
        == #"<a href="https%3A%2F%2Fwww.ready.gov%2F">September is National Preparedness Month</a>"#
    )
  }

  @Test("A recorded office decodes its address and contact details")
  func aRecordedOfficeDecodesItsAddressAndContactDetails() throws {
    let office = try JSONDecoder().decode(WeatherOffice.self, from: Fixture.office.data())
    #expect(office.id == "EWX")
    #expect(office.name == "Austin/San Antonio, TX")
    #expect(office.nwsRegion == "sr")
    #expect(office.telephone == "(830) 629-0130")
    #expect(office.email == "sr-ewx.webmaster@noaa.gov")
    #expect(office.faxNumber == "")
    #expect(office.sameAs == "https://www.weather.gov/ewx")
    #expect(office.url == URL(string: "https://api.weather.gov/offices/EWX"))
    #expect(office.parentOrganization == URL(string: "https://api.weather.gov/offices/SRH"))
    #expect(
      office.address
        == WeatherOffice.Address(
          addressLocality: "New Braunfels", addressRegion: "TX", postalCode: "78130",
          streetAddress: "2090 Airport Road"))
  }

  @Test("A recorded office decodes its zone and station lists in service order")
  func aRecordedOfficeDecodesItsZoneAndStationListsInServiceOrder() throws {
    let office = try JSONDecoder().decode(WeatherOffice.self, from: Fixture.office.data())
    #expect(office.responsibleCounties?.count == 33)
    #expect(
      office.responsibleCounties?.first
        == URL(string: "https://api.weather.gov/zones/county/TXC013"))
    #expect(
      office.responsibleCounties?.last == URL(string: "https://api.weather.gov/zones/county/TXC507")
    )
    #expect(office.responsibleFireZones?.count == 33)
    #expect(
      office.responsibleFireZones?.first == URL(string: "https://api.weather.gov/zones/fire/TXZ171")
    )
    #expect(office.responsibleForecastZones?.count == 33)
    #expect(
      office.responsibleForecastZones?.last
        == URL(string: "https://api.weather.gov/zones/forecast/TXZ228"))
    #expect(office.approvedObservationStations?.count == 63)
    #expect(
      office.approvedObservationStations?.first
        == URL(string: "https://api.weather.gov/stations/K11R"))
    #expect(
      office.approvedObservationStations?.last
        == URL(string: "https://api.weather.gov/stations/KVCT"))
  }

  @Test("A recorded office round-trips through its encoded form")
  func aRecordedOfficeRoundTripsThroughItsEncodedForm() throws {
    let office = try JSONDecoder().decode(WeatherOffice.self, from: Fixture.office.data())
    let encoded = try JSONEncoder().encode(office)
    #expect(try JSONDecoder().decode(WeatherOffice.self, from: encoded) == office)
    let object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(object["@id"] as? String == "https://api.weather.gov/offices/EWX")
    #expect(object["faxNumber"] as? String == "")
    #expect((object["approvedObservationStations"] as? [Any])?.count == 63)
  }

  @Test("An office and headline without optional fields decode as nil")
  func anOfficeAndHeadlineWithoutOptionalFieldsDecodeAsNil() throws {
    let office = try JSONDecoder().decode(
      WeatherOffice.self, from: Data(#"{"id":"EWX","name":"Austin/San Antonio, TX"}"#.utf8))
    #expect(office == WeatherOffice(id: "EWX", name: "Austin/San Antonio, TX"))
    #expect(office.address == nil)
    #expect(office.faxNumber == nil)
    #expect(office.url == nil)
    let headline = try JSONDecoder().decode(
      OfficeHeadline.self, from: Data(#"{"id":"a","title":"Update"}"#.utf8))
    #expect(headline == OfficeHeadline(id: "a", title: "Update"))
    #expect(headline.important == nil)
    #expect(headline.issuanceTime == nil)
    #expect(headline.link == nil)
  }

  @Test("An explicitly empty headline array decodes as no headlines")
  func anExplicitlyEmptyHeadlineArrayDecodesAsNoHeadlines() throws {
    let body = Data(#"{"@context":[],"@graph":[]}"#.utf8)
    #expect(
      try JSONDecoder().decode(OfficeHeadlines.self, from: body) == OfficeHeadlines(headlines: []))
  }

  @Test(
    "An office keeps an empty or plain text website exactly as sent",
    arguments: ["", "www.weather.gov ewx"])
  func anOfficeKeepsAnEmptyOrPlainTextWebsiteExactlyAsSent(website: String) throws {
    let websiteJSON = String(decoding: try JSONEncoder().encode(website), as: UTF8.self)
    let body = Data(
      (#"{"id":"EWX","name":"Austin/San Antonio, TX","sameAs":"# + websiteJSON + "}").utf8)
    let office = try JSONDecoder().decode(WeatherOffice.self, from: body)
    #expect(office.sameAs == website)
    #expect(office.id == "EWX")
  }

  @Test("Office endpoints reject an identifier they cannot encode")
  func officeEndpointsRejectAnIdentifierTheyCannotEncode() {
    #expect(Endpoint.office(identifier: "") == nil)
    #expect(Endpoint.officeHeadlines(officeIdentifier: "") == nil)
    #expect(Endpoint.officeHeadline(identifier: "a", officeIdentifier: "") == nil)
    #expect(Endpoint.officeHeadline(identifier: "", officeIdentifier: "EWX") == nil)
  }

  @Test("Office endpoints encode each identifier as one path segment")
  func officeEndpointsEncodeEachIdentifierAsOnePathSegment() {
    #expect(Endpoint.office(identifier: "EWX")?.path == "/offices/EWX")
    #expect(Endpoint.office(identifier: "ewx")?.path == "/offices/ewx")
    #expect(Endpoint.office(identifier: "E/X?a=b")?.path == "/offices/E%2FX%3Fa%3Db")
    #expect(Endpoint.officeHeadlines(officeIdentifier: "EWX")?.path == "/offices/EWX/headlines")
    #expect(
      Endpoint.officeHeadline(identifier: "a/b", officeIdentifier: "EWX")?.path
        == "/offices/EWX/headlines/a%2Fb")
  }

  @Test("The office endpoints and requests describe one JSON-LD path each")
  func theOfficeEndpointsAndRequestsDescribeOneJSONLDPathEach() throws {
    let office = try #require(Endpoint.office(identifier: "EWX"))
    let headlines = try #require(Endpoint.officeHeadlines(officeIdentifier: "EWX"))
    let headline = try #require(
      Endpoint.officeHeadline(
        identifier: "ab45482ca5f57ff412eb1320721d5ac9", officeIdentifier: "EWX"))
    #expect(headline.path == "/offices/EWX/headlines/ab45482ca5f57ff412eb1320721d5ac9")
    for path in [office.path, headlines.path, headline.path] {
      #expect(!path.contains("?"))
    }
    #expect(office.accept == .jsonLD)
    #expect(headlines.accept == .jsonLD)
    #expect(headline.accept == .jsonLD)
    #expect(office.featureFlags.isEmpty)
    #expect(headlines.featureFlags.isEmpty)
    #expect(headline.featureFlags.isEmpty)
    #expect(WeatherRequest.office(identifier: "EWX").resolution == .office(identifier: "EWX"))
    #expect(
      WeatherRequest.officeHeadlines(officeIdentifier: "EWX").resolution
        == .officeHeadlines(officeIdentifier: "EWX"))
    #expect(
      WeatherRequest.officeHeadline(identifier: "a", officeIdentifier: "EWX").resolution
        == .officeHeadline(identifier: "a", officeIdentifier: "EWX"))
    #expect(WeatherRequest.austinSanAntonio == WeatherRequest.office(identifier: "EWX"))
  }
}

private struct OfficeName: Decodable, Equatable, Sendable {
  var id: String
  var name: String
}

extension WeatherRequest where Response == WeatherOffice {
  fileprivate static var austinSanAntonio: Self { .office(identifier: "EWX") }
}

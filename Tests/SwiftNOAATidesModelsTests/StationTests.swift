import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Coastal stations", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct StationTests {
  @Test("Directory recordings preserve order and null resource links")
  func directoryRecordingsPreserveOrderAndNullResourceLinks() throws {
    let response = try JSONDecoder().decode(
      CoastalStations.self, from: Fixture.stationsTidePredictions.data())
    #expect(response.count == 3499)
    #expect(response.stations.count == 3499)
    let station = try #require(response.stations.first)
    #expect(station.identifier == "1610367")
    #expect(station.kind == .subordinate)
    #expect(station.referenceIdentifier == "1612340")
    #expect(station.affiliations == "")
    #expect(station.products == nil)
    #expect(station.timeMeridian == -150)
    #expect(
      try JSONDecoder().decode(CoastalStations.self, from: JSONEncoder().encode(response))
        == response)
  }

  @Test("Detail recordings retain names and capability metadata")
  func detailRecordingsRetainNamesAndCapabilityMetadata() throws {
    let response = try JSONDecoder().decode(CoastalStations.self, from: Fixture.station.data())
    let station = try #require(response.stations.first)
    #expect(station.name == "San Francisco")
    #expect(station.latitude == 37.806305)
    #expect(station.longitude == -122.46589)
    #expect(station.timeZone == "PST")
    #expect(station.timeZoneCorrection == -8)
    #expect(station.tidal == true)
    #expect(
      station.datums?.url
        == "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations/9414290/datums.json")
    #expect(response.units == nil)
    #expect(response.url == nil)
  }

  @Test(
    "Endpoints reject invalid paths and origins",
    arguments: [
      "//evil.com/a", "/a/../b", "/%2e%2e/b", "/%2f/evil", "/a%5Cb", "/a%00b",
      "/a b", "/a#b", "/a%", "/a%zz", "https://evil.com", "/a\\b",
    ])
  func endpointsRejectInvalidPathsAndOrigins(path: String) {
    #expect(TidesEndpoint<CoastalStations>(path: path) == nil)
  }

  @Test(
    "Foreign links and credentials cannot become endpoints",
    arguments: [
      "http://api.tidesandcurrents.noaa.gov/x", "https://evil.com/x",
      "https://api.tidesandcurrents.noaa.gov:444/x",
      "https://user@api.tidesandcurrents.noaa.gov/x",
      "https://api.tidesandcurrents.noaa.gov/x#fragment",
    ])
  func foreignLinksAndCredentialsCannotBecomeEndpoints(link: String) throws {
    #expect(TidesEndpoint<CoastalStations>(link: try #require(URL(string: link))) == nil)
  }

  @Test(
    "Identifiers reject invalid input", arguments: ["", " ", "../x", "a/b", "a?b", "a%20b", "a\nb"])
  func identifiersRejectInvalidInput(rawValue: String) {
    #expect(throws: TidesQueryError.self) { try CoastalStationIdentifier(rawValue) }
  }

  @Test(
    "Malformed envelopes do not become empty directories",
    arguments: ["{}", "{\"stations\":null}", "{\"count\":0}", "{\"count\":0,\"stations\":{}}"])
  func malformedEnvelopesDoNotBecomeEmptyDirectories(body: String) {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(CoastalStations.self, from: Data(body.utf8))
    }
  }

  @Test("Requests support consumer enums and retain concrete inference")
  func requestsSupportConsumerEnumsAndRetainConcreteInference() throws {
    enum Category: String { case custom = "future&kind" }
    let query = try CoastalStationQuery(type: Category.custom)
    let request = TidesRequest.stations(matching: query)
    #expect(request == TidesRequest<CoastalStations>.stations(matching: query))
    guard case .endpoint(let endpoint) = request.resolution else {
      Issue.record("Expected endpoint"); return
    }
    #expect(endpoint.path == "/mdapi/prod/webapi/stations.json?type=future%26kind")
    #expect(try CoastalStationIdentifier("cb0102").rawValue == "cb0102")
    #expect(try CoastalStationIdentifier("A_9-b").rawValue == "A_9-b")
  }

  @Test("Unknown station kinds remain open")
  func unknownStationKindsRemainOpen() throws {
    let kind = try JSONDecoder().decode(CoastalStationKind.self, from: Data("\"future\"".utf8))
    #expect(kind.rawValue == "future")
  }
}

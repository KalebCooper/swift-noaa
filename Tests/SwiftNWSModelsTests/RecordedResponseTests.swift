import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Decoding recorded responses", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct RecordedResponseTests {
  @Test("An observation decodes its readings, its missing readings, and its timestamp")
  func anObservationDecodesItsReadingsItsMissingReadingsAndItsTimestamp() throws {
    let observation = try JSONDecoder().decode(
      Feature<WeatherObservation>.self, from: Fixture.observation.data()
    ).properties

    #expect(observation.stationId == "KATT")
    #expect(observation.stationName == "Austin City Austin Camp Mabry")
    #expect(observation.textDescription == "Clear")
    #expect(
      observation.temperature
        == QuantitativeValue(qualityControl: "V", unitCode: "wmoUnit:degC", value: 37.8))
    #expect(
      observation.windChill
        == QuantitativeValue(qualityControl: "V", unitCode: "wmoUnit:degC", value: nil))
    // 2026-09-13T19:51:00+00:00
    #expect(observation.timestamp == Date(timeIntervalSince1970: 1_789_329_060))
  }

  @Test("An observation decodes the same under any date decoding strategy")
  func anObservationDecodesTheSameUnderAnyDateDecodingStrategy() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970

    let observation = try decoder.decode(
      Feature<WeatherObservation>.self, from: Fixture.observation.data()
    ).properties

    #expect(observation.timestamp == Date(timeIntervalSince1970: 1_789_329_060))
  }

  @Test("An observation encodes its timestamp as an ISO 8601 string")
  func anObservationEncodesItsTimestampAsAnISO8601String() throws {
    let observation = WeatherObservation(
      stationId: "KATT", timestamp: Date(timeIntervalSince1970: 1_789_329_060))

    let json = try #require(String(data: JSONEncoder().encode(observation), encoding: .utf8))

    #expect(json.contains(#""timestamp":"2026-09-13T19:51:00Z""#))
  }

  @Test("A point decodes its grid, links, and nearest city")
  func aPointDecodesItsGridLinksAndNearestCity() throws {
    let point = try JSONDecoder().decode(Feature<Point>.self, from: Fixture.point.data())

    #expect(point.id?.absoluteString == "https://api.weather.gov/points/30.2672,-97.7431")
    #expect(point.properties.gridId == "EWX")
    #expect(point.properties.gridX == 156)
    #expect(point.properties.gridY == 91)
    #expect(
      point.properties.observationStations.absoluteString
        == "https://api.weather.gov/gridpoints/EWX/156,91/stations")
    #expect(
      point.properties.relativeLocation?.properties
        == Point.RelativeLocation(city: "Austin", state: "TX"))
    #expect(point.properties.timeZone == "America/Chicago")
  }

  @Test("A station collection decodes every station in service order")
  func aStationCollectionDecodesEveryStationInServiceOrder() throws {
    let stations = try JSONDecoder().decode(
      FeatureCollection<ObservationStation>.self, from: Fixture.observationStations.data())

    #expect(stations.features.count == 64)
    #expect(
      stations.features.first?.properties
        == ObservationStation(
          elevation: QuantitativeValue(unitCode: "wmoUnit:m", value: 199.9488),
          name: "Austin City Austin Camp Mabry",
          stationIdentifier: "KATT",
          timeZone: "America/Chicago"
        ))
  }

  @Test("Problem details decode the status, title, and correlation identifier")
  func problemDetailsDecodeTheStatusTitleAndCorrelationIdentifier() throws {
    let problem = try JSONDecoder().decode(ProblemDetail.self, from: Fixture.problemDetail.data())

    #expect(
      problem
        == ProblemDetail(
          correlationId: "308408e8",
          detail: "Unable to provide data for requested point 0,0",
          instance: "https://api.weather.gov/requests/308408e8",
          status: 404,
          title: "Data Unavailable For Requested Point",
          type: "https://api.weather.gov/problems/InvalidPoint"
        ))
  }

  @Test("Unknown unit and quality codes survive decoding with a missing measurement")
  func unknownUnitAndQualityCodesSurviveDecodingWithAMissingMeasurement() throws {
    let body = Data(
      #"{"qualityControl":"future-quality","unitCode":"wmoUnit:future","value":null}"#.utf8)
    let value = try JSONDecoder().decode(QuantitativeValue.self, from: body)
    #expect(value.qualityControl == "future-quality")
    #expect(value.unitCode == "wmoUnit:future")
    #expect(value.value == nil)
  }
}

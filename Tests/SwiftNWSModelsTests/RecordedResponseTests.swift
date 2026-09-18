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
        == QuantitativeValue(qualityControl: .verified, unitCode: "wmoUnit:degC", value: 37.8))
    #expect(
      observation.windChill
        == QuantitativeValue(qualityControl: .verified, unitCode: "wmoUnit:degC", value: nil))
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

  @Test("Observation history decodes every observation in service order with its continuation link")
  func observationHistoryDecodesEveryObservationInServiceOrderWithItsContinuationLink() throws {
    let history = try JSONDecoder().decode(
      FeatureCollection<WeatherObservation>.self, from: Fixture.observationHistory.data())
    // 2026-09-16T23:51:00+00:00 then 2026-09-16T22:51:00+00:00, as the service listed them.
    #expect(
      history.features.map(\.properties.timestamp) == [
        Date(timeIntervalSince1970: 1_789_602_660), Date(timeIntervalSince1970: 1_789_599_060),
      ])
    #expect(history.features.allSatisfy { $0.properties.stationId == "KATT" })
    #expect(history.features.first?.properties.temperature?.value == 35.6)
    #expect(
      history.pagination?.next
        == "https://api.weather.gov/stations/KATT/observations"
        + "?cursor=eyJzIjoiMjAyNi0wOS0xNlQyMjo1MTowMCswMDowMCJ9")
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
          bearing: QuantitativeValue(unitCode: "wmoUnit:degree_(angle)", value: 339),
          county: URL(string: "https://api.weather.gov/zones/county/TXC453"),
          distance: QuantitativeValue(unitCode: "wmoUnit:m", value: 5975.7495213949),
          elevation: QuantitativeValue(unitCode: "wmoUnit:m", value: 199.9488),
          fireWeatherZone: URL(string: "https://api.weather.gov/zones/fire/TXZ192"),
          forecast: URL(string: "https://api.weather.gov/zones/forecast/TXZ192"),
          name: "Austin City Austin Camp Mabry",
          provider: "ASOS",
          stationIdentifier: "KATT",
          subProvider: "",
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

  @Test("Problem details keep every parameter error the service listed")
  func problemDetailsKeepEveryParameterErrorTheServiceListed() throws {
    let problem = try JSONDecoder().decode(
      ProblemDetail.self, from: Fixture.unknownRegionProblem.data())

    #expect(
      problem
        == ProblemDetail(
          correlationId: "124b9aed",
          detail: "Not Found",
          instance: "https://api.weather.gov/requests/124b9aed",
          parameterErrors: [
            ProblemDetail.ParameterError(
              message: #"Does not have a value in the enumeration ["AL","AT","GL","GM","PA","PI"]"#,
              parameter: "path.region")
          ],
          status: 404,
          title: "Not Found",
          type: "https://api.weather.gov/problems/NotFound"
        ))
  }

  @Test("Unknown unit and quality codes survive decoding with a missing measurement")
  func unknownUnitAndQualityCodesSurviveDecodingWithAMissingMeasurement() throws {
    let body = Data(
      #"{"qualityControl":"future-quality","unitCode":"wmoUnit:future","value":null}"#.utf8)
    let value = try JSONDecoder().decode(QuantitativeValue.self, from: body)
    #expect(value.qualityControl?.rawValue == "future-quality")
    #expect(value.unitCode == "wmoUnit:future")
    #expect(value.value == nil)
  }
}

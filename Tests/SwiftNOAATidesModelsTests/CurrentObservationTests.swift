import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Current observations and metadata", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct CurrentObservationTests {
  @Test("Bin tables preserve nullable fields and reported units")
  func binTablesPreserveNullableFieldsAndReportedUnits() throws {
    let metric = try JSONDecoder().decode(CurrentBins.self, from: Fixture.stationBins.data())
    #expect(metric.count == 15)
    #expect(metric.bins?.count == 15)
    #expect(metric.units == "meters")
    #expect(metric.binSize == 1)
    #expect(metric.centerOfFirstBinDistance == 1.4)
    #expect(metric.realTimeBin == 4)
    #expect(metric.bins?.first?.depth == 3.51)
    #expect(metric.bins?.first?.distance == nil)
    #expect(metric.bins?[3].isPublished == true)
    #expect(metric.bins?.first?.qualityFlag == 1)
    let english = try JSONDecoder().decode(CurrentBins.self, from: Fixture.binsEnglish.data())
    #expect(english.units == "feet")
    #expect(english.bins?.first?.depth == 11.5)
    let survey = try JSONDecoder().decode(CurrentBins.self, from: Fixture.binsSurvey.data())
    #expect(survey.realTimeBin == nil)
    #expect(survey.bins?.first?.pingInterval == 360)
    let absent = try JSONDecoder().decode(CurrentBins.self, from: Fixture.binsInvalid.data())
    #expect(absent.count == 0)
    #expect(absent.bins == nil)
    #expect(
      try JSONDecoder().decode(CurrentBins.self, from: JSONEncoder().encode(absent)) == absent)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(CurrentBins.self, from: Data(#"{"nbr_of_bins":0}"#.utf8))
    }
  }

  @Test("Current queries validate bins and calendar months without I/O")
  func currentQueriesValidateBinsAndCalendarMonthsWithoutIO() throws {
    let begin = try TidesTimestamp("2024-01-31 00:00").date
    let end = try TidesTimestamp("2024-02-29 00:00").date
    let station = try CoastalStationIdentifier("cb0102")
    let range = try TidesDateRange(begin: begin, end: end)
    let query = try CurrentObservationQuery(
      bin: .explicit(4), range: range, stationIdentifier: station, units: .metric)
    let request = TidesRequest.currentObservations(matching: query)
    let _: TidesRequest<CurrentObservations> = request
    #expect(request.resolution == .currentObservations(query))
    #expect(
      TidesEndpoint.currentObservations(matching: query).path
        == "/api/prod/datagetter?begin_date=20240131%2000:00&bin=4&end_date=20240229%2000:00&format=json&product=currents&station=cb0102&time_zone=gmt&units=metric"
    )
    for n in [0, -1] {
      #expect(throws: TidesQueryError.invalidBin(n)) {
        try CurrentObservationQuery(
          bin: .explicit(n), range: range, stationIdentifier: station, units: .metric)
      }
    }
    #expect(throws: TidesQueryError.rangeTooLong(maximumMonths: 1)) {
      try CurrentObservationQuery(
        bin: .providerDefault, range: TidesDateRange(begin: begin, end: end.addingTimeInterval(60)),
        stationIdentifier: station, units: .metric)
    }
    #expect(throws: TidesQueryError.invalidUnits("")) {
      try CurrentObservationQuery(
        bin: .providerDefault, range: range, stationIdentifier: station, units: .init(rawValue: ""))
    }
    #expect(
      try TidesEndpoint.currentBins(stationIdentifier: station, units: .english).path
        == "/mdapi/prod/webapi/stations/cb0102/bins.json?units=english")
    enum Category: String { case survey = "surveycurrents" }
    #expect(CoastalStationType(Category.survey) == .surveyCurrents)
    #expect(
      try TidesEndpoint.stations(matching: CoastalStationQuery(type: .historicCurrents)).path
        == "/mdapi/prod/webapi/stations.json?type=historiccurrents")
  }

  @Test("Current stations retain deployment text and resources")
  func currentStationsRetainDeploymentTextAndResources() throws {
    let ports = try JSONDecoder().decode(CoastalStations.self, from: Fixture.stationCurrent.data())
      .stations[0]
    #expect(ports.identifier == "cb0102")
    #expect(ports.project == "Chesapeake Bay South PORTS")
    #expect(ports.projectType == "PORTS")
    #expect(ports.deployed == "2025-01-27 15:00:00")
    #expect(ports.retrieved == "")
    #expect(ports.timeZoneOffset == "-5")
    #expect(ports.noaaChart == 12222)
    #expect(ports.heightFromBottom == 0)
    #expect(ports.bins != nil)
    #expect(ports.deployments != nil)
    let survey = try JSONDecoder().decode(CoastalStations.self, from: Fixture.stationSurvey.data())
      .stations[0]
    #expect(survey.retrieved == "2016-05-11 18:24:00")
    #expect(survey.noaaChart == nil)
    #expect(survey.centerOfFirstBinDistance == 2.11)
    #expect(
      try JSONDecoder().decode(CoastalStation.self, from: JSONEncoder().encode(survey)) == survey)
    let directory = try JSONDecoder().decode(
      CoastalStations.self, from: Fixture.stationsCurrents.data())
    #expect(!directory.stations.isEmpty)
  }

  @Test("Current wire records retain raw quantities and reported bins")
  func currentWireRecordsRetainRawQuantitiesAndReportedBins() throws {
    let ports = try JSONDecoder().decode(
      CurrentObservationResponse.self, from: Fixture.currentsPorts.data())
    #expect(ports.observations.count == 10)
    #expect(ports.observations.first?.speed.rawValue == "0.7")
    #expect(ports.observations.first?.direction.value == 214)
    #expect(ports.observations.first?.bin == "4")
    #expect(ports.observations.first?.time.rawValue == "2024-09-26 00:03")
    let survey = try JSONDecoder().decode(
      CurrentObservationResponse.self, from: Fixture.currentsSurvey.data())
    #expect(survey.observations.count == 11)
    #expect(survey.metadata.name == "null")
    #expect(survey.observations.first?.speed.value == 112.4)
    #expect(survey.observations.first?.bin == "9")
    let english = try JSONDecoder().decode(
      CurrentObservationResponse.self, from: Fixture.currentsEnglish.data())
    #expect(english.observations.first?.speed.rawValue == "0.014")
    #expect(
      try JSONDecoder().decode(CurrentObservationResponse.self, from: JSONEncoder().encode(ports))
        == ports)
  }

  @Test("Missing current quantities remain distinct from malformed numbers")
  func missingCurrentQuantitiesRemainDistinctFromMalformedNumbers() throws {
    let value = try JSONDecoder().decode(
      CurrentObservation.self,
      from: Data(#"{"b":"future","d":"","s":"","t":"2024-01-01 00:00"}"#.utf8))
    #expect(value.speed.value == nil)
    #expect(value.direction.rawValue == "")
    #expect(value.bin == "future")
    for body in [
      #"{"b":"1","d":"0","s":"NaN","t":"2024-01-01 00:00"}"#,
      #"{"b":"1","d":"0","s":null,"t":"2024-01-01 00:00"}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(CurrentObservation.self, from: Data(body.utf8))
      }
    }
    for body in ["{}", #"{"data":[],"metadata":null}"#] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(CurrentObservationResponse.self, from: Data(body.utf8))
      }
    }
    let empty = try JSONDecoder().decode(
      CurrentObservationResponse.self,
      from: Data(#"{"metadata":{"id":"x","name":"","lat":"0","lon":"0"},"data":[]}"#.utf8))
    #expect(empty.observations.isEmpty)
  }
}

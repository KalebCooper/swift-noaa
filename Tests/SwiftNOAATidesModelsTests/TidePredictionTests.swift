import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Sampled tides and datum models", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct TidePredictionTests {
  @Test("Datum metadata retain reported units epoch and reference text")
  func datumMetadataRetainReportedUnitsEpochAndReferenceText() throws {
    let value = try JSONDecoder().decode(CoastalDatums.self, from: Fixture.stationDatums.data())
    #expect(value.datums.count == 15)
    #expect(value.datums.first?.name == "STND")
    #expect(value.datums.first?.value == 0)
    #expect(value.datums.last?.description == "North American Vertical Datum of 1988")
    #expect(value.datums.last?.value == 1.804)
    #expect(value.epoch == "1983-2001")
    #expect(value.units == "meters")
    #expect(value.accepted == "Apr 17 2003")
    #expect(value.superseded == "")
    #expect(value.controlStation == "")
    #expect(value.ngsLink == "")
    #expect(value.orthometricDatum == "NAVD88")
    #expect(value.analysisPeriods == ["01/01/1983 - 12/31/2001"])
    #expect(value.disclaimers?.disclaimers.isEmpty == true)
    #expect(value.disclaimers?.selfLink == nil)
    #expect(value.leastAstronomicalTide == 1.2268009)
    #expect(value.highestAstronomicalTideTime == "18:24")
    #expect(value.maximumDate == "19830127")
    let english = try JSONDecoder().decode(
      CoastalDatums.self, from: Fixture.stationDatumsEnglish.data())
    #expect(english.units == "feet")
    #expect(english.datums.last?.value == 5.92)
    #expect(
      try JSONDecoder().decode(CoastalDatums.self, from: JSONEncoder().encode(value)) == value)
  }

  @Test("Malformed sampled and datum envelopes fail strictly")
  func malformedSampledAndDatumEnvelopesFailStrictly() throws {
    for body in [
      "{}", #"{"predictions":null}"#, #"{"predictions":[{"t":"2024-01-01 00:00","v":""}]}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(TidePredictionResponse.self, from: Data(body.utf8))
      }
    }
    for body in [
      "{}", #"{"datums":null}"#, #"{"datums":[{"name":"X","description":"unknown","value":"2"}]}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(CoastalDatums.self, from: Data(body.utf8))
      }
    }
    let custom = try JSONDecoder().decode(
      CoastalDatums.self,
      from: Data(
        #"{"datums":[{"name":"FUTURE","description":"custom","value":-2}],"disclaimers":{"disclaimers":[{"name":"notice","text":"Retain this text"}],"self":null}}"#
          .utf8))
    #expect(custom.datums.first?.name == "FUTURE")
    #expect(custom.disclaimers?.disclaimers.first?.text == "Retain this text")
  }

  @Test("Sample queries enforce supported cadences and calendar year bounds")
  func sampleQueriesEnforceSupportedCadencesAndCalendarYearBounds() throws {
    #expect(TidePredictionInterval(rawValue: 7) == nil)
    #expect(Set(TidePredictionInterval.allCases.map(\.rawValue)) == [1, 5, 6, 10, 15, 30, 60])
    let begin = try TidesTimestamp("2024-02-29 00:00").date
    let end = try TidesTimestamp("2025-02-28 00:00").date
    let station = try CoastalStationIdentifier("9414290")
    let query = try TidePredictionQuery(
      datum: .meanLowerLowWater, interval: .hourly,
      range: TidesDateRange(begin: begin, end: end), stationIdentifier: station, units: .metric)
    let request = TidesRequest.tidePredictions(matching: query)
    let _: TidesRequest<TidePredictions> = request
    #expect(request.resolution == .tidePredictions(query))
    #expect(Set([request, request]).count == 1)
    #expect(
      TidesEndpoint.tidePredictions(matching: query).path
        == "/api/prod/datagetter?begin_date=20240229%2000:00&datum=MLLW&end_date=20250228%2000:00&format=json&interval=60&product=predictions&station=9414290&time_zone=gmt&units=metric"
    )
    #expect(throws: TidesQueryError.rangeTooLong(maximumMonths: 12)) {
      try TidePredictionQuery(
        datum: .meanLowerLowWater, interval: .everyMinute,
        range: TidesDateRange(begin: begin, end: end.addingTimeInterval(60)),
        stationIdentifier: station, units: .metric)
    }
    #expect(throws: TidesQueryError.invalidUnits("")) {
      try TidesRequest.datums(stationIdentifier: station, units: .init(rawValue: ""))
    }
  }

  @Test("Sampled predictions preserve reported points and inclusive bounds")
  func sampledPredictionsPreserveReportedPointsAndInclusiveBounds() throws {
    let hourly = try JSONDecoder().decode(
      TidePredictionResponse.self, from: Fixture.tideHourly.data())
    #expect(hourly.predictions.count == 24)
    #expect(hourly.predictions.first?.height.value == 0.384)
    #expect(hourly.predictions.last?.time.rawValue == "2026-09-26 23:00")
    let six = try JSONDecoder().decode(
      TidePredictionResponse.self, from: Fixture.tideInclusive.data())
    #expect(six.predictions.count == 11)
    #expect(six.predictions.first?.time.rawValue == "2024-09-26 00:00")
    #expect(six.predictions.last?.time.rawValue == "2024-09-26 01:00")
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(HighLowTideResponse.self, from: Fixture.tideHourly.data())
    }
    #expect(
      try JSONDecoder().decode(TidePredictionResponse.self, from: Data(#"{"predictions":[]}"#.utf8))
        .predictions.isEmpty)
  }
}

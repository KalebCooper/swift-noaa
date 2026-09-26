import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Current prediction models", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct CurrentPredictionTests {
  @Test("Current event kinds remain open and null depths round trip")
  func currentEventKindsRemainOpenAndNullDepthsRoundTrip() throws {
    enum Kind: String { case future = "future" }
    #expect(CurrentEventKind(Kind.future).rawValue == "future")
    let body =
      #"{"Bin":"1","Depth":null,"Type":"future","meanEbbDir":242,"meanFloodDir":61,"Time":"2026-09-26 02:40","Velocity_Major":-0.3}"#
    let event = try JSONDecoder().decode(CurrentEvent.self, from: Data(body.utf8))
    #expect(event.kind.rawValue == "future")
    #expect(event.depth == nil)
    #expect(event.velocityMajor == -0.3)
    #expect(try JSONDecoder().decode(CurrentEvent.self, from: JSONEncoder().encode(event)) == event)
  }

  @Test("Current event queries fix max slack and validate calendar years")
  func currentEventQueriesFixMaxSlackAndValidateCalendarYears() throws {
    let begin = try TidesTimestamp("2024-02-29 00:00").date
    let end = try TidesTimestamp("2025-02-28 00:00").date
    let station = try CoastalStationIdentifier("PCT1291")
    let query = try CurrentEventQuery(
      bin: .providerDefault, range: TidesDateRange(begin: begin, end: end),
      stationIdentifier: station, units: .metric)
    let request = TidesRequest.currentEvents(matching: query)
    let _: TidesRequest<CurrentEvents> = request
    #expect(request.resolution == .currentEvents(query))
    #expect(
      TidesEndpoint.currentEvents(matching: query).path
        == "/api/prod/datagetter?begin_date=20240229%2000:00&end_date=20250228%2000:00&format=json&interval=max_slack&product=currents_predictions&station=PCT1291&time_zone=gmt&units=metric&vel_type=default"
    )
    #expect(throws: TidesQueryError.rangeTooLong(maximumMonths: 12)) {
      try CurrentEventQuery(
        bin: .providerDefault, range: TidesDateRange(begin: begin, end: end.addingTimeInterval(60)),
        stationIdentifier: station, units: .metric)
    }
    #expect(throws: TidesQueryError.invalidBin(0)) {
      try CurrentEventQuery(
        bin: .explicit(0), range: query.range, stationIdentifier: station, units: .metric)
    }
  }

  @Test("Current prediction queries permit only sampled cadences and calendar months")
  func currentPredictionQueriesPermitOnlySampledCadencesAndCalendarMonths() throws {
    let begin = try TidesTimestamp("2024-01-31 00:00").date
    let end = try TidesTimestamp("2024-02-29 00:00").date
    let station = try CoastalStationIdentifier("EPT0003")
    let range = try TidesDateRange(begin: begin, end: end)
    #expect(CurrentPredictionInterval.allCases.map(\.rawValue).sorted() == [1, 6, 10, 30, 60])
    #expect(CurrentPredictionInterval(rawValue: 5) == nil)
    #expect(CurrentPredictionMode(rawValue: "max_slack") == nil)
    let query = try CurrentPredictionQuery(
      bin: .explicit(14), interval: .everyTenMinutes, mode: .speedAndDirection, range: range,
      stationIdentifier: station, units: .english)
    let request = TidesRequest.currentPredictions(matching: query)
    let _: TidesRequest<CurrentPredictions> = request
    #expect(request.resolution == .currentPredictions(query))
    #expect(
      TidesEndpoint.currentPredictions(matching: query).path
        == "/api/prod/datagetter?begin_date=20240131%2000:00&bin=14&end_date=20240229%2000:00&format=json&interval=10&product=currents_predictions&station=EPT0003&time_zone=gmt&units=english&vel_type=speed_dir"
    )
    #expect(throws: TidesQueryError.rangeTooLong(maximumMonths: 1)) {
      try CurrentPredictionQuery(
        bin: .providerDefault, interval: .hourly, mode: .major,
        range: TidesDateRange(begin: begin, end: end.addingTimeInterval(60)),
        stationIdentifier: station, units: .metric)
    }
    #expect(throws: TidesQueryError.invalidBin(-1)) {
      try CurrentPredictionQuery(
        bin: .explicit(-1), interval: .hourly, mode: .major, range: range,
        stationIdentifier: station, units: .metric)
    }
    #expect(throws: TidesQueryError.invalidUnits("")) {
      try CurrentPredictionQuery(
        bin: .providerDefault, interval: .hourly, mode: .major, range: range,
        stationIdentifier: station, units: .init(rawValue: ""))
    }
  }

  @Test("Current prediction station metadata retains bin and offset links")
  func currentPredictionStationMetadataRetainsBinAndOffsetLinks() throws {
    let station = try JSONDecoder().decode(
      CoastalStations.self, from: Fixture.stationCurrentSubordinateActual.data()
    ).stations[0]
    #expect(station.identifier == "ACT0091")
    #expect(station.kind?.rawValue == "S")
    #expect(station.currentBin == 1)
    #expect(station.currentPredictionOffsets != nil)
    #expect(station.depth == nil)
    #expect(station.depthType == "U")
    let harmonic = try JSONDecoder().decode(
      CoastalStations.self, from: Fixture.stationCurrentHarmonic.data()
    ).stations[0]
    #expect(harmonic.identifier == "EPT0003")
    #expect(harmonic.bins != nil)
    #expect(
      try TidesEndpoint.stations(matching: CoastalStationQuery(type: .currentPredictions)).path
        == "/mdapi/prod/webapi/stations.json?type=currentpredictions")
  }

  @Test("Event and sampled envelopes reject malformed or mismatched shapes")
  func eventAndSampledEnvelopesRejectMalformedOrMismatchedShapes() throws {
    for body in [
      "{}", #"{"current_predictions":{}}"#, #"{"current_predictions":{"units":"x","cp":null}}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(CurrentEventResponse.self, from: Data(body.utf8))
      }
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(CurrentPredictionResponse.self, from: Data(body.utf8))
      }
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(CurrentEventResponse.self, from: Fixture.currentsMajor.data())
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        CurrentPredictionResponse.self, from: Fixture.currentPredictions.data())
    }
    let empty = Data(#"{"current_predictions":{"units":"future units","cp":[]}}"#.utf8)
    #expect(try JSONDecoder().decode(CurrentEventResponse.self, from: empty).events.isEmpty)
    #expect(
      try JSONDecoder().decode(CurrentPredictionResponse.self, from: empty).units == "future units")
  }

  @Test("Recorded current events retain signs directions and nonzero slack")
  func recordedCurrentEventsRetainSignsDirectionsAndNonzeroSlack() throws {
    let result = try JSONDecoder().decode(
      CurrentEventResponse.self, from: Fixture.currentPredictions.data())
    #expect(result.units == "meters, cm/s")
    #expect(result.events.count == 7)
    #expect(result.events.first?.kind == .slack)
    #expect(result.events.first?.velocityMajor == 0.1)
    #expect(result.events[3].velocityMajor == -159.4)
    #expect(result.events[3].kind == .ebb)
    #expect(result.events[1].kind == .flood)
    #expect(result.events.first?.meanEbbDirection == 242)
    #expect(result.events.first?.meanFloodDirection == 61)
    let harmonic = try JSONDecoder().decode(
      CurrentEventResponse.self, from: Fixture.currentEventsHarmonic.data())
    #expect(harmonic.events.first?.depth?.rawValue == "4")
    #expect(harmonic.events[1].velocityMajor == -0.4)
    let subordinate = try JSONDecoder().decode(
      CurrentEventResponse.self, from: Fixture.currentSubordinateEvents.data())
    #expect(!subordinate.events.isEmpty)
    #expect(
      try JSONDecoder().decode(CurrentEventResponse.self, from: JSONEncoder().encode(result))
        == result)
  }

  @Test("Sampled current velocities retain their actual representation")
  func sampledCurrentVelocitiesRetainTheirActualRepresentation() throws {
    let major = try JSONDecoder().decode(
      CurrentPredictionResponse.self, from: Fixture.currentsMajor.data())
    #expect(major.predictions.count == 7)
    #expect(
      major.predictions.first?.velocity
        == .major(meanEbbDirection: 90, meanFloodDirection: 260, velocity: -76.1))
    let ignoredMode = try JSONDecoder().decode(
      CurrentPredictionResponse.self, from: Fixture.currentsSpeedDirection.data())
    #expect(ignoredMode.predictions.first?.velocity == major.predictions.first?.velocity)
    let english = try JSONDecoder().decode(
      CurrentPredictionResponse.self, from: Fixture.currentsSpeedDirectionCurrent.data())
    #expect(english.units == "feet, knots")
    #expect(english.predictions.first?.depth?.rawValue == "13")
    #expect(
      english.predictions.first?.velocity
        == .speedAndDirection(direction: 261, speed: try TidesNumericValue("2.246")))
    let metric = try JSONDecoder().decode(
      CurrentPredictionResponse.self, from: Fixture.currentSpeedMetric.data())
    #expect(metric.units == "meters, cm/s")
    #expect(
      metric.predictions.first?.velocity
        == .speedAndDirection(direction: 261, speed: try TidesNumericValue("115.562")))
    #expect(
      try JSONDecoder().decode(CurrentPredictionResponse.self, from: JSONEncoder().encode(english))
        == english)
    #expect(
      try JSONDecoder().decode(CurrentPredictionResponse.self, from: JSONEncoder().encode(major))
        == major)
  }

  @Test("Velocity decoding rejects incomplete mixed and malformed representations")
  func velocityDecodingRejectsIncompleteMixedAndMalformedRepresentations() throws {
    for body in [
      "{}", #"{"Speed":"1"}"#, #"{"Speed":"NaN","Direction":1}"#,
      #"{"Speed":"1","Direction":null}"#, #"{"Velocity_Major":1}"#,
      #"{"Velocity_Major":1,"meanEbbDir":1,"meanFloodDir":2,"Speed":"1","Direction":2}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(CurrentVelocity.self, from: Data(body.utf8))
      }
    }
    let decoder = JSONDecoder()
    decoder.nonConformingFloatDecodingStrategy = .convertFromString(
      positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
    #expect(throws: DecodingError.self) {
      try decoder.decode(CurrentVelocity.self, from: Data(#"{"Speed":"1","Direction":"NaN"}"#.utf8))
    }
  }
}

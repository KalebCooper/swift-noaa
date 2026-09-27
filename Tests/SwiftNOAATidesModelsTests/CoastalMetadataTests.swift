import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Coastal notices and sensors", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct CoastalMetadataTests {
  @Test("Missing collections fail while empty and null remain distinct")
  func missingCollectionsFailWhileEmptyAndNullRemainDistinct() throws {
    let decoder = JSONDecoder()
    #expect(throws: DecodingError.self) {
      try decoder.decode(CoastalNotices.self, from: Data("{}".utf8))
    }
    #expect(throws: DecodingError.self) {
      try decoder.decode(CoastalSensors.self, from: Data("{}".utf8))
    }
    #expect(try decoder.decode(CoastalNotices.self, from: Fixture.notices.data()).notices.isEmpty)
    #expect(
      try decoder.decode(CoastalNotices.self, from: Fixture.noticesInvalid.data()).notices.isEmpty)
    let null = try decoder.decode(CoastalSensors.self, from: Fixture.sensorsInvalid.data())
    #expect(null.sensors == nil)
    #expect(try decoder.decode(CoastalSensors.self, from: JSONEncoder().encode(null)) == null)
    #expect(
      try decoder.decode(CoastalSensors.self, from: Data(#"{"sensors":[]}"#.utf8)).sensors == [])
  }

  @Test("Notices retain literal markup and whitespace")
  func noticesRetainLiteralMarkupAndWhitespace() throws {
    let result = try JSONDecoder().decode(
      CoastalNotices.self, from: Fixture.noticesPopulated.data())
    #expect(result.notices.first?.name == "High Water Condition")
    #expect(
      result.notices.first?.text
        == "This station is currently in <a href='http://tidesandcurrents.noaa.gov/waterconditions.html#high'>high water condition</a>."
    )
    let constructed = Data(#"{"name":" A ","text":"\r\n<b>x</b> "}"#.utf8)
    #expect(try JSONDecoder().decode(CoastalNotice.self, from: constructed).text == "\r\n<b>x</b> ")
  }

  @Test("Sensors retain units elevation status and nullable metadata")
  func sensorsRetainUnitsElevationStatusAndNullableMetadata() throws {
    let decoder = JSONDecoder()
    let metric = try decoder.decode(CoastalSensors.self, from: Fixture.sensorsMetric.data())
    let english = try decoder.decode(CoastalSensors.self, from: Fixture.sensorsEnglish.data())
    #expect(metric.units == "meters")
    #expect(english.units == "feet")
    #expect(metric.sensors?.count == 7)
    #expect(metric.sensors?.first?.elevation == 7.37)
    #expect(english.sensors?.first?.elevation == 24.163385)
    #expect(metric.sensors?.first?.referenceDatum == "Site Elevation")
    #expect(metric.sensors?.first?.dataCollectionPlatform == 1)
    #expect(metric.sensors?[2].status == .disabled)
    #expect(
      metric.sensors?[2].message
        == "2025-12-10 22:23:00&Suspect Data - Data failed to meet QC standards - under review.")
    #expect(metric.sensors?.last?.elevation == nil)
    #expect(metric.sensors?.last?.referenceDatum == "")
    let constructed = Data(
      #"{"sensorID":"X","name":"Future","status":17,"message":"","refdatum":null,"elevation":null}"#
        .utf8)
    let unknown = try decoder.decode(CoastalSensor.self, from: constructed)
    #expect(unknown.status.rawValue == 17)
    #expect(unknown.message == "")
    #expect(unknown.referenceDatum == nil)
  }
}

import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Valid time intervals", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ValidTimeIntervalTests {
  @Test(
    "A start and duration interval parses into its start and components",
    arguments: [
      ("PT1H", [0, 0, 0, 1, 0, 0]),
      ("PT3H", [0, 0, 0, 3, 0, 0]),
      ("P2D", [0, 0, 2, 0, 0, 0]),
      ("P1DT19H", [0, 0, 1, 19, 0, 0]),
      ("P7DT8H", [0, 0, 7, 8, 0, 0]),
      ("P1Y2M10DT2H30M", [1, 2, 10, 2, 30, 0]),
      ("PT0S", [0, 0, 0, 0, 0, 0]),
      ("P0D", [0, 0, 0, 0, 0, 0]),
      ("PT1M5S", [0, 0, 0, 0, 1, 5]),
      ("P007D", [0, 0, 7, 0, 0, 0]),
    ])
  func aStartAndDurationIntervalParsesIntoItsStartAndComponents(
    duration: String, components: [Int]
  ) throws {
    let interval = try #require(
      ValidTimeInterval(rawValue: "2026-09-17T17:00:00+00:00/" + duration))
    #expect(interval.start == Date(timeIntervalSince1970: 1_789_664_400))
    let parsed = interval.duration
    #expect(
      [parsed.years, parsed.months, parsed.days, parsed.hours, parsed.minutes, parsed.seconds]
        == components)
    #expect(parsed.rawValue == duration)
  }

  @Test("An interval keeps its exact raw text")
  func anIntervalKeepsItsExactRawText() throws {
    let offset = try #require(ValidTimeInterval(rawValue: "2026-09-17T17:00:00+00:00/PT1H"))
    let zulu = try #require(ValidTimeInterval(rawValue: "2026-09-17T17:00:00Z/PT1H"))
    #expect(offset.rawValue == "2026-09-17T17:00:00+00:00/PT1H")
    #expect(zulu.rawValue == "2026-09-17T17:00:00Z/PT1H")
    #expect(offset.start == zulu.start)
    #expect(offset != zulu)
  }

  @Test("A duration without calendar components has an exact length")
  func aDurationWithoutCalendarComponentsHasAnExactLength() throws {
    let duration = try #require(ISO8601Duration(rawValue: "P1DT6H"))
    #expect(duration.exactDuration == .seconds(108_000))
    #expect(ISO8601Duration(rawValue: "PT1H1M1S")?.exactDuration == .seconds(3_661))
  }

  @Test(
    "A duration with years or months has no exact length", arguments: ["P1Y", "P1M", "P1Y2MT1H"])
  func aDurationWithYearsOrMonthsHasNoExactLength(text: String) throws {
    let duration = try #require(ISO8601Duration(rawValue: text))
    #expect(duration.exactDuration == nil)
  }

  @Test("An interval without calendar components reports its end")
  func anIntervalWithoutCalendarComponentsReportsItsEnd() throws {
    let interval = try #require(ValidTimeInterval(rawValue: "2026-09-17T17:00:00+00:00/P7DT8H"))
    // 2026-09-25T01:00:00+00:00
    #expect(interval.end == Date(timeIntervalSince1970: 1_790_298_000))
  }

  @Test("An interval with calendar components reports no end")
  func anIntervalWithCalendarComponentsReportsNoEnd() throws {
    let interval = try #require(ValidTimeInterval(rawValue: "2026-09-17T17:00:00+00:00/P1M"))
    #expect(interval.end == nil)
    #expect(interval.duration.months == 1)
  }

  @Test(
    "Malformed durations are rejected",
    arguments: [
      "", "P", "PT", "P1DT", "P1W", "PT1.5H", "PT1,5H", "-PT1H", "+PT1H", "pt1h", "P1h", "P1H",
      "PT1D", "P1M1Y", "PT1S1M", "P1D1D", "PT1HT1M", "P 1D", "P1D ", " P1D", "P1", "PT1",
      "P99999999999999999999D",
    ])
  func malformedDurationsAreRejected(text: String) {
    #expect(ISO8601Duration(rawValue: text) == nil)
  }

  @Test(
    "Unsupported interval forms are rejected",
    arguments: [
      "2026-09-17T17:00:00+00:00/2026-09-17T18:00:00+00:00",
      "PT1H/2026-09-17T18:00:00+00:00",
      "NOW/PT1H",
      "2026-09-17T17:00:00+00:00/NOW",
      "2026-09-17T17:00:00+00:00",
      "2026-09-17T17:00:00+00:00/PT1H/PT1H",
      "2026-09-17T17:00:00+00:00/",
      "2026-13-17T17:00:00+00:00/PT1H",
      "tomorrow/PT1H",
    ])
  func unsupportedIntervalFormsAreRejected(text: String) {
    #expect(ValidTimeInterval(rawValue: text) == nil)
  }

  @Test("A duration too large to measure reports no exact length")
  func aDurationTooLargeToMeasureReportsNoExactLength() throws {
    let duration = try #require(ISO8601Duration(rawValue: "P\(Int.max)D"))
    #expect(duration.days == Int.max)
    #expect(duration.exactDuration == nil)
  }

  @Test("A malformed valid time fails decoding and names the value")
  func aMalformedValidTimeFailsDecodingAndNamesTheValue() throws {
    let body = Data(#"["NOW/PT1H"]"#.utf8)
    do {
      _ = try JSONDecoder().decode([ValidTimeInterval].self, from: body)
      Issue.record("Expected a decoding failure")
    } catch DecodingError.dataCorrupted(let context) {
      #expect(context.debugDescription.contains("\"NOW/PT1H\""))
    }
  }

  @Test("A valid time encodes its raw text unchanged")
  func aValidTimeEncodesItsRawTextUnchanged() throws {
    let text = "2026-09-17T17:00:00+00:00/P1DT19H"
    let interval = try #require(ValidTimeInterval(rawValue: text))
    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    let body = try encoder.encode([interval])
    #expect(String(decoding: body, as: UTF8.self) == #"["2026-09-17T17:00:00+00:00/P1DT19H"]"#)
    #expect(try JSONDecoder().decode([ValidTimeInterval].self, from: body) == [interval])
  }
}

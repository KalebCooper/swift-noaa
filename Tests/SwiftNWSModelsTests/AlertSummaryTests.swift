import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Alert counts, types, and regions", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct AlertSummaryTests {
  @Test("A nonempty array breakdown fails to decode")
  func aNonemptyArrayBreakdownFailsToDecode() {
    let body = Data(
      #"{"areas":{},"land":0,"marine":0,"regions":[1],"total":0,"zones":{}}"#.utf8)
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ActiveAlertCount.self, from: body)
    }
  }

  @Test("A recorded active alert count decodes every breakdown")
  func aRecordedActiveAlertCountDecodesEveryBreakdown() throws {
    let count = try JSONDecoder().decode(
      ActiveAlertCount.self, from: Fixture.activeAlertCount.data())
    #expect(count.total == 244)
    #expect(count.land == 81)
    #expect(count.marine == 163)
    #expect(
      count.regions == [
        .alaska: 143, .atlantic: 2, .greatLakes: 5, .gulfOfMexico: 4, .pacific: 7,
        .pacificIslands: 2,
      ])
    #expect(count.areas.count == 38)
    #expect(count.areas[.texas] == 1)
    #expect(count.areas[.northwestNorthAtlanticOcean] == 2)
    #expect(count.zones.count == 1275)
    #expect(count.zones["AKC090"] == 2)
    #expect(count.areas.values.reduce(0, +) == 266)
  }

  @Test("Active alert counts encode breakdowns as objects keyed by code")
  func activeAlertCountsEncodeBreakdownsAsObjectsKeyedByCode() throws {
    let count = try JSONDecoder().decode(
      ActiveAlertCount.self, from: Fixture.activeAlertCount.data())
    let encoded = try JSONEncoder().encode(count)
    let object = try #require(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect((object["regions"] as? [String: Int])?["AT"] == 2)
    #expect((object["areas"] as? [String: Int])?["TX"] == 1)
    #expect(try JSONDecoder().decode(ActiveAlertCount.self, from: encoded) == count)
  }

  @Test("Alert count, type, and region endpoints name their paths and media types")
  func alertCountTypeAndRegionEndpointsNameTheirPathsAndMediaTypes() throws {
    #expect(Endpoint.activeAlertCount.path == "/alerts/active/count")
    #expect(Endpoint.activeAlertCount.accept.rawValue == "application/ld+json")
    #expect(Endpoint.alertTypes.path == "/alerts/types")
    #expect(Endpoint.alertTypes.accept.rawValue == "application/ld+json")
    #expect(
      try #require(Endpoint.activeAlerts(inRegion: .gulfOfMexico)).path
        == "/alerts/active/region/GM")
    #expect(try #require(Endpoint.activeAlerts(inRegion: .gulfOfMexico)).accept == .geoJSON)
    #expect(
      try #require(Endpoint.activeAlerts(inRegion: ConsumerRegion.atlantic)).path
        == "/alerts/active/region/AT")
    #expect(
      try #require(Endpoint.activeAlerts(inRegion: MarineRegionCode(rawValue: "A/T"))).path
        == "/alerts/active/region/A%2FT")
  }

  @Test("Alert count, type, and region requests describe their endpoints without sending")
  func alertCountTypeAndRegionRequestsDescribeTheirEndpointsWithoutSending() throws {
    let count = WeatherRequest.activeAlertCount
    let types = WeatherRequest.alertTypes
    let region = try #require(WeatherRequest.activeAlerts(inRegion: .atlantic))
    #expect(count.resolution == .endpoint(.activeAlertCount))
    #expect(types.resolution == .endpoint(.alertTypes))
    #expect(region.resolution == .activeAlerts(try #require(.activeAlerts(inRegion: .atlantic))))
    #expect(try #require(WeatherRequest.activeAlerts(inRegion: ConsumerRegion.atlantic)) == region)
    #expect(WeatherRequest.nationalAlertCount == count)
  }

  @Test("Alert types decode the recognized event names in service order")
  func alertTypesDecodeTheRecognizedEventNamesInServiceOrder() throws {
    let types = try JSONDecoder().decode(AlertTypes.self, from: Fixture.alertTypes.data())
    #expect(types.eventTypes.count == 111)
    #expect(types.eventTypes.first == "911 Telephone Outage")
    #expect(types.eventTypes.last == "Winter Weather Advisory")
    #expect(types.eventTypes.contains("Heat Advisory"))
    #expect(try JSONDecoder().decode(AlertTypes.self, from: JSONEncoder().encode(types)) == types)
  }

  @Test("Empty breakdowns decode from an empty object or an empty array")
  func emptyBreakdownsDecodeFromAnEmptyObjectOrAnEmptyArray() throws {
    let body = Data(
      #"{"areas":[],"land":0,"marine":0,"regions":{},"total":0,"zones":[]}"#.utf8)
    let count = try JSONDecoder().decode(ActiveAlertCount.self, from: body)
    #expect(
      count == ActiveAlertCount(areas: [:], land: 0, marine: 0, regions: [:], total: 0, zones: [:]))
  }

  @Test("Recorded region alerts decode marine CAP fields")
  func recordedRegionAlertsDecodeMarineCAPFields() throws {
    let alerts = try JSONDecoder().decode(
      FeatureCollection<WeatherAlert>.self, from: Fixture.regionAlerts.data())
    #expect(
      alerts.features.map(\.properties.event) == [
        "Marine Weather Statement", "Small Craft Advisory",
      ])
    #expect(alerts.features.map(\.properties.response) == [.monitor, .avoid])
    #expect(alerts.pagination == nil)
  }

  @Test("Unknown codes survive as breakdown keys")
  func unknownCodesSurviveAsBreakdownKeys() throws {
    let body = Data(
      #"{"areas":{"ZZ":3},"land":3,"marine":1,"regions":{"XR":1},"total":4,"zones":{"ZZZ001":3}}"#
        .utf8)
    let count = try JSONDecoder().decode(ActiveAlertCount.self, from: body)
    #expect(count.areas[AreaCode(rawValue: "ZZ")] == 3)
    #expect(count.regions[MarineRegionCode(rawValue: "XR")] == 1)
    #expect(count.zones == ["ZZZ001": 3])
  }
}

private enum ConsumerRegion: String {
  case atlantic = "AT"
}

extension WeatherRequest where Response == ActiveAlertCount {
  fileprivate static var nationalAlertCount: Self { .activeAlertCount }
}

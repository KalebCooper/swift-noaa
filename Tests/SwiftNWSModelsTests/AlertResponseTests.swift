import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Alert responses", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct AlertResponseTests {
  @Test(
    "Alert collections decode recorded CAP fields",
    arguments: [Fixture.activeAlerts, .areaAlerts, .zoneAlerts])
  func alertCollectionsDecodeRecordedCAPFields(fixture: Fixture) throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let alerts = try decoder.decode(FeatureCollection<WeatherAlert>.self, from: fixture.data())
    #expect(alerts.features.count == (fixture == .areaAlerts ? 12 : 2))
    let first = try #require(alerts.features.first?.properties)
    #expect(first.status == .actual)
    #expect(first.expires > first.sent)
    #expect(!first.affectedZones.isEmpty)
    #expect(first.parameters?["AWIPSidentifier"] != nil)
    #expect(first.geocode?["UGC"]?.isEmpty == false)
    #expect(
      try decoder.decode(FeatureCollection<WeatherAlert>.self, from: JSONEncoder().encode(alerts))
        == alerts)
  }

  @Test("An alert retains references and optional CAP fields")
  func anAlertRetainsReferencesAndOptionalCAPFields() throws {
    let alert = try JSONDecoder().decode(Feature<WeatherAlert>.self, from: Fixture.alert.data())
      .properties
    #expect(alert.event == "Heat Advisory")
    #expect(alert.severity == .moderate)
    #expect(alert.certainty == .likely)
    #expect(alert.urgency == .expected)
    #expect(alert.note == nil)
    #expect(alert.messageType == .update)
    #expect(
      alert.references?.first?.identifier
        == "urn:oid:2.49.0.1.840.0.b427ca6143604a9af1714a82cf768a1a4e95f084.001.1")
    #expect(alert.language == "en-US")
    #expect(alert.scope == "Public")
    #expect(alert.eventCode?["SAME"] == [.string("NWS")])
  }

  @Test("Every geographic filter has one query key")
  func everyGeographicFilterHasOneQueryKey() throws {
    let point = try WeatherCoordinate(latitude: 30.26721, longitude: -97.74306)
    let filters: [(ActiveAlertFilter.Location, String)] = [
      (.areas(["TX", "OK"]), "area=TX,OK"),
      (.point(point), "point=30.2672,-97.7431"),
      (.regions(["AL"]), "region=AL"),
      (.regionType(.marine), "region_type=marine"),
      (.zones(["TXZ192"]), "zone=TXZ192"),
    ]
    for (location, query) in filters {
      #expect(
        Endpoint.activeAlerts(matching: .init(location: location)).path == "/alerts/active?" + query
      )
    }
  }

  @Test("Filters encode all supported query fields")
  func filtersEncodeAllSupportedQueryFields() {
    let endpoint = Endpoint.activeAlerts(
      matching: .init(
        certainty: [.likely], code: ["HTY"], event: ["Heat Advisory"], location: .areas(["TX"]),
        messageType: [.update], severity: [.moderate], status: [.actual], urgency: [.expected]))
    #expect(
      endpoint.path
        == "/alerts/active?area=TX&certainty=Likely&code=HTY&event=Heat%20Advisory&message_type=update&severity=Moderate&status=actual&urgency=Expected"
    )
    #expect(Endpoint.activeAlerts().path == "/alerts/active")
    #expect(Endpoint.activeAlerts(inArea: "TX/OK").path == "/alerts/active/area/TX%2FOK")
    #expect(Endpoint.activeAlerts(inZone: "../x").path == "/alerts/active/zone/%2E%2E%2Fx")
    #expect(Endpoint.alert(identifier: "urn:oid:a/b").path == "/alerts/urn%3Aoid%3Aa%2Fb")
  }

  @Test("Unknown alert codes and null fields survive decoding")
  func unknownAlertCodesAndNullFieldsSurviveDecoding() throws {
    var body = try #require(
      JSONSerialization.jsonObject(with: Fixture.alert.data()) as? [String: Any])
    var properties = try #require(body["properties"] as? [String: Any])
    for key in ["certainty", "messageType", "severity", "status", "urgency"] {
      properties[key] = "FutureCode"
    }
    for key in ["ends", "headline", "instruction", "onset"] { properties[key] = NSNull() }
    properties["parameters"] = ["future": [NSNull(), true, 12.5, ["nested": "value"]]]
    body["properties"] = properties
    let data = try JSONSerialization.data(withJSONObject: body)
    let alert = try JSONDecoder().decode(Feature<WeatherAlert>.self, from: data).properties
    #expect(alert.certainty.rawValue == "FutureCode")
    #expect(alert.messageType.rawValue == "FutureCode")
    #expect(alert.severity.rawValue == "FutureCode")
    #expect(alert.status.rawValue == "FutureCode")
    #expect(alert.urgency.rawValue == "FutureCode")
    #expect(
      alert.ends == nil && alert.onset == nil && alert.instruction == nil && alert.headline == nil)
    #expect(
      alert.parameters?["future"] == [
        .null, .bool(true), .number(12.5), .object(["nested": .string("value")]),
      ])
  }
}

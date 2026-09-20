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
    #expect(first.category == .meteorological)
    #expect(first.response == .execute)
    #expect(first.scope == .public)
    #expect(first.status == .actual)
    #expect(first.expires > first.sent)
    #expect(!first.affectedZones.isEmpty)
    #expect(first.parameters?["AWIPSidentifier"] != nil)
    #expect(first.geocode?["UGC"]?.isEmpty == false)
    #expect(
      try decoder.decode(FeatureCollection<WeatherAlert>.self, from: JSONEncoder().encode(alerts))
        == alerts)
  }

  @Test("Alert history decodes its features in service order with its continuation link")
  func alertHistoryDecodesItsFeaturesInServiceOrderWithItsContinuationLink() throws {
    let history = try JSONDecoder().decode(
      FeatureCollection<WeatherAlert>.self, from: Fixture.alertHistory.data())
    #expect(
      history.features.map(\.properties.event) == ["Special Weather Statement", "Flood Advisory"])
    #expect(history.features.allSatisfy { $0.properties.status == .actual })
    #expect(
      history.pagination?.next
        == "https://api.weather.gov/alerts?area%5B0%5D=TX&end=2026-09-17T00:00:00Z&limit=2"
        + "&start=2026-09-16T00:00:00Z&status%5B0%5D=actual&cursor=eyJ0IjoxNzg5NjAxOTQwLCJpIjoidXJu"
        + "Om9pZDoyLjQ5LjAuMS44NDAuMC4xYzk1MTA5ZWQ5ZjE5ZDZkYmNmZjBiMWUzZmEwMjg5NzAxYzZkMThjLjAwMS4xIn0%3D"
    )
  }

  @Test("Alert timestamps retain milliseconds when encoded")
  func alertTimestampsRetainMillisecondsWhenEncoded() throws {
    var alert = try JSONDecoder().decode(Feature<WeatherAlert>.self, from: Fixture.alert.data())
      .properties
    let instant = try Date(
      "2026-09-13T14:30:00.125Z",
      strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    alert.onset = instant
    alert.sent = instant
    let decoded = try JSONDecoder().decode(WeatherAlert.self, from: JSONEncoder().encode(alert))
    #expect(decoded.onset == instant)
    #expect(decoded.sent == instant)
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
    #expect(alert.scope == .public)
    #expect(alert.eventCode?["SAME"] == [.string("NWS")])
  }

  @Test("Consumer enums create filter locations")
  func consumerEnumsCreateFilterLocations() {
    let areas: ActiveAlertFilter.Location = .areas([ConsumerArea.texas])
    let regions: ActiveAlertFilter.Location = .regions([ConsumerRegion.alaska])

    #expect(AlertSeverity(ConsumerSeverity.severe) == .severe)
    #expect(
      Endpoint.activeAlerts(matching: .init(location: areas)).path == "/alerts/active?area=TX")
    #expect(
      Endpoint.activeAlerts(matching: .init(location: regions)).path == "/alerts/active?region=AL")
  }

  @Test("Every geographic filter has one query key")
  func everyGeographicFilterHasOneQueryKey() throws {
    let point = try WeatherCoordinate(latitude: 30.26721, longitude: -97.74306)
    let filters: [(ActiveAlertFilter.Location, String)] = [
      (.areas([.texas, .oklahoma]), "area=TX,OK"),
      (.point(point), "point=30.2672,-97.7431"),
      (.regionType(.marine), "region_type=marine"),
      (.regions([.alaska]), "region=AL"),
      (.zones(["TXZ192"]), "zone=TXZ192"),
    ]
    for (location, query) in filters {
      #expect(
        Endpoint.activeAlerts(matching: .init(location: location)).path == "/alerts/active?" + query
      )
    }
  }

  @Test("Filters encode all supported query fields")
  func filtersEncodeAllSupportedQueryFields() throws {
    let endpoint = Endpoint.activeAlerts(
      matching: .init(
        certainty: [.likely], code: ["HTY"], event: ["Heat Advisory"], location: .areas([.texas]),
        messageType: [.update], severity: [.moderate], status: [.actual], urgency: [.expected]))
    #expect(
      endpoint.path
        == "/alerts/active?area=TX&certainty=Likely&code=HTY&event=Heat%20Advisory&message_type=update&severity=Moderate&status=actual&urgency=Expected"
    )
    #expect(Endpoint.activeAlerts().path == "/alerts/active")
    #expect(
      try #require(Endpoint.activeAlerts(inArea: AreaCode(rawValue: "TX/OK"))).path
        == "/alerts/active/area/TX%2FOK")
    #expect(try #require(Endpoint.activeAlerts(inZone: "x/y")).path == "/alerts/active/zone/x%2Fy")
    #expect(
      try #require(Endpoint.alert(identifier: "urn:oid:a/b")).path == "/alerts/urn%3Aoid%3Aa%2Fb")
  }

  @Test("Unknown alert codes and null fields survive decoding")
  func unknownAlertCodesAndNullFieldsSurviveDecoding() throws {
    var body = try #require(
      JSONSerialization.jsonObject(with: Fixture.alert.data()) as? [String: Any])
    var properties = try #require(body["properties"] as? [String: Any])
    for key in [
      "category", "certainty", "messageType", "response", "scope", "severity", "status", "urgency",
    ] {
      properties[key] = "FutureCode"
    }
    for key in ["ends", "headline", "instruction", "onset"] { properties[key] = NSNull() }
    properties["parameters"] = ["future": [NSNull(), true, 12.5, ["nested": "value"]]]
    body["properties"] = properties
    let data = try JSONSerialization.data(withJSONObject: body)
    let alert = try JSONDecoder().decode(Feature<WeatherAlert>.self, from: data).properties
    #expect(alert.category.rawValue == "FutureCode")
    #expect(alert.certainty.rawValue == "FutureCode")
    #expect(alert.messageType.rawValue == "FutureCode")
    #expect(alert.response.rawValue == "FutureCode")
    #expect(alert.scope?.rawValue == "FutureCode")
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

private enum ConsumerArea: String {
  case texas = "TX"
}

private enum ConsumerRegion: String {
  case alaska = "AL"
}

private enum ConsumerSeverity: String {
  case severe = "Severe"
}

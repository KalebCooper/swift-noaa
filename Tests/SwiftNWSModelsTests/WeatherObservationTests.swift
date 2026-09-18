import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Decoding every observation field", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct WeatherObservationTests {
  @Test("A latest observation decodes every field the service sent")
  func aLatestObservationDecodesEveryFieldTheServiceSent() throws {
    let observation = try JSONDecoder().decode(
      Feature<WeatherObservation>.self, from: Fixture.observation.data()
    ).properties

    #expect(
      observation
        == WeatherObservation(
          barometricPressure: QuantitativeValue(
            qualityControl: .verified, unitCode: "wmoUnit:Pa", value: 101_460),
          cloudLayers: [
            CloudLayer(amount: .clear, base: QuantitativeValue(unitCode: "wmoUnit:m", value: nil))
          ],
          dewpoint: QuantitativeValue(
            qualityControl: .verified, unitCode: "wmoUnit:degC", value: 20),
          elevation: QuantitativeValue(unitCode: "wmoUnit:m", value: 198),
          heatIndex: QuantitativeValue(
            qualityControl: .verified, unitCode: "wmoUnit:degC", value: 41.13086375045),
          icon: URL(string: "https://api.weather.gov/icons/land/day/skc?size=medium"),
          maxTemperatureLast24Hours: QuantitativeValue(unitCode: "wmoUnit:degC", value: nil),
          minTemperatureLast24Hours: QuantitativeValue(unitCode: "wmoUnit:degC", value: nil),
          precipitationLast3Hours: QuantitativeValue(
            qualityControl: .preliminary, unitCode: "wmoUnit:mm", value: nil),
          precipitationLast6Hours: QuantitativeValue(
            qualityControl: .preliminary, unitCode: "wmoUnit:mm", value: nil),
          precipitationLastHour: QuantitativeValue(
            qualityControl: .preliminary, unitCode: "wmoUnit:mm", value: nil),
          presentWeather: [],
          rawMessage:
            "KATT 131951Z AUTO 21005G17KT 10SM CLR 38/20 A2996 RMK AO2 SLP129 T03780200 $",
          relativeHumidity: QuantitativeValue(
            qualityControl: .verified, unitCode: "wmoUnit:percent", value: 35.623741997968),
          seaLevelPressure: QuantitativeValue(
            qualityControl: .verified, unitCode: "wmoUnit:Pa", value: 101_290),
          station: URL(string: "https://api.weather.gov/stations/KATT"),
          stationId: "KATT",
          stationName: "Austin City Austin Camp Mabry",
          temperature: QuantitativeValue(
            qualityControl: .verified, unitCode: "wmoUnit:degC", value: 37.8),
          textDescription: "Clear",
          // 2026-09-13T19:51:00+00:00
          timestamp: Date(timeIntervalSince1970: 1_789_329_060),
          visibility: QuantitativeValue(
            qualityControl: .coarsePass, unitCode: "wmoUnit:m", value: 16_090),
          windChill: QuantitativeValue(
            qualityControl: .verified, unitCode: "wmoUnit:degC", value: nil),
          windDirection: QuantitativeValue(
            qualityControl: .verified, unitCode: "wmoUnit:degree_(angle)", value: 210),
          windGust: QuantitativeValue(
            qualityControl: .coarsePass, unitCode: "wmoUnit:km_h-1", value: 31.68),
          windSpeed: QuantitativeValue(
            qualityControl: .verified, unitCode: "wmoUnit:km_h-1", value: 9.36)
        ))
  }

  @Test("Reported weather decodes each phenomenon and cloud layer in service order")
  func reportedWeatherDecodesEachPhenomenonAndCloudLayerInServiceOrder() throws {
    let observation = try JSONDecoder().decode(
      Feature<WeatherObservation>.self, from: Fixture.observationWithWeather.data()
    ).properties

    #expect(
      observation.presentWeather == [
        WeatherPhenomenon(intensity: .heavy, modifier: nil, rawString: "+RA", weather: .rain),
        WeatherPhenomenon(intensity: nil, modifier: nil, rawString: "BR", weather: .fogMist),
      ])
    #expect(
      observation.cloudLayers == [
        CloudLayer(amount: .broken, base: QuantitativeValue(unitCode: "wmoUnit:m", value: 91.44)),
        CloudLayer(amount: .broken, base: QuantitativeValue(unitCode: "wmoUnit:m", value: 243.84)),
        CloudLayer(amount: .overcast, base: QuantitativeValue(unitCode: "wmoUnit:m", value: 609.6)),
      ])
    #expect(observation.textDescription == "Heavy Rain and Fog/Mist")
  }

  @Test("Fields the service omits stay absent and empty strings stay empty")
  func fieldsTheServiceOmitsStayAbsentAndEmptyStringsStayEmpty() throws {
    let observation = try JSONDecoder().decode(
      Feature<WeatherObservation>.self, from: Fixture.observationWithWeather.data()
    ).properties

    #expect(observation.rawMessage == "")
    #expect(observation.precipitationLastHour == nil)
    #expect(observation.precipitationLast6Hours == nil)
    #expect(
      observation.precipitationLast3Hours
        == QuantitativeValue(qualityControl: .preliminary, unitCode: "wmoUnit:mm", value: nil))
    #expect(
      observation.seaLevelPressure
        == QuantitativeValue(qualityControl: .preliminary, unitCode: "wmoUnit:Pa", value: nil))
  }

  @Test("A null icon and an empty cloud layer list decode as sent")
  func aNullIconAndAnEmptyCloudLayerListDecodeAsSent() throws {
    let observation = try JSONDecoder().decode(
      Feature<WeatherObservation>.self, from: Fixture.observationAtTimestamp.data()
    ).properties

    #expect(observation.icon == nil)
    #expect(observation.cloudLayers == [])
    #expect(observation.presentWeather == [])
    #expect(observation.textDescription == "")
  }

  @Test("Unknown weather and sky coverage codes survive decoding")
  func unknownWeatherAndSkyCoverageCodesSurviveDecoding() throws {
    let body = Data(
      #"""
      {"cloudLayers":[{"amount":"NSC","base":{"unitCode":"wmoUnit:m","value":null}}],
      "presentWeather":[{"inVicinity":true,"intensity":"extreme","modifier":"distant",
      "rawString":"VCXX","weather":"meteor_shower"}],
      "stationId":"KATT","timestamp":"2026-09-13T19:51:00+00:00"}
      """#.utf8)

    let observation = try JSONDecoder().decode(WeatherObservation.self, from: body)

    #expect(observation.cloudLayers?.first?.amount.rawValue == "NSC")
    let phenomenon = try #require(observation.presentWeather?.first)
    #expect(phenomenon.inVicinity == true)
    #expect(phenomenon.intensity?.rawValue == "extreme")
    #expect(phenomenon.modifier?.rawValue == "distant")
    #expect(phenomenon.weather.rawValue == "meteor_shower")
  }

  @Test("A null cloud layer list decodes as no list")
  func aNullCloudLayerListDecodesAsNoList() throws {
    let body = Data(
      #"{"cloudLayers":null,"stationId":"KATT","timestamp":"2026-09-13T19:51:00+00:00"}"#.utf8)

    let observation = try JSONDecoder().decode(WeatherObservation.self, from: body)

    #expect(observation.cloudLayers == nil)
  }

  @Test("An observation with reported weather survives encoding and decoding unchanged")
  func anObservationWithReportedWeatherSurvivesEncodingAndDecodingUnchanged() throws {
    let observation = try JSONDecoder().decode(
      Feature<WeatherObservation>.self, from: Fixture.observationWithWeather.data()
    ).properties

    let decoded = try JSONDecoder().decode(
      WeatherObservation.self, from: JSONEncoder().encode(observation))

    #expect(decoded == observation)
  }
}

import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Forecast grid", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ForecastGridTests {
  @Test("The recorded grid decodes its identity, elevation, and valid times")
  func theRecordedGridDecodesItsIdentityElevationAndValidTimes() throws {
    let grid = try decode(.forecastGrid)
    #expect(grid.gridId == "EWX")
    #expect(grid.gridX == 156)
    #expect(grid.gridY == 91)
    #expect(grid.forecastOffice == URL(string: "https://api.weather.gov/offices/EWX"))
    #expect(grid.elevation == QuantitativeValue(unitCode: "wmoUnit:m", value: 155.1432))
    // 2026-09-17T23:48:18+00:00
    #expect(grid.updateTime == Date(timeIntervalSince1970: 1_789_688_898))
    #expect(grid.validTimes.rawValue == "2026-09-17T17:00:00+00:00/P7DT8H")
    #expect(grid.validTimes.start == Date(timeIntervalSince1970: 1_789_664_400))
    #expect(grid.otherProperties.isEmpty)
  }

  @Test("Every recorded quantitative layer decodes under its name")
  func everyRecordedQuantitativeLayerDecodesUnderItsName() throws {
    let grid = try decode(.forecastGrid)
    let expected: [ForecastGridLayerName] = [
      .apparentTemperature, .atmosphericDispersionIndex, .ceilingHeight, .davisStabilityIndex,
      .dewpoint, .dispersionIndex, .grasslandFireDangerIndex, .hainesIndex, .heatIndex, .heatRisk,
      .iceAccumulation, .lightningActivityLevel, .lowVisibilityOccurrenceRiskIndex, .maxTemperature,
      .minTemperature, .mixingHeight, .potentialOf15mphWinds, .potentialOf20mphWindGusts,
      .potentialOf25mphWinds, .potentialOf30mphWindGusts, .potentialOf35mphWinds,
      .potentialOf40mphWindGusts, .potentialOf45mphWinds, .potentialOf50mphWindGusts,
      .potentialOf60mphWindGusts, .pressure, .primarySwellDirection, .primarySwellHeight,
      .probabilityOfHurricaneWinds, .probabilityOfPrecipitation, .probabilityOfThunder,
      .probabilityOfTropicalStormWinds, .quantitativePrecipitation, .redFlagThreatIndex,
      .relativeHumidity, .secondarySwellDirection, .secondarySwellHeight, .skyCover, .snowLevel,
      .snowfallAmount, .stability, .temperature, .transportWindDirection, .transportWindSpeed,
      .twentyFootWindDirection, .twentyFootWindSpeed, .visibility, .waveDirection, .waveHeight,
      .wavePeriod, .wavePeriod2, .wetBulbGlobeTemperature, .windChill, .windDirection, .windGust,
      .windSpeed, .windWaveHeight,
    ]
    #expect(expected.count == 57)
    #expect(Set(grid.layers.keys) == Set(expected))
    #expect(grid.weather != nil)
    #expect(grid.hazards != nil)
  }

  @Test("A layer keeps its unit code, or nil when the service omits it")
  func aLayerKeepsItsUnitCodeOrNilWhenTheServiceOmitsIt() throws {
    let grid = try decode(.forecastGrid)
    #expect(grid[.temperature]?.unitCode == "wmoUnit:degC")
    #expect(grid[.heatRisk]?.unitCode == nil)
    #expect(grid[.heatRisk]?.values.first?.value == 4)
    #expect(grid[.probabilityOfThunder]?.unitCode == nil)
  }

  @Test("A null grid value decodes as nil and keeps its interval")
  func aNullGridValueDecodesAsNilAndKeepsItsInterval() throws {
    let windChill = try #require(try decode(.forecastGrid)[.windChill])
    #expect(windChill.values.count == 1)
    #expect(windChill.values.first?.value == .some(nil))
    #expect(windChill.values.first?.validTime.rawValue == "2026-09-17T17:00:00+00:00/P7DT8H")
  }

  @Test("A present layer with no values stays distinct from an absent layer")
  func aPresentLayerWithNoValuesStaysDistinctFromAnAbsentLayer() throws {
    let recorded = try decode(.forecastGrid)
    #expect(recorded[.waveHeight]?.values == [])
    let minimal = try JSONDecoder().decode(ForecastGrid.self, from: Self.minimalGrid(""))
    #expect(minimal[.waveHeight] == nil)
    #expect(minimal.layers.isEmpty)
    #expect(minimal.weather == nil)
    #expect(minimal.hazards == nil)
  }

  @Test("Layer values keep service order")
  func layerValuesKeepServiceOrder() throws {
    let grid = try decode(.forecastGrid)
    let temperature = try #require(grid[.temperature])
    #expect(temperature.values.count == 161)
    #expect(
      temperature.values.prefix(3).map(\.validTime.rawValue) == [
        "2026-09-17T17:00:00+00:00/PT1H", "2026-09-17T18:00:00+00:00/PT1H",
        "2026-09-17T19:00:00+00:00/PT1H",
      ])
    #expect(
      temperature.values.prefix(3).map(\.value) == [
        33.333333333333336, 35.55555555555556, 36.111111111111114,
      ])
    // The service's own sentinel for the ceiling height is kept, not interpreted.
    let ceiling = try #require(grid[.ceilingHeight])
    #expect(ceiling.values.prefix(3).map(\.value) == [-30.48, 7620, -30.48])
    #expect(ceiling.values[2].validTime.duration.days == 1)
    #expect(ceiling.values[2].validTime.duration.hours == 8)
  }

  @Test("A layer name the package does not know is preserved with its values")
  func aLayerNameThePackageDoesNotKnowIsPreservedWithItsValues() throws {
    let grid = try JSONDecoder().decode(
      ForecastGrid.self,
      from: Self.minimalGrid(
        #","futureLayer":{"uom":"wmoUnit:m","values":[{"validTime":"2026-09-17T17:00:00+00:00/PT1H","value":2}]}"#
      ))
    let layer = try #require(grid[ForecastGridLayerName(rawValue: "futureLayer")])
    #expect(layer.unitCode == "wmoUnit:m")
    #expect(layer.values.map(\.value) == [2])
    #expect(grid.otherProperties.isEmpty)
  }

  @Test("A property that is not a layer is preserved as JSON")
  func aPropertyThatIsNotALayerIsPreservedAsJSON() throws {
    let grid = try JSONDecoder().decode(
      ForecastGrid.self,
      from: Self.minimalGrid(#","futureNote":"text","futureObject":{"values":"none"}"#))
    #expect(grid.otherProperties["futureNote"] == .string("text"))
    #expect(grid.otherProperties["futureObject"] == .object(["values": .string("none")]))
    #expect(grid.layers.isEmpty)
  }

  @Test("JSON-LD metadata keys are not treated as layers")
  func jsonLDMetadataKeysAreNotTreatedAsLayers() throws {
    let grid = try JSONDecoder().decode(
      ForecastGrid.self,
      from: Self.minimalGrid(
        #","@context":["https://geojson.org/geojson-ld/geojson-context.jsonld"],"@id":"https://api.weather.gov/gridpoints/EWX/156,91","@type":"wx:Gridpoint","geometry":"POLYGON((0 0))""#
      ))
    #expect(grid.layers.isEmpty)
    #expect(grid.otherProperties.isEmpty)
  }

  @Test("A known layer with the wrong shape fails decoding")
  func aKnownLayerWithTheWrongShapeFailsDecoding() throws {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        ForecastGrid.self, from: Self.minimalGrid(#","temperature":{"values":"none"}"#))
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        ForecastGrid.self,
        from: Self.minimalGrid(
          #","temperature":{"values":[{"validTime":"NOW/PT1H","value":1}]}"#))
    }
  }

  @Test("Weather values keep null coverage, phenomenon, and intensity")
  func weatherValuesKeepNullCoveragePhenomenonAndIntensity() throws {
    let weather = try #require(try decode(.forecastGrid).weather)
    let first = try #require(weather.values.first)
    #expect(first.validTime.rawValue == "2026-09-17T17:00:00+00:00/P5DT7H")
    #expect(
      first.value == [
        ForecastWeather(visibility: QuantitativeValue(unitCode: "wmoUnit:km", value: nil))
      ])
  }

  @Test("Weather codes the package does not know are preserved")
  func weatherCodesThePackageDoesNotKnowArePreserved() throws {
    let body = Data(
      #"{"attributes":["future_attribute"],"coverage":"future_coverage","intensity":"future_intensity","visibility":{"unitCode":"wmoUnit:km","value":null},"weather":"future_weather"}"#
        .utf8)
    let weather = try JSONDecoder().decode(ForecastWeather.self, from: body)
    #expect(weather.attributes.map(\.rawValue) == ["future_attribute"])
    #expect(weather.coverage?.rawValue == "future_coverage")
    #expect(weather.intensity?.rawValue == "future_intensity")
    #expect(weather.phenomenon?.rawValue == "future_weather")
  }

  @Test("Weather attributes decode from the recorded hazard grid")
  func weatherAttributesDecodeFromTheRecordedHazardGrid() throws {
    let weather = try #require(try decode(.forecastGridHazards).weather)
    let first = try #require(weather.values.first)
    let visibility = QuantitativeValue(unitCode: "wmoUnit:km", value: nil)
    #expect(first.validTime.rawValue == "2026-09-17T18:00:00+00:00/PT3H")
    #expect(
      first.value == [
        ForecastWeather(
          attributes: [.heavyRain], coverage: .scattered, phenomenon: .thunderstorms,
          visibility: visibility),
        ForecastWeather(
          coverage: .scattered, intensity: .moderate, phenomenon: .rainShowers,
          visibility: visibility),
      ])
  }

  @Test("Hazards decode their phenomenon, significance, and null event number")
  func hazardsDecodeTheirPhenomenonSignificanceAndNullEventNumber() throws {
    let hazards = try #require(try decode(.forecastGridHazards).hazards)
    #expect(hazards.values.count == 1)
    #expect(hazards.values.first?.validTime.rawValue == "2026-09-17T18:00:00+00:00/PT15H")
    #expect(hazards.values.first?.value == [ForecastHazard(phenomenon: "FA", significance: "A")])
  }

  @Test("An empty hazards layer decodes as present with no values")
  func anEmptyHazardsLayerDecodesAsPresentWithNoValues() throws {
    let hazards = try #require(try decode(.forecastGrid).hazards)
    #expect(hazards.values.isEmpty)
    #expect(hazards.unitCode == nil)
  }

  @Test(
    "A grid encodes and decodes to an equal value",
    arguments: [Fixture.forecastGrid, .forecastGridHazards])
  func aGridEncodesAndDecodesToAnEqualValue(fixture: Fixture) throws {
    let grid = try decode(fixture)
    let body = try JSONEncoder().encode(grid)
    #expect(try JSONDecoder().decode(ForecastGrid.self, from: body) == grid)
    let hazard = ForecastHazard(phenomenon: "FA", significance: "A")
    let hazardJSON = String(decoding: try JSONEncoder().encode(hazard), as: UTF8.self)
    #expect(hazardJSON.contains(#""event_number":null"#))
  }

  @Test("A consumer-defined layer set decodes from the recorded grid")
  func aConsumerDefinedLayerSetDecodesFromTheRecordedGrid() throws {
    let slim = try JSONDecoder().decode(
      Feature<TemperatureOnly>.self, from: Fixture.forecastGrid.data()
    ).properties
    #expect(slim.temperature.unitCode == "wmoUnit:degC")
    #expect(slim.temperature.values.first?.value == 33.333333333333336)
  }

  @Test("Consumer String-backed enums convert to layer names and weather codes")
  func consumerStringBackedEnumsConvertToLayerNamesAndWeatherCodes() {
    #expect(ForecastGridLayerName(AppLayer.temperature) == .temperature)
    #expect(ForecastWeatherAttribute(AppCode.heavyRain) == .heavyRain)
    #expect(ForecastWeatherCoverage(AppCode.slightChance) == .slightChance)
    #expect(ForecastWeatherIntensity(AppCode.veryLight) == .veryLight)
    #expect(ForecastWeatherPhenomenon(AppCode.rainShowers) == .rainShowers)
  }

  @Test("A layer name keys a JSON object by its raw name")
  func aLayerNameKeysAJSONObjectByItsRawName() throws {
    let body = try JSONEncoder().encode([ForecastGridLayerName.temperature: 1])
    #expect(String(decoding: body, as: UTF8.self) == #"{"temperature":1}"#)
  }

  @Test("A grid value pairs with its layer unit as a quantity")
  func aGridValuePairsWithItsLayerUnitAsAQuantity() throws {
    let grid = try decode(.forecastGrid)
    let temperature = try #require(grid[.temperature])
    let entry = try #require(temperature.values.first)
    #expect(
      entry.quantity(unitCode: temperature.unitCode)
        == QuantitativeValue(unitCode: "wmoUnit:degC", value: 33.333333333333336))
    let heatRisk = try #require(grid[.heatRisk]?.values.first)
    #expect(heatRisk.quantity(unitCode: nil) == nil)
  }

  private func decode(_ fixture: Fixture) throws -> ForecastGrid {
    try JSONDecoder().decode(Feature<ForecastGrid>.self, from: fixture.data()).properties
  }

  // The fields every grid carries, followed by the extra properties a test supplies.
  private static func minimalGrid(_ extra: String) -> Data {
    Data(
      (#"{"elevation":{"unitCode":"wmoUnit:m","value":155.1432},"#
        + #""forecastOffice":"https://api.weather.gov/offices/EWX","gridId":"EWX","gridX":156,"#
        + #""gridY":91,"updateTime":"2026-09-17T23:48:18+00:00","#
        + #""validTimes":"2026-09-17T17:00:00+00:00/P7DT8H""# + extra + "}").utf8)
  }
}

private struct TemperatureOnly: Decodable, Sendable {
  var temperature: ForecastGridLayer<Double?>
}

private enum AppLayer: String {
  case temperature
}

private enum AppCode: String {
  case heavyRain = "heavy_rain"
  case rainShowers = "rain_showers"
  case slightChance = "slight_chance"
  case veryLight = "very_light"
}

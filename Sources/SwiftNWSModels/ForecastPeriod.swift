#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One service-provided forecast period.
///
/// Dates decode as ISO 8601 independently of the decoder's date strategy.
///
/// ```swift
/// let summary = forecast.periods.first?.shortForecast
/// ```
public struct ForecastPeriod: Codable, Hashable, Sendable {
  /// The detailed forecast text.
  public var detailedForecast: String

  /// The hourly dewpoint, when reported.
  public var dewpoint: QuantitativeValue?

  /// The end of the period.
  public var endTime: Date

  /// The service's forecast icon link.
  public var icon: URL?

  /// Whether this is a daytime period.
  public var isDaytime: Bool

  /// The period name, which can be absent for hourly forecasts.
  public var name: String?

  /// The service's sequential period number.
  public var number: Int

  /// The probability of precipitation, including a null measurement.
  public var probabilityOfPrecipitation: QuantitativeValue?

  /// The hourly relative humidity, when reported.
  public var relativeHumidity: QuantitativeValue?

  /// The brief forecast text.
  public var shortForecast: String

  /// The start of the period.
  public var startTime: Date

  /// The temperature in the shape returned by the service.
  public var temperature: ForecastTemperature

  /// The temperature trend; unknown values are preserved.
  public var temperatureTrend: ForecastTemperatureTrend?

  /// The legacy temperature unit, when reported.
  public var temperatureUnit: ForecastTemperatureUnit?

  /// The wind direction; unknown values are preserved.
  public var windDirection: ForecastWindDirection

  /// The peak wind gust, when reported.
  public var windGust: ForecastWind?

  /// The wind speed in the shape returned by the service.
  public var windSpeed: ForecastWind

  /// Creates a forecast period from service values.
  ///
  /// - Parameters:
  ///   - detailedForecast: The detailed forecast text.
  ///   - dewpoint: The hourly dewpoint, when reported.
  ///   - endTime: The end of the period.
  ///   - icon: The service's forecast icon link.
  ///   - isDaytime: Whether this is a daytime period.
  ///   - name: The period name, which can be absent for hourly forecasts.
  ///   - number: The service's sequential period number.
  ///   - probabilityOfPrecipitation: The probability of precipitation, including a null measurement.
  ///   - relativeHumidity: The hourly relative humidity, when reported.
  ///   - shortForecast: The brief forecast text.
  ///   - startTime: The start of the period.
  ///   - temperature: The temperature in the shape returned by the service.
  ///   - temperatureTrend: The temperature trend; unknown values are preserved.
  ///   - temperatureUnit: The legacy temperature unit, when reported.
  ///   - windDirection: The wind direction; unknown values are preserved.
  ///   - windGust: The peak wind gust, when reported.
  ///   - windSpeed: The wind speed in the shape returned by the service.
  public init(
    detailedForecast: String,
    dewpoint: QuantitativeValue? = nil,
    endTime: Date,
    icon: URL? = nil,
    isDaytime: Bool,
    name: String? = nil,
    number: Int,
    probabilityOfPrecipitation: QuantitativeValue? = nil,
    relativeHumidity: QuantitativeValue? = nil,
    shortForecast: String,
    startTime: Date,
    temperature: ForecastTemperature,
    temperatureTrend: ForecastTemperatureTrend? = nil,
    temperatureUnit: ForecastTemperatureUnit? = nil,
    windDirection: ForecastWindDirection,
    windGust: ForecastWind? = nil,
    windSpeed: ForecastWind
  ) {
    self.detailedForecast = detailedForecast
    self.dewpoint = dewpoint
    self.endTime = endTime
    self.icon = icon
    self.isDaytime = isDaytime
    self.name = name
    self.number = number
    self.probabilityOfPrecipitation = probabilityOfPrecipitation
    self.relativeHumidity = relativeHumidity
    self.shortForecast = shortForecast
    self.startTime = startTime
    self.temperature = temperature
    self.temperatureTrend = temperatureTrend
    self.temperatureUnit = temperatureUnit
    self.windDirection = windDirection
    self.windGust = windGust
    self.windSpeed = windSpeed
  }

  /// Decodes service values, including ISO 8601 dates.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for missing or malformed required values.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      detailedForecast: try container.decode(String.self, forKey: .detailedForecast),
      dewpoint: try container.decodeIfPresent(QuantitativeValue.self, forKey: .dewpoint),
      endTime: try container.decodeISO8601(forKey: .endTime),
      icon: try container.decodeIfPresent(URL.self, forKey: .icon),
      isDaytime: try container.decode(Bool.self, forKey: .isDaytime),
      name: try container.decodeIfPresent(String.self, forKey: .name),
      number: try container.decode(Int.self, forKey: .number),
      probabilityOfPrecipitation: try container.decodeIfPresent(
        QuantitativeValue.self, forKey: .probabilityOfPrecipitation),
      relativeHumidity: try container.decodeIfPresent(
        QuantitativeValue.self, forKey: .relativeHumidity),
      shortForecast: try container.decode(String.self, forKey: .shortForecast),
      startTime: try container.decodeISO8601(forKey: .startTime),
      temperature: try container.decode(ForecastTemperature.self, forKey: .temperature),
      temperatureTrend: try container.decodeIfPresent(
        ForecastTemperatureTrend.self, forKey: .temperatureTrend),
      temperatureUnit: try container.decodeIfPresent(
        ForecastTemperatureUnit.self, forKey: .temperatureUnit),
      windDirection: try container.decode(ForecastWindDirection.self, forKey: .windDirection),
      windGust: try container.decodeIfPresent(ForecastWind.self, forKey: .windGust),
      windSpeed: try container.decode(ForecastWind.self, forKey: .windSpeed)
    )
  }

  /// Encodes service values with ISO 8601 dates.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(detailedForecast, forKey: .detailedForecast)
    try container.encodeIfPresent(dewpoint, forKey: .dewpoint)
    try container.encode(
      endTime.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)), forKey: .endTime
    )
    try container.encodeIfPresent(icon, forKey: .icon)
    try container.encode(isDaytime, forKey: .isDaytime)
    try container.encodeIfPresent(name, forKey: .name)
    try container.encode(number, forKey: .number)
    try container.encodeIfPresent(probabilityOfPrecipitation, forKey: .probabilityOfPrecipitation)
    try container.encodeIfPresent(relativeHumidity, forKey: .relativeHumidity)
    try container.encode(shortForecast, forKey: .shortForecast)
    try container.encode(
      startTime.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
      forKey: .startTime)
    try container.encode(temperature, forKey: .temperature)
    try container.encodeIfPresent(temperatureTrend, forKey: .temperatureTrend)
    try container.encodeIfPresent(temperatureUnit, forKey: .temperatureUnit)
    try container.encode(windDirection, forKey: .windDirection)
    try container.encodeIfPresent(windGust, forKey: .windGust)
    try container.encode(windSpeed, forKey: .windSpeed)
  }

  private enum CodingKeys: String, CodingKey {
    case detailedForecast
    case dewpoint
    case endTime
    case icon
    case isDaytime
    case name
    case number
    case probabilityOfPrecipitation
    case relativeHumidity
    case shortForecast
    case startTime
    case temperature
    case temperatureTrend
    case temperatureUnit
    case windDirection
    case windGust
    case windSpeed
  }
}

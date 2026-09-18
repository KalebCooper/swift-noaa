#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A twelve-hour or hourly forecast for a grid cell.
///
/// Dates decode as ISO 8601 independently of the decoder's date strategy.
///
/// ```swift
/// let forecast = try JSONDecoder().decode(Feature<WeatherForecast>.self, from: body).properties
/// ```
public struct WeatherForecast: Codable, Hashable, Sendable {
  /// The grid cell's elevation.
  public var elevation: QuantitativeValue

  /// The service's forecast generator identifier.
  public var forecastGenerator: String?

  /// When the service generated the forecast.
  public var generatedAt: Date

  /// The forecast periods in service order.
  public var periods: [ForecastPeriod]

  /// The unit system reported by the service; unknown values are preserved.
  public var units: ForecastUnits

  /// When the underlying forecast data was updated.
  public var updateTime: Date

  /// The interval the forecast covers, with its exact text retained.
  public var validTimes: ValidTimeInterval

  /// Creates a forecast from service values.
  ///
  /// - Parameters:
  ///   - elevation: The grid cell's elevation.
  ///   - forecastGenerator: The service's forecast generator identifier.
  ///   - generatedAt: When the service generated the forecast.
  ///   - periods: The forecast periods in service order.
  ///   - units: The unit system reported by the service; unknown values are preserved.
  ///   - updateTime: When the underlying forecast data was updated.
  ///   - validTimes: The interval the forecast covers.
  public init(
    elevation: QuantitativeValue,
    forecastGenerator: String? = nil,
    generatedAt: Date,
    periods: [ForecastPeriod],
    units: ForecastUnits,
    updateTime: Date,
    validTimes: ValidTimeInterval
  ) {
    self.elevation = elevation
    self.forecastGenerator = forecastGenerator
    self.generatedAt = generatedAt
    self.periods = periods
    self.units = units
    self.updateTime = updateTime
    self.validTimes = validTimes
  }

  /// Decodes service values, including ISO 8601 dates.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for missing or malformed required values, including a `validTimes`
  ///   that is not an ISO 8601 start and duration.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      elevation: try container.decode(QuantitativeValue.self, forKey: .elevation),
      forecastGenerator: try container.decodeIfPresent(String.self, forKey: .forecastGenerator),
      generatedAt: try container.decodeISO8601(forKey: .generatedAt),
      periods: try container.decode([ForecastPeriod].self, forKey: .periods),
      units: try container.decode(ForecastUnits.self, forKey: .units),
      updateTime: try container.decodeISO8601(forKey: .updateTime),
      validTimes: try container.decode(ValidTimeInterval.self, forKey: .validTimes)
    )
  }

  /// Encodes service values with ISO 8601 dates.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(elevation, forKey: .elevation)
    try container.encodeIfPresent(forecastGenerator, forKey: .forecastGenerator)
    try container.encode(
      generatedAt.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
      forKey: .generatedAt)
    try container.encode(periods, forKey: .periods)
    try container.encode(units, forKey: .units)
    try container.encode(
      updateTime.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
      forKey: .updateTime)
    try container.encode(validTimes, forKey: .validTimes)
  }

  private enum CodingKeys: String, CodingKey {
    case elevation
    case forecastGenerator
    case generatedAt
    case periods
    case units
    case updateTime
    case validTimes
  }
}

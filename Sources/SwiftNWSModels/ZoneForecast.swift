#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A zone's text forecast, as `/zones/{type}/{zoneId}/forecast` describes it.
///
/// The service sends the forecast as a GeoJSON feature whose geometry is the zone's polygon;
/// ``Feature/geometry`` retains it. The forecast accepts no units or feature flags, so its periods
/// carry only text. The update instant decodes as ISO 8601 independently of the decoder's date
/// strategy.
///
/// ```swift
/// let forecast = try JSONDecoder().decode(Feature<ZoneForecast>.self, from: body).properties
/// print(forecast.updated, forecast.periods.count)
/// ```
public struct ZoneForecast: Codable, Hashable, Sendable {
  /// The forecast periods in service order.
  public var periods: [ZoneForecastPeriod]

  /// When the service last updated the forecast.
  public var updated: Date

  /// A link to the zone the forecast covers.
  public var zone: URL

  /// Creates a zone forecast.
  ///
  /// - Parameters:
  ///   - periods: The forecast periods in service order.
  ///   - updated: When the service last updated the forecast.
  ///   - zone: A link to the zone the forecast covers.
  public init(periods: [ZoneForecastPeriod], updated: Date, zone: URL) {
    self.periods = periods
    self.updated = updated
    self.zone = zone
  }

  /// Decodes a zone forecast, reading its update instant as ISO 8601 text.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for a missing field or an update instant that is not ISO 8601.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      periods: try container.decode([ZoneForecastPeriod].self, forKey: .periods),
      updated: try container.decodeISO8601(forKey: .updated),
      zone: try container.decode(URL.self, forKey: .zone)
    )
  }

  /// Encodes the forecast, writing its update instant as ISO 8601 text.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(periods, forKey: .periods)
    try container.encode(
      updated.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
      forKey: .updated)
    try container.encode(zone, forKey: .zone)
  }

  private enum CodingKeys: String, CodingKey {
    case periods
    case updated
    case zone
  }
}

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One named period of a zone forecast, as `/zones/{type}/{zoneId}/forecast` describes it.
///
/// A zone period is text only. Unlike a grid ``ForecastPeriod``, the service sends no start or end
/// instant, temperature, wind, or icon for it, and nothing about its duration can be inferred from
/// its name. Periods are kept in service order with their numbers as sent.
///
/// ```swift
/// for period in forecast.periods {
///   print(period.number, period.name, period.detailedForecast)
/// }
/// ```
public struct ZoneForecastPeriod: Codable, Hashable, Sendable {
  /// The forecast text for the period.
  public var detailedForecast: String

  /// The period's name, such as `Tonight` or `Tuesday Night through Saturday`.
  public var name: String

  /// The service's period number, as sent.
  public var number: Int

  /// Creates a zone forecast period.
  ///
  /// - Parameters:
  ///   - detailedForecast: The forecast text for the period.
  ///   - name: The period's name.
  ///   - number: The service's period number.
  public init(detailedForecast: String, name: String, number: Int) {
    self.detailedForecast = detailedForecast
    self.name = name
    self.number = number
  }
}

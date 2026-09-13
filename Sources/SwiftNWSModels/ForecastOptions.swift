/// Explicit forecast response options.
///
/// ```swift
/// let options = ForecastOptions(featureFlags: [.temperatureQuantity, .windSpeedQuantity], units: .si)
/// ```
public struct ForecastOptions: Hashable, Sendable {
  /// A supported opt-in forecast representation.
  public enum FeatureFlag: String, CaseIterable, Hashable, Sendable {
    /// Returns temperature as a quantitative value.
    case temperatureQuantity = "forecast_temperature_qv"
    /// Returns wind speed and gusts as quantitative values.
    case windSpeedQuantity = "forecast_wind_speed_qv"
  }

  /// The requested forecast unit system.
  public enum Units: String, CaseIterable, Hashable, Sendable {
    /// International System units.
    case si
    /// United States customary units.
    case us
  }

  /// The explicitly requested representation flags.
  public var featureFlags: Set<FeatureFlag>

  /// The requested unit system.
  public var units: Units

  /// Creates forecast options.
  /// - Parameters:
  ///   - featureFlags: Opt-in representations; empty preserves the service default.
  ///   - units: The requested unit system, defaulting to US customary.
  public init(featureFlags: Set<FeatureFlag> = [], units: Units = .us) {
    self.featureFlags = featureFlags
    self.units = units
  }
}

/// Explicit forecast response options.
///
/// ```swift
/// let options = ForecastOptions(featureFlags: [.temperatureQuantity, .windSpeedQuantity], units: .si)
/// ```
public struct ForecastOptions: Hashable, Sendable {
  /// The explicitly requested representation flags.
  public var featureFlags: Set<NWSFeatureFlag>

  /// The requested unit system.
  public var units: ForecastUnits

  /// Creates forecast options from library code values.
  /// - Parameters:
  ///   - featureFlags: Opt-in representations; empty preserves the service default.
  ///   - units: The requested unit system, defaulting to US customary.
  public init(featureFlags: Set<NWSFeatureFlag> = [], units: ForecastUnits = .us) {
    self.featureFlags = featureFlags
    self.units = units
  }

  /// Creates forecast options using a consumer-defined feature flag enum.
  /// - Parameters:
  ///   - featureFlags: String-backed opt-in representations.
  ///   - units: The requested unit system, defaulting to US customary.
  public init<Flag>(featureFlags: Set<Flag>, units: ForecastUnits = .us)
  where Flag: Hashable & RawRepresentable, Flag.RawValue == String {
    var converted: Set<NWSFeatureFlag> = []
    converted.reserveCapacity(featureFlags.count)
    for featureFlag in featureFlags {
      converted.insert(NWSFeatureFlag(featureFlag))
    }
    self.init(featureFlags: converted, units: units)
  }

  /// Creates forecast options using consumer-defined feature flag and unit enums.
  /// - Parameters:
  ///   - featureFlags: String-backed opt-in representations.
  ///   - units: A String-backed unit system.
  public init<Flag, Units>(featureFlags: Set<Flag>, units: Units)
  where
    Flag: Hashable & RawRepresentable, Flag.RawValue == String,
    Units: RawRepresentable, Units.RawValue == String
  {
    var converted: Set<NWSFeatureFlag> = []
    converted.reserveCapacity(featureFlags.count)
    for featureFlag in featureFlags {
      converted.insert(NWSFeatureFlag(featureFlag))
    }
    self.init(featureFlags: converted, units: ForecastUnits(units))
  }

  /// Creates forecast options using a consumer-defined unit enum.
  /// - Parameters:
  ///   - featureFlags: Opt-in representations; empty preserves the service default.
  ///   - units: A String-backed unit system.
  public init<Units>(featureFlags: Set<NWSFeatureFlag> = [], units: Units)
  where Units: RawRepresentable, Units.RawValue == String {
    self.init(featureFlags: featureFlags, units: ForecastUnits(units))
  }
}

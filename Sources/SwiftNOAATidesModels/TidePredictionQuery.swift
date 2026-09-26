#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An explicit GMT request for sampled tide predictions.
///
/// Use `try TidePredictionQuery(datum: .meanLowerLowWater, interval: .hourly, range: window,
/// stationIdentifier: station, units: .metric)`. Subordinate stations do not support samples;
/// support is determined by NOAA without a hidden station lookup.
public struct TidePredictionQuery: Hashable, Sendable {
  /// The requested vertical datum, not echoed by the prediction response.
  public let datum: TideDatum
  /// The requested sampling cadence.
  public let interval: TidePredictionInterval
  /// Inclusive minute bounds, limited to one Gregorian calendar year.
  public let range: TidesDateRange
  /// The exact requested station identifier.
  public let stationIdentifier: CoastalStationIdentifier
  /// Requested units: metric heights are meters, English heights are feet.
  public let units: TidesUnits

  /// Validates a sampled tide prediction query without I/O.
  /// - Parameters:
  ///   - datum: A nonempty provider datum code without controls.
  ///   - interval: A supported sampled cadence.
  ///   - range: An explicit window no longer than one calendar year.
  ///   - stationIdentifier: A validated station identifier.
  ///   - units: A nonempty provider unit-system code without controls.
  /// - Throws: `TidesQueryError.invalidDatum`, `TidesQueryError.invalidUnits`, or `TidesQueryError.rangeTooLong`.
  public init(
    datum: TideDatum, interval: TidePredictionInterval, range: TidesDateRange,
    stationIdentifier: CoastalStationIdentifier,
    units: TidesUnits
  ) throws(TidesQueryError) {
    guard !datum.rawValue.isEmpty,
      !datum.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidDatum(datum.rawValue) }
    guard !units.rawValue.isEmpty,
      !units.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidUnits(units.rawValue) }
    try range.validate(maximumMonths: 12)
    self.datum = datum
    self.interval = interval
    self.range = range
    self.stationIdentifier = stationIdentifier
    self.units = units
  }
}

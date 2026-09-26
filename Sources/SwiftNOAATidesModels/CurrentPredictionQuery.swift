#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An explicit GMT request for sampled current predictions.
///
/// Use `try CurrentPredictionQuery(bin: .explicit(4), interval: .hourly, mode: .major, range: window,
/// stationIdentifier: station, units: .metric)`. Availability is determined by NOAA;
/// the query does not request latest data, infer station capabilities, or fill missing observations.
public struct CurrentPredictionQuery: Hashable, Sendable {
  /// A positive explicit bin or an intentional provider default, never all bins.
  public let bin: CurrentBinSelection
  /// Requested sampling cadence; max/slack events use their own query.
  public let interval: CurrentPredictionInterval
  /// Requested velocity representation, which is not proof of the returned shape.
  public let mode: CurrentPredictionMode
  /// Inclusive minute bounds, limited to one Gregorian calendar month.
  public let range: TidesDateRange
  /// The exact requested station identifier.
  public let stationIdentifier: CoastalStationIdentifier
  /// Requested velocity units: metric is centimeters per second, English is knots.
  public let units: TidesUnits

  /// Validates a current prediction query without I/O.
  /// - Parameters:
  ///   - bin: A positive explicit bin or the provider default.
  ///   - interval: A supported sampled cadence.
  ///   - mode: The requested major-axis or speed/direction representation.
  ///   - range: An explicit window no longer than one calendar month.
  ///   - stationIdentifier: A validated station identifier.
  ///   - units: A nonempty provider unit-system code without controls.
  /// - Throws: `TidesQueryError.invalidBin`, `TidesQueryError.invalidUnits`, or `TidesQueryError.rangeTooLong`.
  public init(
    bin: CurrentBinSelection, interval: CurrentPredictionInterval, mode: CurrentPredictionMode,
    range: TidesDateRange, stationIdentifier: CoastalStationIdentifier,
    units: TidesUnits
  ) throws(TidesQueryError) {
    try bin.validate()
    guard !units.rawValue.isEmpty,
      !units.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidUnits(units.rawValue) }
    try range.validate(maximumMonths: 1)
    self.bin = bin
    self.interval = interval
    self.mode = mode
    self.range = range
    self.stationIdentifier = stationIdentifier
    self.units = units
  }
}

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An explicit GMT request for six-minute measured currents.
///
/// Use `try CurrentObservationQuery(bin: .explicit(4), range: window,
/// stationIdentifier: station, units: .metric)`. Availability is determined by NOAA;
/// the query does not request latest data, infer quality, or fill missing observations.
public struct CurrentObservationQuery: Hashable, Sendable {
  /// A positive explicit bin or an intentional provider default, never all bins.
  public let bin: CurrentBinSelection
  /// Inclusive minute bounds, limited to one Gregorian calendar month.
  public let range: TidesDateRange
  /// The exact requested station identifier.
  public let stationIdentifier: CoastalStationIdentifier
  /// Requested velocity units: metric is centimeters per second, English is knots.
  public let units: TidesUnits

  /// Validates a current observation query without I/O.
  /// - Parameters:
  ///   - bin: A positive explicit bin or the provider default.
  ///   - range: An explicit window no longer than one calendar month.
  ///   - stationIdentifier: A validated station identifier.
  ///   - units: A nonempty provider unit-system code without controls.
  /// - Throws: `TidesQueryError.invalidBin`, `TidesQueryError.invalidUnits`, or `TidesQueryError.rangeTooLong`.
  public init(
    bin: CurrentBinSelection, range: TidesDateRange, stationIdentifier: CoastalStationIdentifier,
    units: TidesUnits
  ) throws(TidesQueryError) {
    try bin.validate()
    guard !units.rawValue.isEmpty,
      !units.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidUnits(units.rawValue) }
    try range.validate(maximumMonths: 1)
    self.bin = bin
    self.range = range
    self.stationIdentifier = stationIdentifier
    self.units = units
  }
}

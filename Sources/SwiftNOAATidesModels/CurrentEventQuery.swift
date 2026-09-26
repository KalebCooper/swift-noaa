#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An explicit GMT request for predicted current events.
///
/// Use `try CurrentEventQuery(bin: .explicit(4), range: window,
/// stationIdentifier: station, units: .metric)`. Availability is determined by NOAA;
/// the query always selects max/slack events and major-axis velocity, never speed/direction.
public struct CurrentEventQuery: Hashable, Sendable {
  /// A positive explicit bin or an intentional provider default, never all bins.
  public let bin: CurrentBinSelection
  /// Inclusive minute bounds, limited to one Gregorian calendar year.
  public let range: TidesDateRange
  /// The exact requested station identifier.
  public let stationIdentifier: CoastalStationIdentifier
  /// Requested velocity units: metric is centimeters per second, English is knots.
  public let units: TidesUnits

  /// Validates a current prediction query without I/O.
  /// - Parameters:
  ///   - bin: A positive explicit bin or the provider default.
  ///   - range: An explicit window no longer than one calendar year.
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
    try range.validate(maximumMonths: 12)
    self.bin = bin
    self.range = range
    self.stationIdentifier = stationIdentifier
    self.units = units
  }
}

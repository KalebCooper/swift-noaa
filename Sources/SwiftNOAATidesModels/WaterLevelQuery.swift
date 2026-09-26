#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An explicit GMT request for six-minute measured water levels.
///
/// Use `try WaterLevelQuery(datum: .meanLowerLowWater, range: window,
/// stationIdentifier: station, units: .metric)`. Availability is determined by NOAA;
/// the query does not request latest data, infer quality, or fill missing observations.
public struct WaterLevelQuery: Hashable, Sendable {
  /// The requested vertical datum, not echoed by the observation response.
  public let datum: TideDatum
  /// Inclusive minute bounds, limited to one Gregorian calendar month.
  public let range: TidesDateRange
  /// The exact requested station identifier.
  public let stationIdentifier: CoastalStationIdentifier
  /// Requested units: metric heights are meters, English heights are feet.
  public let units: TidesUnits

  /// Validates a water-level observation query without I/O.
  /// - Parameters:
  ///   - datum: A nonempty provider datum code without controls.
  ///   - range: An explicit window no longer than one calendar month.
  ///   - stationIdentifier: A validated station identifier.
  ///   - units: A nonempty provider unit-system code without controls.
  /// - Throws: `TidesQueryError.invalidDatum`, `TidesQueryError.invalidUnits`, or `TidesQueryError.rangeTooLong`.
  public init(
    datum: TideDatum, range: TidesDateRange, stationIdentifier: CoastalStationIdentifier,
    units: TidesUnits
  ) throws(TidesQueryError) {
    guard !datum.rawValue.isEmpty,
      !datum.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidDatum(datum.rawValue) }
    guard !units.rawValue.isEmpty,
      !units.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidUnits(units.rawValue) }
    try range.validate(maximumMonths: 1)
    self.datum = datum
    self.range = range
    self.stationIdentifier = stationIdentifier
    self.units = units
  }
}

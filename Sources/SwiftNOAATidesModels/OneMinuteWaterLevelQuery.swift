#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An explicit GMT request for one-minute measured water levels.
///
/// Use `try OneMinuteWaterLevelQuery(datum: .meanLowerLowWater, range: window,
/// stationIdentifier: station, units: .metric)`. Availability is determined by NOAA;
/// the query does not request latest data, infer quality, or fill missing observations.
public struct OneMinuteWaterLevelQuery: Hashable, Sendable {
  /// The requested vertical datum, not echoed by the observation response.
  public let datum: TideDatum
  /// Inclusive minute bounds, limited to four Gregorian calendar days.
  public let range: TidesDateRange
  /// The exact requested station identifier.
  public let stationIdentifier: CoastalStationIdentifier
  /// Requested units: metric heights are meters, English heights are feet.
  public let units: TidesUnits

  /// Validates a water-level observation query without I/O.
  /// - Parameters:
  ///   - datum: A nonempty provider datum code without controls.
  ///   - range: An explicit window no longer than four calendar days.
  ///   - stationIdentifier: A validated station identifier.
  ///   - units: A nonempty provider unit-system code without controls.
  /// - Throws: `TidesQueryError.invalidDatum`, `TidesQueryError.invalidUnits`, or `TidesQueryError.rangeTooLongDays`.
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
    try range.validate(maximumDays: 4)
    self.datum = datum
    self.range = range
    self.stationIdentifier = stationIdentifier
    self.units = units
  }
}

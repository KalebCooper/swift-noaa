#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An explicit GMT request for verified observed high/low water levels.
///
/// Use `try ObservedHighLowWaterLevelQuery(datum: .meanLowerLowWater, range: window,
/// stationIdentifier: station, units: .metric)`. Availability is determined by NOAA;
/// the query does not request latest data, infer quality, or fill missing observations.
public struct ObservedHighLowWaterLevelQuery: Hashable, Sendable {
  /// The requested vertical datum, not echoed by the observation response.
  public let datum: TideDatum
  /// Inclusive minute bounds, limited to twelve Gregorian calendar months.
  public let range: TidesDateRange
  /// The exact requested station identifier.
  public let stationIdentifier: CoastalStationIdentifier
  /// Requested units: metric heights are meters, English heights are feet.
  public let units: TidesUnits

  /// Validates a water-level observation query without I/O.
  /// - Parameters:
  ///   - datum: A nonempty provider datum code without controls.
  ///   - range: An explicit window no longer than twelve calendar months.
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
    try range.validate(maximumMonths: 12)
    self.datum = datum
    self.range = range
    self.stationIdentifier = stationIdentifier
    self.units = units
  }
}

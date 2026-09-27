/// Explicit station, datum and units for NOAA's latest available water level.
/// This selector has no local clock or date range. NOAA uses an eighteen-minute availability window.
public struct LatestWaterLevelQuery: Hashable, Sendable {
  /// The requested vertical datum, not echoed by the observation response.
  public let datum: TideDatum
  /// The exact requested station identifier.
  public let stationIdentifier: CoastalStationIdentifier
  /// Requested units: metric heights are meters, English heights are feet.
  public let units: TidesUnits

  /// Validates a water-level observation query without I/O.
  /// - Parameters:
  ///   - datum: A nonempty provider datum code without controls.
  ///   - stationIdentifier: A validated station identifier.
  ///   - units: A nonempty provider unit-system code without controls.
  /// - Throws: `TidesQueryError.invalidDatum`, `TidesQueryError.invalidUnits`.
  public init(
    datum: TideDatum, stationIdentifier: CoastalStationIdentifier,
    units: TidesUnits
  ) throws(TidesQueryError) {
    guard !datum.rawValue.isEmpty,
      !datum.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidDatum(datum.rawValue) }
    guard !units.rawValue.isEmpty,
      !units.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidUnits(units.rawValue) }
    self.datum = datum
    self.stationIdentifier = stationIdentifier
    self.units = units
  }
}

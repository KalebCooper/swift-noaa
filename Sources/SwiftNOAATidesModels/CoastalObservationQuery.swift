/// An explicit GMT query for station weather and physical-oceanographic observations.
///
/// Use `try CoastalObservationQuery(interval: .sixMinutes, range: window,
/// stationIdentifier: station, units: .metric)`. Each named factory fixes the product.
/// No datum, bin, preflight, relative selector, or local averaging is involved.
public struct CoastalObservationQuery: Hashable, Sendable {
  /// Native samples or on-hour selection.
  public let interval: CoastalObservationInterval
  /// Inclusive GMT bounds, limited to one calendar month for six-minute data or twelve for hourly data.
  public let range: TidesDateRange
  /// The exact requested station, independent of response metadata.
  public let stationIdentifier: CoastalStationIdentifier
  /// Requested unit system; each product documents its physical units separately.
  public let units: TidesUnits

  /// Validates a station observation request without I/O.
  /// - Parameters:
  ///   - interval: The explicitly selected cadence.
  ///   - range: Inclusive GMT minute bounds.
  ///   - stationIdentifier: A validated station identifier.
  ///   - units: A nonempty unit code without controls.
  /// - Throws: `TidesQueryError.invalidUnits` or `TidesQueryError.rangeTooLong`.
  public init(
    interval: CoastalObservationInterval, range: TidesDateRange,
    stationIdentifier: CoastalStationIdentifier, units: TidesUnits
  ) throws(TidesQueryError) {
    guard !units.rawValue.isEmpty,
      !units.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidUnits(units.rawValue) }
    try range.validate(maximumMonths: interval == .hourly ? 12 : 1)
    self.interval = interval
    self.range = range
    self.stationIdentifier = stationIdentifier
    self.units = units
  }
}

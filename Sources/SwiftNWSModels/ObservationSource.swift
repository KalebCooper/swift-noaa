/// Where to retrieve a station's latest observation.
public enum ObservationSource: Hashable, Sendable {
  /// Uses the first station listed for the coordinate's forecast grid.
  ///
  /// This preserves the service's ordering; it does not calculate distances. The API does not
  /// guarantee that this station is geographically closest to the exact coordinate.
  case nearest(to: WeatherCoordinate)

  /// Uses an explicit station identifier, such as `KATT`.
  ///
  /// Identifiers are open strings and are encoded as one path segment. The SDK rejects an empty
  /// identifier before sending a request.
  case station(String)
}

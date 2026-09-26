/// A local query validation failure, before any network request.
public enum TidesQueryError: Error, Hashable, Sendable {
  /// The station identifier is empty or contains unsupported characters.
  case invalidStationIdentifier(String)
  /// The directory type is empty or contains control characters.
  case invalidStationType(String)
}

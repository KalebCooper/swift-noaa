/// Verified hourly water levels with provider metadata and separate requested context.
///
/// Returned by `hourlyWaterLevels(matching:)`. Predictions are not subtracted and gaps are not filled.
public struct HourlyWaterLevels: Hashable, Sendable {
  /// Provider-reported station metadata, not reconstructed from the query.
  public let metadata: CoastalDataMetadata
  /// Observations in provider order, preserving missing quantities and time steps.
  public let observations: [HourlyWaterLevel]
  /// The original requested datum, units, station and inclusive GMT bounds.
  public let requestedQuery: HourlyWaterLevelQuery

  /// Combines decoded measurements and their original requested context.
  /// - Parameters:
  ///   - metadata: The provider's echoed metadata.
  ///   - observations: The unchanged observations.
  ///   - requestedQuery: The actual query that produced the response.
  public init(
    metadata: CoastalDataMetadata, observations: [HourlyWaterLevel],
    requestedQuery: HourlyWaterLevelQuery
  ) {
    self.metadata = metadata
    self.observations = observations
    self.requestedQuery = requestedQuery
  }
}

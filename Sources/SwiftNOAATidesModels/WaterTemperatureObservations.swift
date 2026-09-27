/// Measured water temperature observations with provider metadata and separate requested context.
///
/// Returned by `waterTemperatureObservations(matching:)`. Values are not converted and gaps are not filled.
public struct WaterTemperatureObservations: Hashable, Sendable {
  /// Provider-reported station metadata, not reconstructed from the query.
  public let metadata: CoastalDataMetadata
  /// Observations in provider order, preserving missing quantities and time steps.
  public let observations: [WaterTemperatureObservation]
  /// The original requested cadence, units, station and inclusive GMT bounds.
  public let requestedQuery: CoastalObservationQuery

  /// Combines decoded measurements and their original requested context.
  /// - Parameters:
  ///   - metadata: The provider's echoed metadata.
  ///   - observations: The unchanged observations.
  ///   - requestedQuery: The actual query that produced the response.
  public init(
    metadata: CoastalDataMetadata, observations: [WaterTemperatureObservation],
    requestedQuery: CoastalObservationQuery
  ) {
    self.metadata = metadata
    self.observations = observations
    self.requestedQuery = requestedQuery
  }
}

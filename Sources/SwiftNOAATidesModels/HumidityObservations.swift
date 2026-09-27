/// Measured humidity observations with provider metadata and separate requested context.
///
/// Returned by `humidityObservations(matching:)`. Missing samples remain gaps.
public struct HumidityObservations: Hashable, Sendable {
  /// Provider-reported station metadata, not reconstructed from the query.
  public let metadata: CoastalDataMetadata
  /// Observations in provider order, preserving missing quantities and time steps.
  public let observations: [HumidityObservation]
  /// The original requested cadence, units, station and inclusive GMT bounds.
  public let requestedQuery: CoastalObservationQuery

  /// Combines decoded measurements and their original requested context.
  /// - Parameters:
  ///   - metadata: The provider's echoed metadata.
  ///   - observations: The unchanged observations.
  ///   - requestedQuery: The actual query that produced the response.
  public init(
    metadata: CoastalDataMetadata, observations: [HumidityObservation],
    requestedQuery: CoastalObservationQuery
  ) {
    self.metadata = metadata
    self.observations = observations
    self.requestedQuery = requestedQuery
  }
}

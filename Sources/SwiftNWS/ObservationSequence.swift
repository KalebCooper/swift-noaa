import SwiftNWSModels

/// A lazy sequence of observation-history features, preserving GeoJSON metadata and service order.
/// Fetches another page only after the current page's features have been consumed.
/// Each iterator starts independently. Any error ends its traversal.
///
/// ```swift
/// let query = try ObservationQuery(limit: 24, stationIdentifier: "KATT")
/// for try await observation in client.observations(matching: query) {
///   print(observation.properties.timestamp, observation.properties.temperature?.value ?? .nan)
///   break
/// }
/// ```
public struct ObservationSequence: AsyncSequence, Sendable {
  /// One feature with its GeoJSON metadata.
  public typealias Element = Feature<WeatherObservation>
  /// A failure retrieving or validating a page.
  public typealias Failure = NWSError

  /// An independent traversal retaining only the current page's features.
  public struct Iterator: AsyncIteratorProtocol {
    private var features: CollectionFeatureSequence<WeatherObservation>.Iterator

    init(_ pages: ObservationPageSequence) {
      self.features = CollectionFeatureSequence(pages: pages.pages).makeAsyncIterator()
    }

    /// Returns the next feature, checking cancellation even while a page is buffered.
    /// - Parameter actor: The caller's isolation, forwarded through page fetching. Read an iterator
    ///   serially; concurrent calls to the same iterator are unsupported.
    /// - Throws: The same errors as the page sequence. Any error finishes this iterator.
    public mutating func next(
      isolation actor: isolated (any Actor)? = #isolation
    ) async throws(NWSError) -> Element? {
      try await features.next(isolation: actor)
    }
  }

  private let pages: ObservationPageSequence

  init(pages: ObservationPageSequence) { self.pages = pages }

  /// Creates an independent iterator without sending a request.
  public func makeAsyncIterator() -> Iterator { Iterator(pages) }
}

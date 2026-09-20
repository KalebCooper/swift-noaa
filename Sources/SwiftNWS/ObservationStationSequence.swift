import SwiftNWSModels

/// A lazy sequence of station-directory features, preserving GeoJSON metadata and service order.
/// Fetches another page only after the current page's features have been consumed.
/// Each iterator starts independently. Any error ends its traversal.
///
/// ```swift
/// let query = try ObservationStationQuery(states: [.texas])
/// for try await station in client.observationStations(query: query) {
///   print(station.properties.stationIdentifier)
///   break
/// }
/// ```
public struct ObservationStationSequence: AsyncSequence, Sendable {
  /// One feature with its GeoJSON metadata.
  public typealias Element = Feature<ObservationStation>
  /// A failure retrieving or validating a page.
  public typealias Failure = NWSError

  /// An independent traversal retaining only the current page's features.
  public struct Iterator: AsyncIteratorProtocol {
    private var features: CollectionFeatureSequence<ObservationStation>.Iterator

    init(_ pages: ObservationStationPageSequence) {
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

  private let pages: ObservationStationPageSequence

  init(pages: ObservationStationPageSequence) { self.pages = pages }

  /// Creates an independent iterator without sending a request.
  public func makeAsyncIterator() -> Iterator { Iterator(pages) }
}

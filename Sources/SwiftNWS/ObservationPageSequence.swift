import SwiftNWSModels

/// A lazy sequence of observation-history pages in service order.
///
/// No request is sent until iteration. Each iterator starts independently and fetches only on
/// demand. An empty page can continue. Stop when you have enough; traversal need not be finite.
/// Invalid continuation metadata throws before its page is returned. Any error ends the iterator.
///
/// ```swift
/// let query = try ObservationQuery(limit: 24, stationIdentifier: "KATT")
/// for try await page in client.observationPages(matching: query) {
///   print(page.features.count)
///   break
/// }
/// ```
public struct ObservationPageSequence: AsyncSequence, Sendable {
  /// One complete GeoJSON page.
  public typealias Element = FeatureCollection<WeatherObservation>
  /// A failure retrieving or validating a page.
  public typealias Failure = NWSError

  /// An independent traversal, finished after a terminal page or any error.
  public struct Iterator: AsyncIteratorProtocol {
    private var pages: CollectionPageSequence<WeatherObservation>.Iterator

    init(_ pages: CollectionPageSequence<WeatherObservation>) {
      self.pages = pages.makeAsyncIterator()
    }

    /// Fetches a page on demand, validating its continuation before returning it.
    /// - Parameter actor: The caller's isolation, forwarded through page fetching. Read an iterator
    ///   serially; concurrent calls to the same iterator are unsupported.
    /// - Throws: A pagination, redirect, problem-detail, transport, or cancellation error.
    public mutating func next(
      isolation actor: isolated (any Actor)? = #isolation
    ) async throws(NWSError) -> Element? {
      try await pages.next(isolation: actor)
    }
  }

  let pages: CollectionPageSequence<WeatherObservation>

  init(client: NWSClient, endpoint: Endpoint<Element>, followsLinks: Bool) {
    self.pages = CollectionPageSequence(
      client: client, endpoint: endpoint, followsLinks: followsLinks)
  }

  /// Creates an independent iterator without sending a request.
  public func makeAsyncIterator() -> Iterator { Iterator(pages) }
}

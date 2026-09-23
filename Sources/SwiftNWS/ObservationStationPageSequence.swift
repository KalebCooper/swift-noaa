import SwiftNWSModels

/// A lazy sequence of station-directory pages in service order.
///
/// A station-directory query follows continuation links. A nearby-station request resolves its
/// coordinate's point on the first read and yields exactly one page. A forecast-zone request
/// validates its identifier on the first read and yields exactly one page. No request is sent until
/// iteration. Each iterator starts independently and fetches only on
/// demand. An empty page can continue. Stop when you have enough; traversal need not be finite.
/// Invalid continuation metadata throws before its page is returned. Any error ends the iterator.
///
/// ```swift
/// let query = try ObservationStationQuery(states: [.texas])
/// for try await page in client.observationStationPages(matching: query) {
///   print(page.features.count)
///   break
/// }
/// ```
public struct ObservationStationPageSequence: AsyncSequence, Sendable {
  /// One complete GeoJSON page.
  public typealias Element = FeatureCollection<ObservationStation>
  /// A failure retrieving or validating a page.
  public typealias Failure = NWSError

  /// An independent traversal, finished after a terminal page or any error.
  public struct Iterator: AsyncIteratorProtocol {
    private var pages: CollectionPageSequence<ObservationStation>.Iterator

    init(_ pages: CollectionPageSequence<ObservationStation>) {
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

  let pages: CollectionPageSequence<ObservationStation>

  init(client: NWSClient, endpoint: Endpoint<Element>, followsLinks: Bool) {
    self.pages = CollectionPageSequence(
      client: client, endpoint: endpoint, followsLinks: followsLinks)
  }

  init(client: NWSClient, forecastZone identifier: String) {
    self.pages = CollectionPageSequence(
      client: client, followsLinks: false, start: .forecastZoneStations(identifier))
  }

  init(client: NWSClient, nearby location: WeatherCoordinate) {
    self.pages = CollectionPageSequence(
      client: client, followsLinks: false, start: .nearbyObservationStations(location))
  }

  /// Creates an independent iterator without sending a request.
  public func makeAsyncIterator() -> Iterator { Iterator(pages) }
}

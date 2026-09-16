import SwiftNWSModels

/// A lazy sequence of active-alert pages in service order.
///
/// No request is sent until iteration. Each iterator starts independently and fetches only on
/// demand. An empty page can continue. Stop when you have enough; traversal need not be finite.
/// Invalid continuation metadata throws before its page is returned. Any error ends the iterator.
///
/// ```swift
/// for try await page in client.activeAlertPages(matching: .init(severity: [.severe])) {
///   print(page.features.count)
///   break
/// }
/// ```
public struct ActiveAlertPageSequence: AsyncSequence, Sendable {
  /// One complete GeoJSON page.
  public typealias Element = FeatureCollection<WeatherAlert>
  /// A failure retrieving or validating a page.
  public typealias Failure = NWSError

  /// An independent traversal, finished after a terminal page or any error.
  public struct Iterator: AsyncIteratorProtocol {
    private var pages: CollectionPageSequence<WeatherAlert>.Iterator

    init(_ pages: CollectionPageSequence<WeatherAlert>) {
      self.pages = pages.makeAsyncIterator()
    }

    /// Fetches a page on demand, validating its continuation before returning it.
    /// - Throws: A pagination, redirect, problem-detail, transport, or cancellation error.
    public mutating func next() async throws(NWSError) -> Element? {
      try await pages.next()
    }
  }

  let pages: CollectionPageSequence<WeatherAlert>

  init(client: NWSClient, endpoint: Endpoint<Element>, followsLinks: Bool) {
    self.pages = CollectionPageSequence(
      client: client, endpoint: endpoint, followsLinks: followsLinks)
  }

  /// Creates an independent iterator without sending a request.
  public func makeAsyncIterator() -> Iterator { Iterator(pages) }
}

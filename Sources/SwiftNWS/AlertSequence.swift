import SwiftNWSModels

/// A lazy sequence of alert-history features, preserving GeoJSON metadata and service order.
/// Fetches another page only after the current page's features have been consumed.
/// Each iterator starts independently. Any error ends its traversal.
///
/// ```swift
/// let query = try AlertQuery(filter: .init(location: .areas([.texas])), limit: 100)
/// for try await alert in client.alerts(matching: query) {
///   print(alert.properties.headline ?? alert.properties.event)
///   break
/// }
/// ```
public struct AlertSequence: AsyncSequence, Sendable {
  /// One feature with its GeoJSON metadata.
  public typealias Element = Feature<WeatherAlert>
  /// A failure retrieving or validating a page.
  public typealias Failure = NWSError

  /// An independent traversal retaining only the current page's features.
  public struct Iterator: AsyncIteratorProtocol {
    private var features: CollectionFeatureSequence<WeatherAlert>.Iterator

    init(_ pages: AlertPageSequence) {
      self.features = CollectionFeatureSequence(pages: pages.pages).makeAsyncIterator()
    }

    /// Returns the next feature, checking cancellation even while a page is buffered.
    /// - Throws: The same errors as the page sequence. Any error finishes this iterator.
    public mutating func next() async throws(NWSError) -> Element? {
      try await features.next()
    }
  }

  private let pages: AlertPageSequence

  init(pages: AlertPageSequence) { self.pages = pages }

  /// Creates an independent iterator without sending a request.
  public func makeAsyncIterator() -> Iterator { Iterator(pages) }
}

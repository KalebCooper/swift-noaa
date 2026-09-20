import SwiftNWSModels

struct CollectionFeatureSequence<Properties: Decodable & Sendable>: AsyncSequence, Sendable {
  /// One feature with its GeoJSON metadata.
  typealias Element = Feature<Properties>
  /// A failure retrieving or validating a page.
  typealias Failure = NWSError

  /// An independent traversal that retains only the current page's features.
  struct Iterator: AsyncIteratorProtocol {
    private var features: [Element] = []
    private var finished = false
    private var index = 0
    private var pages: CollectionPageSequence<Properties>.Iterator

    init(_ pages: CollectionPageSequence<Properties>) {
      self.pages = pages.makeAsyncIterator()
    }

    /// Returns the next feature, checking cancellation even while a page is buffered.
    /// - Parameter actor: The caller's isolation, forwarded through page fetching. Read an iterator
    ///   serially; concurrent calls to the same iterator are unsupported.
    /// - Throws: The same errors as the page sequence. Any error finishes this iterator.
    mutating func next(
      isolation actor: isolated (any Actor)? = #isolation
    ) async throws(NWSError) -> Element? {
      guard !finished else { return nil }
      finished = true
      guard !Task.isCancelled else { throw .transport(.cancelled) }
      while index == features.count {
        guard let page = try await pages.next(isolation: actor) else { return nil }
        features = page.features
        index = 0
      }
      let feature = features[index]
      index += 1
      finished = false
      return feature
    }
  }

  private let pages: CollectionPageSequence<Properties>

  init(pages: CollectionPageSequence<Properties>) { self.pages = pages }

  /// Creates an independent iterator without sending a request.
  func makeAsyncIterator() -> Iterator { Iterator(pages) }
}

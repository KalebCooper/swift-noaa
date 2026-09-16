import SwiftNWSModels

/// A lazy sequence of station features, preserving GeoJSON metadata and service order.
/// Fetches another page only after the current page's features have been consumed.
///
/// ```swift
/// let query = try ObservationStationQuery(states: [.texas])
/// for try await station in client.observationStations(query: query) {
///   print(station.properties.stationIdentifier)
///   break
/// }
/// ```
public struct ObservationStationSequence: AsyncSequence, Sendable {
  /// One station with its GeoJSON metadata.
  public typealias Element = Feature<ObservationStation>
  /// A failure retrieving or validating a page.
  public typealias Failure = NWSError

  /// An independent traversal that retains only the current page's features.
  public struct Iterator: AsyncIteratorProtocol {
    private var features: [Element] = []
    private var finished = false
    private var index = 0
    private var pages: ObservationStationPageSequence.Iterator

    init(_ pages: ObservationStationPageSequence) {
      self.pages = pages.makeAsyncIterator()
    }

    /// Returns the next feature, checking cancellation even while a page is buffered.
    /// - Throws: The same errors as the page sequence. Any error finishes this iterator.
    public mutating func next() async throws(NWSError) -> Element? {
      guard !finished else { return nil }
      finished = true
      guard !Task.isCancelled else { throw .transport(.cancelled) }
      while index == features.count {
        guard let page = try await pages.next() else { return nil }
        features = page.features
        index = 0
      }
      let feature = features[index]
      index += 1
      finished = false
      return feature
    }
  }

  private let pages: ObservationStationPageSequence

  init(pages: ObservationStationPageSequence) { self.pages = pages }

  /// Creates an independent iterator without sending a request.
  public func makeAsyncIterator() -> Iterator { Iterator(pages) }
}

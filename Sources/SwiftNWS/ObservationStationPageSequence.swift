import HTTPCore
import SwiftNWSModels

/// A lazy sequence of station-directory pages in service order.
///
/// No request is sent until iteration. Each iterator starts independently, fetching only on
/// demand. An empty page can still have a continuation. Stop iterating when you have enough:
/// the service does not guarantee a finite number of pages.
/// Invalid continuation metadata throws before its page is returned. Any error ends the iterator.
///
/// ```swift
/// let query = try ObservationStationQuery(states: [.texas])
/// for try await page in client.observationStationPages(query: query) {
///   print(page.features.count)
///   break
/// }
/// ```
public struct ObservationStationPageSequence: AsyncSequence, Sendable {
  /// One complete GeoJSON page.
  public typealias Element = FeatureCollection<ObservationStation>
  /// A failure retrieving or validating a page.
  public typealias Failure = NWSError

  /// One independent traversal, finished after a terminal page or any error.
  public struct Iterator: AsyncIteratorProtocol {
    private var current: Endpoint<Element>
    private var finished = false
    private var pages: PageSequence<Element>.Iterator
    private let sequence: ObservationStationPageSequence
    private var visited: Set<String>

    init(_ sequence: ObservationStationPageSequence) {
      self.current = sequence.endpoint
      self.pages = sequence.client.stationPages(
        endpoint: sequence.endpoint, followsLinks: sequence.followsLinks
      ).makeAsyncIterator()
      self.sequence = sequence
      self.visited = [sequence.endpoint.path]
    }

    /// Fetches a page on demand, validating its continuation before returning it.
    /// - Throws: A pagination, redirect, problem-detail, transport, or cancellation error.
    public mutating func next() async throws(NWSError) -> Element? {
      guard !finished else { return nil }
      finished = true
      guard !Task.isCancelled else { throw .transport(.cancelled) }
      var redirects = Set<String>()
      for hop in 0...5 {
        guard redirects.insert(current.path).inserted else { throw .tooManyRedirects }
        let page: Element
        do {
          guard let response = try await pages.next() else { return nil }
          page = response.value
        } catch {
          guard let redirected = try sequence.client.redirectEndpoint(after: error, from: current)
          else {
            throw NWSError(error)
          }
          guard hop < 5 else { throw .tooManyRedirects }
          current = redirected
          visited.insert(current.path)
          pages = sequence.client.stationPages(
            endpoint: current, followsLinks: sequence.followsLinks
          ).makeAsyncIterator()
          continue
        }
        guard !Task.isCancelled else { throw .transport(.cancelled) }
        if sequence.followsLinks,
          let next = try ObservationStationPageSequence.continuation(page.pagination, from: current)
        {
          guard visited.insert(next.path).inserted else {
            throw .pagination(.repeatedNext(page.pagination?.next ?? next.path))
          }
          current = next
          finished = false
        }
        return page
      }
      throw .tooManyRedirects
    }
  }

  private let client: NWSClient
  private let endpoint: Endpoint<Element>
  private let followsLinks: Bool

  init(client: NWSClient, endpoint: Endpoint<Element>, followsLinks: Bool) {
    self.client = client
    self.endpoint = endpoint
    self.followsLinks = followsLinks
  }

  /// Creates an independent iterator without sending a request.
  public func makeAsyncIterator() -> Iterator { Iterator(self) }

  static func continuation(_ pagination: PaginationInfo?, from endpoint: Endpoint<Element>)
    throws(NWSError) -> Endpoint<Element>?
  {
    guard let pagination else { return nil }
    do {
      return try pagination.nextEndpoint(after: endpoint)
    } catch {
      throw .pagination(error)
    }
  }
}

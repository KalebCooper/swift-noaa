import HTTPCore
import SwiftNWSModels

struct CollectionPageSequence<Properties: Decodable & Sendable>: AsyncSequence, Sendable {
  /// One complete GeoJSON page.
  typealias Element = FeatureCollection<Properties>
  /// A failure retrieving or validating a page.
  typealias Failure = NWSError

  /// One independent traversal, finished after a terminal page or any error.
  struct Iterator: AsyncIteratorProtocol {
    private var current: Endpoint<Element>
    private var finished = false
    private var pages: PageSequence<Element>.Iterator
    private let sequence: CollectionPageSequence
    private var visited: Set<String>

    init(_ sequence: CollectionPageSequence) {
      self.current = sequence.endpoint
      self.pages = sequence.client.collectionPages(
        endpoint: sequence.endpoint, followsLinks: sequence.followsLinks
      ).makeAsyncIterator()
      self.sequence = sequence
      self.visited = [sequence.endpoint.path]
    }

    /// Fetches a page on demand, validating its continuation before returning it.
    /// - Throws: A pagination, redirect, problem-detail, transport, or cancellation error.
    mutating func next() async throws(NWSError) -> Element? {
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
          pages = sequence.client.collectionPages(
            endpoint: current, followsLinks: sequence.followsLinks
          ).makeAsyncIterator()
          continue
        }
        guard !Task.isCancelled else { throw .transport(.cancelled) }
        if sequence.followsLinks,
          let next = try CollectionPageSequence.continuation(page.pagination, from: current)
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
  func makeAsyncIterator() -> Iterator { Iterator(self) }

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

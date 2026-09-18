import HTTPCore
import SwiftNWSModels

struct CollectionPageSequence<Properties: Decodable & Sendable>: AsyncSequence, Sendable {
  /// One complete GeoJSON page.
  typealias Element = FeatureCollection<Properties>
  /// A failure retrieving or validating a page.
  typealias Failure = NWSError

  /// Where a traversal begins.
  enum Start: Sendable {
    /// Begin at a known endpoint.
    case endpoint(Endpoint<Element>)

    /// Resolve a coordinate's point on the first read, then begin at its validated
    /// observation-stations link.
    case nearbyObservationStations(WeatherCoordinate)
  }

  /// One independent traversal, finished after a terminal page or any error.
  struct Iterator: AsyncIteratorProtocol {
    private var current: Endpoint<Element>?
    private var finished = false
    private var pages: PageSequence<Element>.Iterator?
    private let sequence: CollectionPageSequence
    private var visited: Set<String> = []

    init(_ sequence: CollectionPageSequence) {
      self.sequence = sequence
      if case .endpoint(let endpoint) = sequence.start {
        begin(at: endpoint)
      }
    }

    /// Fetches a page on demand, validating its continuation before returning it.
    /// - Throws: A pagination, redirect, problem-detail, transport, or cancellation error, or
    ///   ``NWSError/invalidLink(_:)`` when a point's station link is disallowed.
    mutating func next() async throws(NWSError) -> Element? {
      guard !finished else { return nil }
      finished = true
      guard !Task.isCancelled else { throw .transport(.cancelled) }
      if current == nil, case .nearbyObservationStations(let location) = sequence.start {
        let stations = try await sequence.client.nearbyObservationStationsEndpoint(for: location)
        guard !Task.isCancelled else { throw .transport(.cancelled) }
        begin(
          at: Endpoint(
            accept: stations.accept, featureFlags: stations.featureFlags, path: stations.path))
      }
      guard var current, var pages else {
        preconditionFailure(
          "An iterator begins at an endpoint, or resolves one before its first read.")
      }
      defer {
        self.current = current
        self.pages = pages
      }
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

    private mutating func begin(at endpoint: Endpoint<Element>) {
      current = endpoint
      pages = sequence.client.collectionPages(
        endpoint: endpoint, followsLinks: sequence.followsLinks
      ).makeAsyncIterator()
      visited = [endpoint.path]
    }
  }

  private let client: NWSClient
  private let followsLinks: Bool
  private let start: Start

  init(client: NWSClient, endpoint: Endpoint<Element>, followsLinks: Bool) {
    self.init(client: client, followsLinks: followsLinks, start: .endpoint(endpoint))
  }

  init(client: NWSClient, followsLinks: Bool, start: Start) {
    self.client = client
    self.followsLinks = followsLinks
    self.start = start
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

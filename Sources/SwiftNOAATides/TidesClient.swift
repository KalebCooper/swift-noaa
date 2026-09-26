#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

import HTTPCore
import HTTPTypes
import SwiftNOAATidesModels

/// Executes CO-OPS requests without automatic station selection, pagination, or resource expansion.
///
/// Use `stations(matching:)` for discovery, `value(for:)` for reusable requests, or `send(_:)`
/// for direct wire responses. Retry budgets belong to each HTTP operation, including each redirect.
public struct TidesClient: Sendable {
  /// Identification attached to subsequent requests.
  public var configuration: TidesConfiguration

  private let client: HTTPClient

  /// Creates a client using any swifty-networking transport.
  /// - Parameters:
  ///   - clock: The clock for explicitly enabled retries.
  ///   - configuration: Optional caller identification.
  ///   - retryPolicy: A swifty-networking retry policy, disabled by default.
  ///   - transport: The transport used for every send.
  public init(
    clock: any Clock<Duration> = ContinuousClock(),
    configuration: TidesConfiguration = .init(),
    retryPolicy: RetryPolicy = .disabled,
    transport: any Transport
  ) {
    self.configuration = configuration
    self.client = HTTPClient(
      baseURL: Self.baseURL, clock: clock, redirectPolicy: .never,
      retryPolicy: retryPolicy, transport: transport)
  }

  /// Sends a JSON endpoint, following at most five validated same-origin redirects.
  /// - Parameter endpoint: A built-in or consumer-defined endpoint.
  /// - Returns: The wire response, without request context.
  /// - Throws: A `TidesError` distinguishing decoding, HTTP, provider, transport, and link failures.
  public func send<Value: Decodable & SendableMetatype>(
    _ endpoint: TidesEndpoint<Value>
  ) async throws(TidesError) -> Value {
    var endpoint = endpoint
    var visited = Set<String>()
    for _ in 0...5 {
      guard !Task.isCancelled else { throw .transport(.cancelled) }
      guard visited.insert(endpoint.path).inserted else { throw .tooManyRedirects }
      let response: Response
      do {
        response = try await client.execute(request(for: endpoint))
      } catch {
        if case .httpStatus(let body, let code, let headers) = error {
          if [301, 302, 303, 307, 308].contains(code), let location = headers[.location] {
            endpoint = try redirect(location, from: endpoint)
            continue
          }
          if let refusal = try? JSONDecoder().decode(ProviderErrorEnvelope.self, from: body),
            let provider = refusal.providerError
          {
            throw .provider(provider)
          }
          throw .httpStatus(body: body, code: code)
        }
        throw .transport(error)
      }
      guard !Task.isCancelled else { throw .transport(.cancelled) }
      do {
        // A present but malformed refusal must not decode as a custom successful response.
        let envelope = try JSONDecoder().decode(ProviderErrorEnvelope.self, from: response.body)
        if let refusal = envelope.providerError { throw TidesError.provider(refusal) }
        return try JSONDecoder().decode(Value.self, from: response.body)
      } catch let error as TidesError {
        throw error
      } catch {
        throw .decoding(error)
      }
    }
    throw .tooManyRedirects
  }

  /// Retrieves exactly one matching station, retaining its detail spelling and resource links.
  /// - Parameter identifier: A validated station identifier.
  /// - Returns: The single station.
  /// - Throws: `TidesError.invalidStationResponse` or an execution failure.
  public func station(identifier: CoastalStationIdentifier) async throws(TidesError)
    -> CoastalStation
  {
    try await value(for: .station(identifier: identifier))
  }

  /// Retrieves one directory envelope in provider order.
  /// - Parameter query: The validated station category.
  /// - Returns: The complete response, without resource expansion.
  /// - Throws: Any `TidesError` from execution.
  public func stations(matching query: CoastalStationQuery) async throws(TidesError)
    -> CoastalStations
  {
    try await value(for: .stations(matching: query))
  }

  /// Executes a portable request using the same send path as direct endpoints.
  /// - Parameter request: The inspectable description.
  /// - Returns: The concrete response selected by its factory.
  /// - Throws: Any `TidesError` from execution or station cardinality validation.
  public func value<Value: Decodable & SendableMetatype>(
    for request: TidesRequest<Value>
  ) async throws(TidesError) -> Value {
    guard !Task.isCancelled else { throw .transport(.cancelled) }
    switch request.resolution {
    case .endpoint(let endpoint):
      return try await send(endpoint)
    case .station(let identifier):
      let envelope = try await send(
        TidesEndpoint.station(identifier: identifier).decoding(StationEnvelope<Value>.self))
      guard envelope.count == 1, envelope.stations.count == 1,
        let station = envelope.stations.first, station.identifier == identifier.rawValue
      else {
        throw .invalidStationResponse(
          expected: identifier.rawValue,
          identifiers: envelope.stations.map(\.identifier), reportedCount: envelope.count)
      }
      return station.value
    }
  }

  private func redirect<Value>(
    _ location: String, from endpoint: TidesEndpoint<Value>
  ) throws(TidesError) -> TidesEndpoint<Value> {
    guard let current = URL(string: Self.baseURL.absoluteString + endpoint.path),
      let raw = URL(string: location, encodingInvalidCharacters: false),
      let parts = URLComponents(url: raw, resolvingAgainstBaseURL: false)
    else { throw .invalidLink(location) }
    let path = parts.percentEncodedPath
    let relative = path.hasPrefix("/") ? path : "/" + path
    guard
      TidesEndpoint<Value>(path: relative + (parts.percentEncodedQuery.map { "?" + $0 } ?? ""))
        != nil,
      parts.scheme != nil || parts.host == nil,
      let link = URL(string: location, relativeTo: current)?.absoluteURL,
      let next = TidesEndpoint<Value>(link: link)
    else { throw .invalidLink(location) }
    return next
  }

  private func request<Value>(for endpoint: TidesEndpoint<Value>) -> Request {
    var path = endpoint.path
    if let application = configuration.application,
      var components = URLComponents(string: path),
      components.path == "/api/prod/datagetter"
    {
      var items = components.queryItems ?? []
      if !items.contains(where: { $0.name == "application" }) {
        items.append(URLQueryItem(name: "application", value: application))
        components.queryItems = items
        path = components.string ?? path
      }
    }
    var headers = HTTPFields()
    headers[.accept] = "application/json"
    headers[.userAgent] = configuration.userAgent
    return Request(headers: headers, options: RequestOptions(redirectPolicy: .never), path: path)
  }

  private static let baseURL: URL = {
    guard let url = URL(string: "https://api.tidesandcurrents.noaa.gov") else {
      preconditionFailure("The fixed CO-OPS HTTPS origin is valid.")
    }
    return url
  }()
}

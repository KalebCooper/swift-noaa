#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import HTTPCore
import HTTPTypes
import SwiftNWSModels

/// A client for the National Weather Service API.
///
/// Use ``latestObservation(from:)`` for current conditions, ``value(for:)`` for a reusable
/// request, and ``send(_:)`` for a single endpoint. All three use the same transport and errors.
/// On Apple platforms, create a client with ``init(userAgent:)``; elsewhere, pass a transport.
public struct NWSClient: Sendable {
  /// The values every request is sent with.
  public var configuration: NWSConfiguration

  /// The shared point cache, or nil when point caching is disabled.
  public let pointCache: PointCache?

  private let client: HTTPClient

  /// Creates a client that sends through a swifty-networking transport.
  ///
  /// - Parameters:
  ///   - configuration: The values every request is sent with.
  ///   - pointCache: Shared point mappings, or nil to disable caching.
  ///   - transport: What sends each request.
  public init(
    configuration: NWSConfiguration, pointCache: PointCache? = .init(), transport: any Transport
  ) {
    self.configuration = configuration
    self.pointCache = pointCache
    self.client = HTTPClient(baseURL: Self.baseURL, redirectPolicy: .never, transport: transport)
  }

  /// Retrieves active alerts at a coordinate.
  /// - Parameter location: The coordinate to filter.
  /// - Returns: The returned GeoJSON collection in service order; no automatic pagination.
  /// - Throws: Any ``NWSError`` from ``value(for:)``.
  public func activeAlerts(for location: WeatherCoordinate) async throws(NWSError)
    -> FeatureCollection<WeatherAlert>
  {
    try await value(for: .activeAlerts(for: location))
  }

  /// Retrieves active alerts for a provider area.
  /// - Parameter area: A nonempty state, territory, or marine area code.
  /// - Returns: The returned GeoJSON collection in service order; no automatic pagination.
  /// - Throws: Any ``NWSError`` from ``value(for:)``.
  public func activeAlerts(inArea area: String) async throws(NWSError) -> FeatureCollection<
    WeatherAlert
  > {
    try await value(for: .activeAlerts(inArea: area))
  }

  /// Retrieves active alerts for a provider zone.
  /// - Parameter zone: A nonempty forecast or county zone identifier.
  /// - Returns: The returned GeoJSON collection in service order; no automatic pagination.
  /// - Throws: Any ``NWSError`` from ``value(for:)``.
  public func activeAlerts(inZone zone: String) async throws(NWSError) -> FeatureCollection<
    WeatherAlert
  > {
    try await value(for: .activeAlerts(inZone: zone))
  }

  /// Retrieves active alerts using supported filters.
  /// - Parameter filter: The geographic and CAP restrictions.
  /// - Returns: The returned GeoJSON collection in service order; no automatic pagination.
  /// - Throws: Any ``NWSError`` from ``value(for:)``.
  public func activeAlerts(matching filter: ActiveAlertFilter = .init()) async throws(NWSError)
    -> FeatureCollection<WeatherAlert>
  {
    try await value(for: .activeAlerts(matching: filter))
  }

  /// Retrieves one alert by its provider identifier.
  /// - Parameter identifier: The alert identifier.
  /// - Returns: The alert properties.
  /// - Throws: Any ``NWSError`` from ``value(for:)``.
  public func alert(identifier: String) async throws(NWSError) -> WeatherAlert {
    try await value(for: .alert(identifier: identifier))
  }

  /// Retrieves the twelve-hour forecast for a coordinate.
  /// - Parameters:
  ///   - location: The coordinate to look up.
  ///   - options: Units and representation flags.
  /// - Returns: The forecast and its periods in service order.
  /// - Throws: ``NWSError/invalidLink(_:)`` or any error from ``send(_:)``.
  public func forecast(for location: WeatherCoordinate, options: ForecastOptions = .init())
    async throws(NWSError) -> WeatherForecast
  {
    try await value(for: .forecast(for: location, options: options))
  }

  /// Retrieves the hourly forecast for a coordinate.
  /// - Parameters:
  ///   - location: The coordinate to look up.
  ///   - options: Units and representation flags.
  /// - Returns: The hourly forecast in service order, without trimming periods.
  /// - Throws: ``NWSError/invalidLink(_:)`` or any error from ``send(_:)``.
  public func hourlyForecast(for location: WeatherCoordinate, options: ForecastOptions = .init())
    async throws(NWSError) -> WeatherForecast
  {
    try await value(for: .hourlyForecast(for: location, options: options))
  }

  /// Retrieves the latest observation from a station or a coordinate's station list.
  ///
  /// A station lookup sends one request. An uncached coordinate lookup sends three: the point, its linked
  /// station list, and the first station's observation. The API does not guarantee distance order.
  /// The result retains its station and timestamp, with no freshness filtering or fallback.
  ///
  /// - Parameter source: The station or coordinate to look up.
  /// - Returns: The station's observation, including any missing measurements.
  /// - Throws: The same ``NWSError`` as the equivalent ``value(for:)`` request.
  public func latestObservation(
    from source: ObservationSource
  ) async throws(NWSError) -> WeatherObservation {
    try await value(for: .latestObservation(from: source))
  }

  /// Sends an endpoint and decodes its response.
  ///
  /// - Parameter endpoint: The endpoint to send.
  /// - Returns: The decoded body, including its GeoJSON wrapper when the endpoint names one.
  /// - Throws: ``NWSError/problem(_:)`` for NWS problem details, or ``NWSError/transport(_:)``
  ///   for transport and decoding failures. Cancellation is a transport cancellation.
  public func send<Value: Decodable & SendableMetatype>(
    _ endpoint: Endpoint<Value>
  ) async throws(NWSError) -> Value {
    var endpoint = endpoint
    var visited = Set<String>()
    for _ in 0...5 {
      guard !Task.isCancelled else { throw .transport(.cancelled) }
      guard visited.insert(endpoint.path).inserted else { throw .tooManyRedirects }
      var headers = HTTPFields()
      headers[.accept] = endpoint.accept.rawValue
      headers[.userAgent] = configuration.userAgent
      if !endpoint.featureFlags.isEmpty, let name = HTTPField.Name("Feature-Flags") {
        headers[name] = endpoint.featureFlags.joined(separator: ",")
      }
      do {
        return try await client.execute(Request(headers: headers, path: endpoint.path))
      } catch {
        guard case .httpStatus(_, let code, let fields) = error,
          [301, 302, 303, 307, 308].contains(code),
          let location = fields[.location]
        else { throw NWSError(error) }
        guard let current = URL(string: Self.baseURL.absoluteString + endpoint.path),
          let link = URL(string: location, relativeTo: current)?.absoluteURL
        else { throw .invalidRedirect(location) }
        guard
          let next = Endpoint<Value>(
            accept: endpoint.accept, featureFlags: endpoint.featureFlags, link: link)
        else { throw .invalidLink(link) }
        endpoint = next
      }
    }
    throw .tooManyRedirects
  }

  /// Executes a reusable weather request.
  ///
  /// Endpoint requests decode directly as `Value`. Latest-observation requests resolve their
  /// source and return the observation's properties. Coordinate resolutions reuse the point cache. Direct endpoints bypass it. No automatic pagination is applied.
  ///
  /// - Parameter request: The portable description to execute.
  /// - Returns: The concrete response selected by the request's factory or endpoint.
  /// - Throws: ``NWSError/invalidStationIdentifier(_:)`` for an empty identifier,
  ///   ``NWSError/invalidLink(_:)`` for a disallowed link, ``NWSError/noObservationStation``
  ///   for an empty station list, or any error from ``send(_:)``.
  public func value<Value: Decodable & SendableMetatype>(
    for request: WeatherRequest<Value>
  ) async throws(NWSError) -> Value {
    guard !Task.isCancelled else { throw .transport(.cancelled) }
    switch request.resolution {
    case .alert(let identifier):
      guard !identifier.isEmpty else { throw .invalidAlertIdentifier(identifier) }
      let endpoint = Endpoint.alert(identifier: identifier)
      return try await send(Endpoint<Feature<Value>>(path: endpoint.path)).properties
    case .endpoint(let endpoint):
      return try await send(endpoint)
    case .forecast(let location, let options), .hourlyForecast(let location, let options):
      let point = try await point(for: location)
      let endpoint: Endpoint<Feature<WeatherForecast>>?
      let link: URL
      if case .hourlyForecast = request.resolution {
        endpoint = .hourlyForecast(for: point, options: options)
        link = point.forecastHourly
      } else {
        endpoint = .forecast(for: point, options: options)
        link = point.forecast
      }
      guard let endpoint else { throw .invalidLink(link) }
      return try await send(
        Endpoint<Feature<Value>>(
          accept: endpoint.accept, featureFlags: endpoint.featureFlags, path: endpoint.path)
      ).properties
    case .latestObservation(let source):
      let identifier: String
      switch source {
      case .nearest(let location):
        let point = try await point(for: location)
        guard let stationsEndpoint = Endpoint.observationStations(near: point) else {
          throw .invalidLink(point.observationStations)
        }
        guard let station = try await send(stationsEndpoint).features.first?.properties else {
          throw .noObservationStation
        }
        identifier = station.stationIdentifier
      case .station(let stationIdentifier):
        identifier = stationIdentifier
      }
      guard !identifier.isEmpty else { throw .invalidStationIdentifier(identifier) }
      let endpoint = Endpoint.latestObservation(stationIdentifier: identifier)
      // Only WeatherRequest<WeatherObservation> can be created with this resolution.
      // Decode the same response type through its GeoJSON envelope without erasing or casting it.
      let feature = try await send(
        Endpoint<Feature<Value>>(accept: endpoint.accept, path: endpoint.path))
      return feature.properties
    }
  }

  private func point(for location: WeatherCoordinate) async throws(NWSError) -> Point {
    guard !Task.isCancelled else { throw .transport(.cancelled) }
    let cached = pointCache?.lookup(location)
    if let point = cached?.point { return point }
    let point = try await send(Endpoint.point(for: location)).properties
    guard !Task.isCancelled else { throw .transport(.cancelled) }
    if let generation = cached?.generation {
      pointCache?.insert(point, for: location, generation: generation)
    }
    return point
  }

  private static let baseURL: URL = {
    guard let url = URL(string: "https://api.weather.gov") else {
      preconditionFailure("https://api.weather.gov is a valid URL.")
    }
    return url
  }()
}

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
/// The client sends ``/SwiftNWSModels/Endpoint`` values to `https://api.weather.gov` with the
/// `User-Agent` from its configuration and the media type each endpoint asks for, and decodes the
/// response. On Apple platforms, create one over a `URLSession`; anywhere else, pass a swifty-networking
/// transport.
///
/// ```swift
/// let client = NWSClient(
///   configuration: NWSConfiguration(userAgent: "(myweatherapp.com, contact@myweatherapp.com)")
/// )
/// let observation = try await client.latestObservation(latitude: 30.2672, longitude: -97.7431)
/// ```
public struct NWSClient: Sendable {
  /// The values every request is sent with.
  public var configuration: NWSConfiguration

  private let client: HTTPClient

  /// Creates a client that sends through a swifty-networking transport.
  ///
  /// - Parameters:
  ///   - configuration: The values every request is sent with.
  ///   - transport: What sends each request.
  public init(configuration: NWSConfiguration, transport: any Transport) {
    self.configuration = configuration
    self.client = HTTPClient(baseURL: Self.baseURL, transport: transport)
  }

  /// Sends an endpoint and decodes its response.
  ///
  /// ```swift
  /// let point = try await client.send(Endpoint.point(latitude: 30.2672, longitude: -97.7431))
  /// ```
  ///
  /// - Parameter endpoint: The endpoint to send.
  /// - Returns: The decoded response.
  /// - Throws: ``NWSError/problem(_:)`` when the API answers with problem details, and
  ///   ``NWSError/transport(_:)`` for any other failure.
  public func send<Value: Decodable & SendableMetatype>(
    _ endpoint: Endpoint<Value>
  ) async throws(NWSError) -> Value {
    var headers = HTTPFields()
    headers[.accept] = endpoint.accept.rawValue
    headers[.userAgent] = configuration.userAgent
    do {
      return try await client.execute(Request(headers: headers, path: endpoint.path))
    } catch {
      throw NWSError(error)
    }
  }

  /// The latest observation from the station nearest a location.
  ///
  /// The lookup takes three requests: the point for the location, the stations near it, and the
  /// latest observation from the first station listed, which is the nearest.
  ///
  /// ```swift
  /// let observation = try await client.latestObservation(latitude: 30.2672, longitude: -97.7431)
  /// print(observation.stationName ?? observation.stationId, observation.textDescription ?? "")
  /// ```
  ///
  /// - Parameters:
  ///   - latitude: The latitude in decimal degrees.
  ///   - longitude: The longitude in decimal degrees.
  /// - Returns: The observation.
  /// - Throws: ``NWSError/noObservationStation`` when the point lists no station,
  ///   ``NWSError/invalidLink(_:)`` when it links outside the API, and whatever ``send(_:)`` throws.
  public func latestObservation(
    latitude: Double,
    longitude: Double
  ) async throws(NWSError) -> WeatherObservation {
    let point = try await send(Endpoint.point(latitude: latitude, longitude: longitude)).properties
    guard let stationsEndpoint = Endpoint.observationStations(near: point) else {
      throw .invalidLink(point.observationStations)
    }
    guard let station = try await send(stationsEndpoint).features.first?.properties else {
      throw .noObservationStation
    }
    let latest = Endpoint.latestObservation(stationIdentifier: station.stationIdentifier)
    return try await send(latest).properties
  }

  private static let baseURL: URL = {
    guard let url = URL(string: "https://api.weather.gov") else {
      preconditionFailure("https://api.weather.gov is a valid URL.")
    }
    return url
  }()
}

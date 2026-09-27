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

  /// Retrieves a station's bin table in explicitly requested units.
  /// - Parameters:
  ///   - stationIdentifier: The validated station identifier.
  ///   - units: The requested provider unit-system code.
  /// - Returns: The bin table and reported metadata, without depth inference.
  /// - Throws: `TidesError.invalidQuery` for invalid units, or any shared execution failure.
  public func currentBins(stationIdentifier: CoastalStationIdentifier, units: TidesUnits)
    async throws(TidesError) -> CurrentBins
  {
    let request: TidesRequest<CurrentBins>
    do { request = try .currentBins(stationIdentifier: stationIdentifier, units: units) } catch {
      throw .invalidQuery(error)
    }
    return try await value(for: request)
  }

  /// Retrieves predicted current events with requested context and reported units.
  /// - Parameter query: The validated prediction query.
  /// - Returns: Provider predictions without conversion, synthesis, or station substitution.
  /// - Throws: Any `TidesError` from the shared send path.
  public func currentEvents(matching query: CurrentEventQuery) async throws(TidesError)
    -> CurrentEvents
  {
    try await value(for: .currentEvents(matching: query))
  }

  /// Retrieves measured currents at one selected or provider-default bin.
  /// - Parameter query: The validated bin, GMT range and requested velocity units.
  /// - Returns: Provider observations with separate requested context, without a metadata preflight.
  /// - Throws: Any `TidesError` from the shared send path.
  public func currentObservations(matching query: CurrentObservationQuery) async throws(TidesError)
    -> CurrentObservations
  {
    try await value(for: .currentObservations(matching: query))
  }

  /// Retrieves predicted current samples with requested context and reported units.
  /// - Parameter query: The validated prediction query.
  /// - Returns: Provider predictions without conversion, synthesis, or station substitution.
  /// - Throws: Any `TidesError` from the shared send path.
  public func currentPredictions(matching query: CurrentPredictionQuery) async throws(TidesError)
    -> CurrentPredictions
  {
    try await value(for: .currentPredictions(matching: query))
  }

  /// Retrieves a station's datum table in explicitly requested units.
  /// - Parameters:
  ///   - stationIdentifier: The validated station identifier.
  ///   - units: The requested provider unit-system code.
  /// - Returns: The datum table and reported metadata, without height conversion.
  /// - Throws: `TidesError.invalidQuery` for invalid units, or any shared execution failure.
  public func datums(stationIdentifier: CoastalStationIdentifier, units: TidesUnits)
    async throws(TidesError) -> CoastalDatums
  {
    let request: TidesRequest<CoastalDatums>
    do { request = try .datums(stationIdentifier: stationIdentifier, units: units) } catch {
      throw .invalidQuery(error)
    }
    return try await value(for: request)
  }

  /// Retrieves the station's raw flood thresholds through the shared request executor.
  /// - Parameter stationIdentifier: The validated station identifier.
  /// - Parameter units: Explicit metric or English threshold units.
  /// - Returns: Unchanged provider metadata, without availability inference.
  /// - Throws: Any `TidesError` from execution, or invalid units.
  public func floodLevels(stationIdentifier: CoastalStationIdentifier, units: TidesUnits)
    async throws(TidesError) -> CoastalFloodLevels
  {
    let request: TidesRequest<CoastalFloodLevels>
    do { request = try .floodLevels(stationIdentifier: stationIdentifier, units: units) } catch {
      throw .invalidQuery(error)
    }
    return try await value(for: request)
  }

  /// Retrieves predicted high/low events with their requested station, datum, units, and GMT range.
  /// - Parameter query: A validated high/low prediction query.
  /// - Returns: Events in provider order with requested context.
  /// - Throws: Any `TidesError` from endpoint execution; provider refusals remain observable.
  public func highLowTides(matching query: HighLowTideQuery) async throws(TidesError)
    -> HighLowTides
  {
    try await value(for: .highLowTides(matching: query))
  }

  /// Retrieves verified hourly heights for explicit inclusive GMT bounds.
  /// - Parameter query: A validated hourly-height query.
  /// - Returns: Hourly observations and raw flags without filling gaps.
  /// - Throws: Any `TidesError` from the shared execution path.
  public func hourlyWaterLevels(matching query: HourlyWaterLevelQuery) async throws(TidesError)
    -> HourlyWaterLevels
  {
    try await value(for: .hourlyWaterLevels(matching: query))
  }

  /// Retrieves the station's notices through the shared request executor.
  /// - Parameter stationIdentifier: The validated station identifier.
  /// - Returns: Unchanged provider metadata, without availability inference.
  /// - Throws: Any `TidesError` from execution.
  public func notices(stationIdentifier: CoastalStationIdentifier) async throws(TidesError)
    -> CoastalNotices
  {
    try await value(for: .notices(stationIdentifier: stationIdentifier))
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

  /// Retrieves the station's sensors through the shared request executor.
  /// - Parameter stationIdentifier: The validated station identifier.
  /// - Parameter units: Requested elevation units.
  /// - Returns: Unchanged provider metadata, without availability inference.
  /// - Throws: Any `TidesError` from execution, or invalid units.
  public func sensors(stationIdentifier: CoastalStationIdentifier, units: TidesUnits)
    async throws(TidesError) -> CoastalSensors
  {
    let request: TidesRequest<CoastalSensors>
    do { request = try .sensors(stationIdentifier: stationIdentifier, units: units) } catch {
      throw .invalidQuery(error)
    }
    return try await value(for: request)
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

  /// Retrieves reported tide samples with their requested context.
  /// - Parameter query: A validated explicit GMT sample query.
  /// - Returns: Samples in provider order, with no interpolation or inferred events.
  /// - Throws: Any `TidesError` from the shared execution path.
  public func tidePredictions(matching query: TidePredictionQuery) async throws(TidesError)
    -> TidePredictions
  {
    try await value(for: .tidePredictions(matching: query))
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
    case .airPressureObservations, .airTemperatureObservations, .conductivityObservations,
      .currentEvents, .currentObservations, .currentPredictions, .highLowTides, .hourlyWaterLevels,
      .humidityObservations, .latestWaterLevel, .observedHighLowWaterLevels, .oneMinuteWaterLevels,
      .salinityObservations, .tidePredictions, .visibilityObservations, .waterLevels,
      .waterTemperatureObservations, .windObservations:
      preconditionFailure(
        "Contextual factories return non-Decodable results and use their specialized executor."
      )
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

  /// Executes predicted current events and attaches the original requested context.
  /// - Parameter request: A request from the constrained prediction factory.
  /// - Returns: Provider records and reported units alongside the query.
  /// - Throws: Any `TidesError` from the shared send path.
  public func value(for request: TidesRequest<CurrentEvents>) async throws(TidesError)
    -> CurrentEvents
  {
    guard case .currentEvents(let query) = request.resolution else {
      preconditionFailure("Only the currentEvents factory constructs CurrentEvents requests.")
    }
    let response = try await send(.currentEvents(matching: query))
    return CurrentEvents(events: response.events, requestedQuery: query, units: response.units)
  }

  /// Executes measured currents and attaches their original requested context.
  /// - Parameter request: A request from the constrained current-observation factory.
  /// - Returns: Observations and provider metadata without inventing depth or units.
  /// - Throws: Any `TidesError` from the shared send path.
  public func value(for request: TidesRequest<CurrentObservations>) async throws(TidesError)
    -> CurrentObservations
  {
    guard case .currentObservations(let query) = request.resolution else {
      preconditionFailure(
        "Only the current-observation factory constructs CurrentObservations requests.")
    }
    let response = try await send(.currentObservations(matching: query))
    return CurrentObservations(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }

  /// Executes sampled current predictions and attaches the original requested context.
  /// - Parameter request: A request from the constrained prediction factory.
  /// - Returns: Provider records and reported units alongside the query.
  /// - Throws: Any `TidesError` from the shared send path.
  public func value(for request: TidesRequest<CurrentPredictions>) async throws(TidesError)
    -> CurrentPredictions
  {
    guard case .currentPredictions(let query) = request.resolution else {
      preconditionFailure(
        "Only the currentPredictions factory constructs CurrentPredictions requests.")
    }
    let response = try await send(.currentPredictions(matching: query))
    return CurrentPredictions(
      predictions: response.predictions, requestedQuery: query, units: response.units)
  }

  /// Executes high/low predictions and attaches the original validated request context.
  /// - Parameter request: A high/low request created by its constrained factory.
  /// - Returns: Decoded events and requested context, without conversion or station substitution.
  /// - Throws: Any `TidesError` from the shared send path, including cancellation.
  public func value(for request: TidesRequest<HighLowTides>) async throws(TidesError)
    -> HighLowTides
  {
    guard case .highLowTides(let query) = request.resolution else {
      preconditionFailure("Only the high/low factory can construct a request for HighLowTides.")
    }
    let response = try await send(.highLowTides(matching: query))
    return HighLowTides(predictions: response.predictions, requestedQuery: query)
  }

  /// Executes verified hourly heights and attaches the original requested context.
  /// - Parameter request: An hourly-height request created by its constrained factory.
  /// - Returns: Observations and provider metadata with separate requested context.
  /// - Throws: Any `TidesError` from the shared send path, including cancellation.
  public func value(for request: TidesRequest<HourlyWaterLevels>) async throws(TidesError)
    -> HourlyWaterLevels
  {
    guard case .hourlyWaterLevels(let query) = request.resolution else {
      preconditionFailure(
        "Only the hourly-height factory can construct a request for HourlyWaterLevels.")
    }
    let response = try await send(.hourlyWaterLevels(matching: query))
    return HourlyWaterLevels(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }

  /// Executes sampled tide predictions and attaches the original validated request context.
  /// - Parameter request: A sampled tide request created by its constrained factory.
  /// - Returns: Decoded samples and requested context, without conversion or station substitution.
  /// - Throws: Any `TidesError` from the shared send path, including cancellation.
  public func value(for request: TidesRequest<TidePredictions>) async throws(TidesError)
    -> TidePredictions
  {
    guard case .tidePredictions(let query) = request.resolution else {
      preconditionFailure(
        "Only the sampled tide factory can construct a request for TidePredictions.")
    }
    let response = try await send(.tidePredictions(matching: query))
    return TidePredictions(predictions: response.predictions, requestedQuery: query)
  }

  /// Executes measured water levels and attaches the original requested context.
  /// - Parameter request: A water-level request created by its constrained factory.
  /// - Returns: Observations and provider metadata with separate requested context.
  /// - Throws: Any `TidesError` from the shared send path, including cancellation.
  public func value(for request: TidesRequest<WaterLevels>) async throws(TidesError) -> WaterLevels
  {
    guard case .waterLevels(let query) = request.resolution else {
      preconditionFailure("Only the water-level factory can construct a request for WaterLevels.")
    }
    let response = try await send(.waterLevels(matching: query))
    return WaterLevels(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }

  /// Retrieves measured six-minute water levels for explicit inclusive GMT bounds.
  /// - Parameter query: A validated water-level observation query.
  /// - Returns: Measurements and quality fields without filling gaps or inferring verification.
  /// - Throws: Any `TidesError` from the shared execution path.
  public func waterLevels(matching query: WaterLevelQuery) async throws(TidesError) -> WaterLevels {
    try await value(for: .waterLevels(matching: query))
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

extension TidesClient {
  /// Executes a reusable water temperature query through the shared send path.
  /// - Parameter request: The concrete request selected by its factory.
  /// - Returns: Provider metadata and measurements with separate query context.
  /// - Throws: Any `TidesError` from execution.
  public func value(for request: TidesRequest<WaterTemperatureObservations>)
    async throws(TidesError) -> WaterTemperatureObservations
  {
    guard case .waterTemperatureObservations(let query) = request.resolution else {
      preconditionFailure("Only the waterTemperatureObservations factory constructs this request.")
    }
    let response = try await send(.waterTemperatureObservations(matching: query))
    return WaterTemperatureObservations(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }

  /// Retrieves reported water temperature and the original requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: Observations without conversion, gap filling, or station substitution.
  /// - Throws: Any `TidesError` from the shared execution path.
  public func waterTemperatureObservations(matching query: CoastalObservationQuery)
    async throws(TidesError) -> WaterTemperatureObservations
  {
    try await value(for: .waterTemperatureObservations(matching: query))
  }

}

extension TidesClient {
  /// Retrieves reported air pressure and the original requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: Observations without conversion, gap filling, or station substitution.
  /// - Throws: Any `TidesError` from the shared execution path.
  public func airPressureObservations(matching query: CoastalObservationQuery)
    async throws(TidesError) -> AirPressureObservations
  {
    try await value(for: .airPressureObservations(matching: query))
  }

  /// Executes a reusable air pressure query through the shared send path.
  /// - Parameter request: The concrete request selected by its factory.
  /// - Returns: Provider metadata and measurements with separate query context.
  /// - Throws: Any `TidesError` from execution.
  public func value(for request: TidesRequest<AirPressureObservations>) async throws(TidesError)
    -> AirPressureObservations
  {
    guard case .airPressureObservations(let query) = request.resolution else {
      preconditionFailure("Only the airPressureObservations factory constructs this request.")
    }
    let response = try await send(.airPressureObservations(matching: query))
    return AirPressureObservations(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }
}

extension TidesClient {
  /// Retrieves reported air temperature and the original requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: Observations without conversion, gap filling, or station substitution.
  /// - Throws: Any `TidesError` from the shared execution path.
  public func airTemperatureObservations(matching query: CoastalObservationQuery)
    async throws(TidesError) -> AirTemperatureObservations
  {
    try await value(for: .airTemperatureObservations(matching: query))
  }

  /// Executes a reusable air temperature query through the shared send path.
  /// - Parameter request: The concrete request selected by its factory.
  /// - Returns: Provider metadata and measurements with separate query context.
  /// - Throws: Any `TidesError` from execution.
  public func value(for request: TidesRequest<AirTemperatureObservations>) async throws(TidesError)
    -> AirTemperatureObservations
  {
    guard case .airTemperatureObservations(let query) = request.resolution else {
      preconditionFailure("Only the airTemperatureObservations factory constructs this request.")
    }
    let response = try await send(.airTemperatureObservations(matching: query))
    return AirTemperatureObservations(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }
}

extension TidesClient {
  /// Executes a reusable wind query through the shared send path.
  /// - Parameter request: The concrete request selected by its factory.
  /// - Returns: Provider metadata and measurements with separate query context.
  /// - Throws: Any `TidesError` from execution.
  public func value(for request: TidesRequest<WindObservations>) async throws(TidesError)
    -> WindObservations
  {
    guard case .windObservations(let query) = request.resolution else {
      preconditionFailure("Only the windObservations factory constructs this request.")
    }
    let response = try await send(.windObservations(matching: query))
    return WindObservations(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }

  /// Retrieves reported wind and the original requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: Observations without conversion, gap filling, or station substitution.
  /// - Throws: Any `TidesError` from the shared execution path.
  public func windObservations(matching query: CoastalObservationQuery) async throws(TidesError)
    -> WindObservations
  {
    try await value(for: .windObservations(matching: query))
  }

}

extension TidesClient {
  /// Retrieves reported conductivity and the original requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: Observations without conversion, gap filling, or station substitution.
  /// - Throws: Any `TidesError` from the shared execution path.
  public func conductivityObservations(matching query: CoastalObservationQuery)
    async throws(TidesError) -> ConductivityObservations
  {
    try await value(for: .conductivityObservations(matching: query))
  }

  /// Executes a reusable conductivity query through the shared send path.
  /// - Parameter request: The concrete request selected by its factory.
  /// - Returns: Provider metadata and measurements with separate query context.
  /// - Throws: Any `TidesError` from execution.
  public func value(for request: TidesRequest<ConductivityObservations>) async throws(TidesError)
    -> ConductivityObservations
  {
    guard case .conductivityObservations(let query) = request.resolution else {
      preconditionFailure("Only the conductivityObservations factory constructs this request.")
    }
    let response = try await send(.conductivityObservations(matching: query))
    return ConductivityObservations(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }
}

extension TidesClient {
  /// Retrieves reported humidity and the original requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: Observations without conversion, gap filling, or station substitution.
  /// - Throws: Any `TidesError` from the shared execution path.
  public func humidityObservations(matching query: CoastalObservationQuery) async throws(TidesError)
    -> HumidityObservations
  {
    try await value(for: .humidityObservations(matching: query))
  }

  /// Executes a reusable humidity query through the shared send path.
  /// - Parameter request: The concrete request selected by its factory.
  /// - Returns: Provider metadata and measurements with separate query context.
  /// - Throws: Any `TidesError` from execution.
  public func value(for request: TidesRequest<HumidityObservations>) async throws(TidesError)
    -> HumidityObservations
  {
    guard case .humidityObservations(let query) = request.resolution else {
      preconditionFailure("Only the humidityObservations factory constructs this request.")
    }
    let response = try await send(.humidityObservations(matching: query))
    return HumidityObservations(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }
}

extension TidesClient {
  /// Retrieves reported salinity and the original requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: Observations without conversion, gap filling, or station substitution.
  /// - Throws: Any `TidesError` from the shared execution path.
  public func salinityObservations(matching query: CoastalObservationQuery) async throws(TidesError)
    -> SalinityObservations
  {
    try await value(for: .salinityObservations(matching: query))
  }

  /// Executes a reusable salinity query through the shared send path.
  /// - Parameter request: The concrete request selected by its factory.
  /// - Returns: Provider metadata and measurements with separate query context.
  /// - Throws: Any `TidesError` from execution.
  public func value(for request: TidesRequest<SalinityObservations>) async throws(TidesError)
    -> SalinityObservations
  {
    guard case .salinityObservations(let query) = request.resolution else {
      preconditionFailure("Only the salinityObservations factory constructs this request.")
    }
    let response = try await send(.salinityObservations(matching: query))
    return SalinityObservations(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }
}

extension TidesClient {
  /// Executes a reusable visibility query through the shared send path.
  /// - Parameter request: The concrete request selected by its factory.
  /// - Returns: Provider metadata and measurements with separate query context.
  /// - Throws: Any `TidesError` from execution.
  public func value(for request: TidesRequest<VisibilityObservations>) async throws(TidesError)
    -> VisibilityObservations
  {
    guard case .visibilityObservations(let query) = request.resolution else {
      preconditionFailure("Only the visibilityObservations factory constructs this request.")
    }
    let response = try await send(.visibilityObservations(matching: query))
    return VisibilityObservations(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }

  /// Retrieves reported visibility and the original requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: Observations without conversion, gap filling, or station substitution.
  /// - Throws: Any `TidesError` from the shared execution path.
  public func visibilityObservations(matching query: CoastalObservationQuery)
    async throws(TidesError) -> VisibilityObservations
  {
    try await value(for: .visibilityObservations(matching: query))
  }

}

extension TidesClient {
  /// Retrieves NOAA's latest available reading without polling or history fallback.
  /// - Parameter query: The explicit latest query.
  /// - Returns: One reading or a successful empty result, retaining query and reported metadata.
  /// - Throws: A provider refusal, cardinality error, or other shared execution error.
  public func latestWaterLevel(matching query: LatestWaterLevelQuery) async throws(TidesError)
    -> LatestWaterLevel
  {
    try await value(for: .latestWaterLevel(matching: query))
  }

  /// Executes a latest request and rejects plural successful observations.
  /// - Parameter request: A request constructed by the latest factory.
  /// - Returns: The sole reading, or an absent observation for a successful empty array.
  /// - Throws: `TidesError.invalidLatestWaterLevelResponse` for multiple readings, or a shared execution error.
  public func value(for request: TidesRequest<LatestWaterLevel>) async throws(TidesError)
    -> LatestWaterLevel
  {
    guard case .latestWaterLevel(let query) = request.resolution else {
      preconditionFailure("Only the latestWaterLevel factory constructs this request.")
    }
    let response = try await send(.latestWaterLevel(matching: query))
    guard response.observations.count <= 1 else {
      throw .invalidLatestWaterLevelResponse(observationCount: response.observations.count)
    }
    return LatestWaterLevel(
      metadata: response.metadata, observation: response.observations.first, requestedQuery: query)
  }
}

extension TidesClient {
  /// Retrieves preliminary one-minute levels with separate requested context.
  /// - Parameter query: The validated one-minute query.
  /// - Returns: Provider observations without resampling or gap filling.
  /// - Throws: Any shared execution error.
  public func oneMinuteWaterLevels(matching query: OneMinuteWaterLevelQuery)
    async throws(TidesError) -> OneMinuteWaterLevels
  {
    try await value(for: .oneMinuteWaterLevels(matching: query))
  }

  /// Executes a one-minute query through the shared send path.
  /// - Parameter request: A request from the one-minute factory.
  /// - Returns: Provider metadata and observations with their original requested context.
  /// - Throws: Any shared execution error.
  public func value(for request: TidesRequest<OneMinuteWaterLevels>) async throws(TidesError)
    -> OneMinuteWaterLevels
  {
    guard case .oneMinuteWaterLevels(let query) = request.resolution else {
      preconditionFailure("Only the oneMinuteWaterLevels factory constructs this request.")
    }
    let response = try await send(.oneMinuteWaterLevels(matching: query))
    return OneMinuteWaterLevels(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }
}

extension TidesClient {
  /// Retrieves provider-verified observed high/low levels with separate requested context.
  /// - Parameter query: The validated observed high/low query.
  /// - Returns: Provider observations without local extrema calculation or prediction.
  /// - Throws: Any shared execution error.
  public func observedHighLowWaterLevels(matching query: ObservedHighLowWaterLevelQuery)
    async throws(TidesError) -> ObservedHighLowWaterLevels
  {
    try await value(for: .observedHighLowWaterLevels(matching: query))
  }

  /// Executes a observed high/low query through the shared send path.
  /// - Parameter request: A request from the observed high/low factory.
  /// - Returns: Provider metadata and observations with their original requested context.
  /// - Throws: Any shared execution error.
  public func value(for request: TidesRequest<ObservedHighLowWaterLevels>) async throws(TidesError)
    -> ObservedHighLowWaterLevels
  {
    guard case .observedHighLowWaterLevels(let query) = request.resolution else {
      preconditionFailure("Only the observedHighLowWaterLevels factory constructs this request.")
    }
    let response = try await send(.observedHighLowWaterLevels(matching: query))
    return ObservedHighLowWaterLevels(
      metadata: response.metadata, observations: response.observations, requestedQuery: query)
  }
}

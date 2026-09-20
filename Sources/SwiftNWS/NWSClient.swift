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

  /// Retrieves the number of active alerts by region type, marine region, area, and zone.
  ///
  /// Sends one request for a JSON-LD body. The breakdowns overlap and list only codes with an
  /// active alert; see `ActiveAlertCount`.
  ///
  /// - Returns: The counts as the service reported them.
  /// - Throws: Any ``NWSError`` from ``value(for:)``.
  public func activeAlertCount() async throws(NWSError) -> ActiveAlertCount {
    try await value(for: .activeAlertCount)
  }

  /// Creates a lazy page traversal for a reusable alert request.
  /// - Parameter request: A library active-alert or alert-history request, which follows links,
  ///   or a custom one-page endpoint request.
  /// - Returns: An independent, demand-driven page sequence.
  public func activeAlertPages(
    for request: WeatherRequest<FeatureCollection<WeatherAlert>>
  ) -> ActiveAlertPageSequence {
    let collection = alertCollection(for: request)
    return ActiveAlertPageSequence(
      client: self, endpoint: collection.endpoint, followsLinks: collection.followsLinks)
  }

  /// Creates a lazy page traversal for supported active-alert filters.
  /// - Parameter filter: The geographic and CAP restrictions.
  /// - Returns: Alert pages in service order.
  public func activeAlertPages(matching filter: ActiveAlertFilter = .init())
    -> ActiveAlertPageSequence
  {
    activeAlertPages(for: .activeAlerts(matching: filter))
  }

  /// Creates a lazy feature traversal for a reusable active-alert request.
  /// - Parameter request: A library active-alert query or a custom one-page endpoint request.
  /// - Returns: Alert features with their GeoJSON metadata.
  public func activeAlerts(
    for request: WeatherRequest<FeatureCollection<WeatherAlert>>
  ) -> ActiveAlertSequence {
    ActiveAlertSequence(pages: activeAlertPages(for: request))
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
  /// - Parameter area: A state, territory, or marine area code.
  /// - Returns: The returned GeoJSON collection in service order; no automatic pagination.
  /// - Throws: ``NWSError/invalidAlertLocation(_:)`` for an empty code or invalid encoded path,
  ///   or any error from ``value(for:)``.
  public func activeAlerts(inArea area: AreaCode) async throws(NWSError) -> FeatureCollection<
    WeatherAlert
  > {
    guard !Task.isCancelled else { throw .transport(.cancelled) }
    guard let request = WeatherRequest<FeatureCollection<WeatherAlert>>.activeAlerts(inArea: area)
    else {
      throw .invalidAlertLocation(area.rawValue)
    }
    return try await value(for: request)
  }

  /// Retrieves active alerts using a consumer-defined area enum.
  /// - Parameter area: A String-backed state, territory, or marine area code.
  /// - Returns: The returned GeoJSON collection in service order; no automatic pagination.
  /// - Throws: ``NWSError/invalidAlertLocation(_:)`` for an empty code or invalid encoded path,
  ///   or any error from ``value(for:)``.
  public func activeAlerts<Area>(inArea area: Area) async throws(NWSError) -> FeatureCollection<
    WeatherAlert
  > where Area: RawRepresentable, Area.RawValue == String {
    try await activeAlerts(inArea: AreaCode(area))
  }

  /// Retrieves active alerts for a marine region.
  /// - Parameter region: A marine region code.
  /// - Returns: The returned GeoJSON collection in service order; no automatic pagination.
  /// - Throws: ``NWSError/invalidAlertLocation(_:)`` for an empty code or invalid encoded path,
  ///   or any error from ``value(for:)``, including ``NWSError/problem(_:)`` for a
  ///   code the service does not recognize.
  public func activeAlerts(inRegion region: MarineRegionCode) async throws(NWSError)
    -> FeatureCollection<WeatherAlert>
  {
    guard !Task.isCancelled else { throw .transport(.cancelled) }
    guard
      let request = WeatherRequest<FeatureCollection<WeatherAlert>>.activeAlerts(inRegion: region)
    else {
      throw .invalidAlertLocation(region.rawValue)
    }
    return try await value(for: request)
  }

  /// Retrieves active alerts using a consumer-defined marine region enum.
  /// - Parameter region: A String-backed marine region code.
  /// - Returns: The returned GeoJSON collection in service order; no automatic pagination.
  /// - Throws: ``NWSError/invalidAlertLocation(_:)`` for an empty code or invalid encoded path,
  ///   or any error from ``value(for:)``.
  public func activeAlerts<Region>(inRegion region: Region) async throws(NWSError)
    -> FeatureCollection<WeatherAlert>
  where Region: RawRepresentable, Region.RawValue == String {
    try await activeAlerts(inRegion: MarineRegionCode(region))
  }

  /// Retrieves active alerts for a provider zone.
  /// - Parameter zone: A nonempty forecast or county zone identifier.
  /// - Returns: The returned GeoJSON collection in service order; no automatic pagination.
  /// - Throws: ``NWSError/invalidAlertLocation(_:)`` for an empty code or invalid encoded path,
  ///   or any error from ``value(for:)``.
  public func activeAlerts(inZone zone: String) async throws(NWSError) -> FeatureCollection<
    WeatherAlert
  > {
    guard !Task.isCancelled else { throw .transport(.cancelled) }
    guard let request = WeatherRequest<FeatureCollection<WeatherAlert>>.activeAlerts(inZone: zone)
    else {
      throw .invalidAlertLocation(zone)
    }
    return try await value(for: request)
  }

  /// Creates a lazy feature traversal for supported active-alert filters.
  /// - Parameter filter: The geographic and CAP restrictions.
  /// - Returns: Alert features in service order. Use the async overload to retrieve one page.
  public func activeAlerts(matching filter: ActiveAlertFilter = .init()) -> ActiveAlertSequence {
    activeAlerts(for: .activeAlerts(matching: filter))
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

  /// Creates a lazy page traversal for a reusable alert request.
  /// - Parameter request: A library alert-history or active-alert request, which follows links,
  ///   or a custom one-page endpoint request.
  /// - Returns: An independent, demand-driven page sequence.
  public func alertPages(
    for request: WeatherRequest<FeatureCollection<WeatherAlert>>
  ) -> AlertPageSequence {
    let collection = alertCollection(for: request)
    return AlertPageSequence(
      client: self, endpoint: collection.endpoint, followsLinks: collection.followsLinks)
  }

  /// Creates a lazy page traversal for an alert-history query.
  /// - Parameter query: The validated filters, window, page size, and initial cursor.
  /// - Returns: Alert pages in service order.
  public func alertPages(matching query: AlertQuery) -> AlertPageSequence {
    alertPages(for: .alerts(matching: query))
  }

  /// Creates a lazy feature traversal for a reusable alert request.
  /// - Parameter request: A library alert-history or active-alert request, which follows links,
  ///   or a custom one-page endpoint request.
  /// - Returns: Alert features with their GeoJSON metadata.
  public func alerts(
    for request: WeatherRequest<FeatureCollection<WeatherAlert>>
  ) -> AlertSequence {
    AlertSequence(pages: alertPages(for: request))
  }

  /// Creates a lazy feature traversal for an alert-history query.
  /// - Parameter query: The validated filters, window, page size, and initial cursor.
  /// - Returns: Alert features in service order. Use the async overload to retrieve one page.
  public func alerts(matching query: AlertQuery) -> AlertSequence {
    alerts(for: .alerts(matching: query))
  }

  /// Retrieves one page of alert history.
  /// - Parameter query: The validated filters, window, page size, and initial cursor.
  /// - Returns: The returned GeoJSON collection in service order; no automatic pagination.
  /// - Throws: Any ``NWSError`` from ``value(for:)``.
  public func alerts(matching query: AlertQuery) async throws(NWSError)
    -> FeatureCollection<WeatherAlert>
  {
    try await value(for: .alerts(matching: query))
  }

  /// Retrieves the alert event names the service recognizes.
  ///
  /// Sends one request for a JSON-LD body. Names keep the service's order and spelling.
  ///
  /// - Returns: The recognized event names.
  /// - Throws: Any ``NWSError`` from ``value(for:)``.
  public func alertTypes() async throws(NWSError) -> AlertTypes {
    try await value(for: .alertTypes)
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

  /// Retrieves the raw forecast grid data for a coordinate.
  ///
  /// An uncached coordinate sends two requests: the point, then its grid data link. The point comes
  /// from ``pointCache`` when it holds one; the grid itself is never cached, because the service
  /// updates it through the day. Layers, values, and units are returned as the service sent them.
  ///
  /// ```swift
  /// let grid = try await client.forecastGrid(for: home)
  /// let temperatures = grid[.temperature]?.values ?? []
  /// ```
  ///
  /// - Parameter location: The coordinate to look up.
  /// - Returns: The grid cell's raw forecast data.
  /// - Throws: ``NWSError/invalidLink(_:)`` for a disallowed grid data link, ``NWSError/problem(_:)``
  ///   for a refusal with problem details, or any other error from ``send(_:)``.
  public func forecastGrid(for location: WeatherCoordinate) async throws(NWSError) -> ForecastGrid {
    try await value(for: .forecastGrid(for: location))
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

  /// Retrieves the observation a station made at an exact instant.
  ///
  /// Sends one request. The instant must be an observation's timestamp, such as one from
  /// observation history; the service answers any other instant with `404`
  /// problem details rather than the nearest observation, and no fallback is applied.
  ///
  /// ```swift
  /// let observation = try await client.observation(stationIdentifier: "KATT", timestamp: timestamp)
  /// ```
  ///
  /// - Parameters:
  ///   - stationIdentifier: The station's identifier, such as `KATT`.
  ///   - timestamp: The observation's exact timestamp, sent with whole-second precision.
  /// - Returns: The observation, including any missing measurements.
  /// - Throws: ``NWSError/invalidStationIdentifier(_:)`` for an empty identifier or invalid encoded path,
  ///   ``NWSError/problem(_:)`` for an unknown station or an instant with no observation, or any
  ///   other error from ``value(for:)``.
  public func observation(
    stationIdentifier: String, timestamp: Date
  ) async throws(NWSError) -> WeatherObservation {
    try await value(for: .observation(stationIdentifier: stationIdentifier, timestamp: timestamp))
  }

  /// Creates a lazy page traversal for a reusable observation-history request.
  /// - Parameter request: An observation query or a custom one-page endpoint request.
  /// - Returns: An independent, demand-driven page sequence.
  public func observationPages(
    for request: WeatherRequest<FeatureCollection<WeatherObservation>>
  ) -> ObservationPageSequence {
    switch request.resolution {
    case .endpoint(let endpoint):
      ObservationPageSequence(client: self, endpoint: endpoint, followsLinks: false)
    case .observations(let query):
      ObservationPageSequence(
        client: self, endpoint: .observations(query: query), followsLinks: true)
    default:
      preconditionFailure(
        "Only endpoint and observation-query resolutions can describe observation collections.")
    }
  }

  /// Creates a lazy page traversal for an observation-history query.
  /// - Parameter query: The validated station, window, page size, and initial cursor.
  /// - Returns: Observation pages in service order.
  public func observationPages(query: ObservationQuery) -> ObservationPageSequence {
    observationPages(for: .observations(query: query))
  }

  /// Retrieves the metadata for one observation station.
  ///
  /// Sends one request and returns the station's properties, including its zone links and provider
  /// when the service lists them.
  ///
  /// ```swift
  /// let station = try await client.observationStation(identifier: "KATT")
  /// ```
  ///
  /// - Parameter identifier: The station's identifier, such as `KATT`.
  /// - Returns: The station's metadata.
  /// - Throws: ``NWSError/invalidStationIdentifier(_:)`` for an empty identifier or invalid encoded path,
  ///   ``NWSError/problem(_:)`` for an unknown station, or any other error from ``value(for:)``.
  public func observationStation(identifier: String) async throws(NWSError) -> ObservationStation {
    try await value(for: .observationStation(identifier: identifier))
  }

  /// Creates a lazy page traversal for a reusable station request.
  ///
  /// A station-directory query follows continuation links. A nearby-station request resolves the
  /// coordinate's point on the first read and yields exactly one page. A custom endpoint request
  /// yields one page.
  ///
  /// - Parameter request: A station query, a nearby-station request, or a custom one-page endpoint
  ///   request.
  /// - Returns: An independent, demand-driven page sequence.
  public func observationStationPages(
    for request: WeatherRequest<FeatureCollection<ObservationStation>>
  ) -> ObservationStationPageSequence {
    switch request.resolution {
    case .endpoint(let endpoint):
      ObservationStationPageSequence(client: self, endpoint: endpoint, followsLinks: false)
    case .nearbyObservationStations(let location):
      ObservationStationPageSequence(client: self, nearby: location)
    case .observationStations(let query):
      ObservationStationPageSequence(
        client: self, endpoint: .observationStations(query: query), followsLinks: true)
    default:
      preconditionFailure(
        "Only endpoint, nearby-station, and station-query resolutions describe station collections."
      )
    }
  }

  /// Creates a lazy page traversal for a station query.
  /// - Parameter query: The validated filters and initial cursor.
  /// - Returns: Station pages in service order.
  public func observationStationPages(query: ObservationStationQuery)
    -> ObservationStationPageSequence
  {
    observationStationPages(for: .observationStations(query: query))
  }

  /// Creates a lazy feature traversal for a reusable station request.
  /// - Parameter request: A station query, which follows links, or a nearby-station or custom
  ///   endpoint request, which yields one page.
  /// - Returns: Station features with their GeoJSON metadata.
  public func observationStations(
    for request: WeatherRequest<FeatureCollection<ObservationStation>>
  ) -> ObservationStationSequence {
    ObservationStationSequence(pages: observationStationPages(for: request))
  }

  /// Retrieves the observation stations the service lists for a coordinate's grid cell.
  ///
  /// An uncached coordinate sends two requests: the point, then its observation-stations link. The
  /// result is one page in the service's order, which does not guarantee distance order. The page's
  /// continuation link is not followed, because it does not continue this list: it names every
  /// station for the grid again at a later offset and leads only to empty pages.
  ///
  /// ```swift
  /// let stations = try await client.observationStations(near: home)
  /// for station in stations.features {
  ///   print(station.properties.stationIdentifier)
  /// }
  /// ```
  ///
  /// - Parameter location: The coordinate to look up.
  /// - Returns: The station list, with each station's GeoJSON metadata.
  /// - Throws: ``NWSError/invalidLink(_:)`` for a disallowed station link, or any error from
  ///   ``send(_:)``.
  public func observationStations(near location: WeatherCoordinate) async throws(NWSError)
    -> FeatureCollection<ObservationStation>
  {
    try await value(for: .observationStations(near: location))
  }

  /// Creates a lazy feature traversal for a station query.
  /// - Parameter query: The validated filters and initial cursor.
  /// - Returns: Station features in service order.
  public func observationStations(query: ObservationStationQuery) -> ObservationStationSequence {
    observationStations(for: .observationStations(query: query))
  }

  /// Creates a lazy feature traversal for a reusable observation-history request.
  /// - Parameter request: An observation query or a custom one-page endpoint request.
  /// - Returns: Observation features with their GeoJSON metadata.
  public func observations(
    for request: WeatherRequest<FeatureCollection<WeatherObservation>>
  ) -> ObservationSequence {
    ObservationSequence(pages: observationPages(for: request))
  }

  /// Creates a lazy feature traversal for an observation-history query.
  /// - Parameter query: The validated station, window, page size, and initial cursor.
  /// - Returns: Observation features in service order. Use the async overload to retrieve one page.
  public func observations(query: ObservationQuery) -> ObservationSequence {
    observations(for: .observations(query: query))
  }

  /// Retrieves one page of a station's observation history.
  /// - Parameter query: The validated station, window, page size, and initial cursor.
  /// - Returns: The returned GeoJSON collection in service order; no automatic pagination.
  /// - Throws: Any ``NWSError`` from ``value(for:)``.
  public func observations(query: ObservationQuery) async throws(NWSError)
    -> FeatureCollection<WeatherObservation>
  {
    try await value(for: .observations(query: query))
  }

  /// Sends an endpoint and decodes its response.
  ///
  /// Follows at most five redirects within the API origin, preserving request headers.
  /// Every hop checks cancellation. Direct sends bypass point caching.
  ///
  /// - Parameter endpoint: The endpoint to send.
  /// - Returns: The decoded body, including its GeoJSON wrapper when the endpoint names one.
  /// - Throws: ``NWSError/problem(_:)`` for NWS problem details, or ``NWSError/transport(_:)``
  ///   for transport and decoding failures. Cancellation is a transport cancellation.
  ///   Redirects can throw ``NWSError/invalidRedirect(_:)``, ``NWSError/invalidLink(_:)``,
  ///   or ``NWSError/tooManyRedirects``.
  public func send<Value: Decodable & SendableMetatype>(
    _ endpoint: Endpoint<Value>
  ) async throws(NWSError) -> Value {
    var endpoint = endpoint
    var visited = Set<String>()
    for _ in 0...5 {
      guard !Task.isCancelled else { throw .transport(.cancelled) }
      guard visited.insert(endpoint.path).inserted else { throw .tooManyRedirects }
      do {
        return try await client.execute(request(for: endpoint, redirectPolicy: .never))
      } catch {
        guard let next = try redirectEndpoint(after: error, from: endpoint) else {
          throw NWSError(error)
        }
        endpoint = next
      }
    }
    throw .tooManyRedirects
  }

  /// Executes a reusable weather request.
  ///
  /// Endpoint requests decode directly as `Value`. Latest-observation requests resolve their
  /// source and return the observation's properties. Forecast and grid requests follow the point's
  /// link and return the feature's properties. Nearby-station requests follow the point's station
  /// link and return that one page. Station and timed-observation lookups send one
  /// request and return its properties. Coordinate resolutions reuse the point cache. Direct endpoints bypass it. No automatic pagination is applied.
  ///
  /// - Parameter request: The portable description to execute.
  /// - Returns: The concrete response selected by the request's factory or endpoint.
  /// - Throws: ``NWSError/invalidStationIdentifier(_:)`` for an empty identifier or invalid encoded path,
  ///   ``NWSError/invalidAlertIdentifier(_:)`` for an empty alert identifier or invalid encoded path,
  ///   ``NWSError/invalidZoneType(_:)`` or ``NWSError/invalidZoneIdentifier(_:)`` for an empty
  ///   zone type or identifier or invalid encoded path,
  ///   ``NWSError/invalidLink(_:)`` for a disallowed link, ``NWSError/noObservationStation``
  ///   for an empty station list, or any error from ``send(_:)``.
  public func value<Value: Decodable & SendableMetatype>(
    for request: WeatherRequest<Value>
  ) async throws(NWSError) -> Value {
    guard !Task.isCancelled else { throw .transport(.cancelled) }
    switch request.resolution {
    case .activeAlerts(let endpoint):
      return try await send(endpoint)
    case .alert(let identifier):
      guard let endpoint = Endpoint.alert(identifier: identifier) else {
        throw .invalidAlertIdentifier(identifier)
      }
      return try await send(endpoint.decoding(Feature<Value>.self)).properties
    case .alerts(let query):
      let endpoint = Endpoint.alerts(matching: query)
      return try await send(endpoint.decoding(Value.self))
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
        endpoint.decoding(Feature<Value>.self)
      ).properties
    case .forecastGrid(let location):
      let point = try await point(for: location)
      guard let endpoint = Endpoint.forecastGrid(for: point) else {
        throw .invalidLink(point.forecastGridData)
      }
      // Only WeatherRequest<ForecastGrid> can be created with this resolution.
      return try await send(
        endpoint.decoding(Feature<Value>.self)
      ).properties
    case .latestObservation(let source):
      let identifier: String
      switch source {
      case .nearest(let location):
        let stationsEndpoint = try await nearbyObservationStationsEndpoint(for: location)
        guard let station = try await send(stationsEndpoint).features.first?.properties else {
          throw .noObservationStation
        }
        identifier = station.stationIdentifier
      case .station(let stationIdentifier):
        identifier = stationIdentifier
      }
      guard let endpoint = Endpoint.latestObservation(stationIdentifier: identifier) else {
        throw .invalidStationIdentifier(identifier)
      }
      // Only WeatherRequest<WeatherObservation> can be created with this resolution.
      // Decode the same response type through its GeoJSON envelope without erasing or casting it.
      let feature = try await send(
        endpoint.decoding(Feature<Value>.self))
      return feature.properties
    case .nearbyObservationStations(let location):
      let endpoint = try await nearbyObservationStationsEndpoint(for: location)
      // Only WeatherRequest<FeatureCollection<ObservationStation>> can be created with this
      // resolution. The page's continuation link is not followed.
      return try await send(
        endpoint.decoding(Value.self))
    case .observation(let stationIdentifier, let timestamp):
      guard
        let endpoint = Endpoint.observation(
          stationIdentifier: stationIdentifier, timestamp: timestamp)
      else { throw .invalidStationIdentifier(stationIdentifier) }
      // Only WeatherRequest<WeatherObservation> can be created with this resolution.
      return try await send(
        endpoint.decoding(Feature<Value>.self)
      ).properties
    case .observationStation(let identifier):
      guard let endpoint = Endpoint.observationStation(identifier: identifier) else {
        throw .invalidStationIdentifier(identifier)
      }
      // Only WeatherRequest<ObservationStation> can be created with this resolution.
      return try await send(
        endpoint.decoding(Feature<Value>.self)
      ).properties
    case .observationStations(let query):
      let endpoint = Endpoint.observationStations(query: query)
      return try await send(endpoint.decoding(Value.self))
    case .observations(let query):
      let endpoint = Endpoint.observations(query: query)
      return try await send(endpoint.decoding(Value.self))
    case .zone(let effective, let identifier, let type):
      guard Endpoint<Feature<Value>>.zoneTypeSegment(type) != nil else {
        throw .invalidZoneType(type.rawValue)
      }
      guard let endpoint = Endpoint.zone(effective: effective, identifier: identifier, type: type)
      else { throw .invalidZoneIdentifier(identifier) }
      // Only WeatherRequest<WeatherZone> can be created with this resolution.
      return try await send(
        endpoint.decoding(Feature<Value>.self)
      ).properties
    case .zonesOfType(let query, let type):
      guard let endpoint = Endpoint.zones(matching: query, ofType: type) else {
        throw .invalidZoneType(type.rawValue)
      }
      // Only WeatherRequest<FeatureCollection<WeatherZone>> can be created with this resolution.
      // The service returns no continuation for the directory.
      return try await send(endpoint.decoding(Value.self))
    }
  }

  /// Retrieves one zone by type and identifier.
  ///
  /// Sends one request for `/zones/{type}/{zoneId}` and returns the feature's properties. The
  /// zone's polygon is available by sending `Endpoint.zone(effective:identifier:type:)` directly.
  ///
  /// ```swift
  /// let zone = try await weather.zone(identifier: "TXZ192", type: .forecast)
  /// print(zone.name, zone.observationStations?.count ?? 0)
  /// ```
  ///
  /// - Parameters:
  ///   - effective: The instant the definition must be effective at, or nil for the current one.
  ///   - identifier: The zone's identifier, such as `TXZ192`.
  ///   - type: The route's zone type, such as `ZoneType.forecast` or `ZoneType.county`.
  /// - Returns: The zone's properties.
  /// - Throws: ``NWSError/invalidZoneType(_:)`` for an empty type or invalid encoded path,
  ///   ``NWSError/invalidZoneIdentifier(_:)`` for an empty identifier or invalid encoded path,
  ///   or any error from ``value(for:)``.
  public func zone(effective: Date? = nil, identifier: String, type: ZoneType)
    async throws(NWSError) -> WeatherZone
  {
    try await value(for: .zone(effective: effective, identifier: identifier, type: type))
  }

  /// Retrieves one zone using a consumer-defined zone type enum.
  /// - Parameters:
  ///   - effective: The instant the definition must be effective at, or nil for the current one.
  ///   - identifier: The zone's identifier.
  ///   - type: A String-backed zone type.
  /// - Returns: The zone's properties.
  /// - Throws: The errors of ``zone(effective:identifier:type:)-(_,_,ZoneType)``.
  public func zone<Kind>(effective: Date? = nil, identifier: String, type: Kind)
    async throws(NWSError) -> WeatherZone
  where Kind: RawRepresentable, Kind.RawValue == String {
    try await zone(effective: effective, identifier: identifier, type: ZoneType(type))
  }

  /// Lists the zones of one type matching a query.
  ///
  /// Sends one request for `/zones/{type}` and returns that response. The service declares no
  /// page size or cursor for the directory and returns no continuation, so the response is the
  /// whole answer for the query, capped by its limit. Recorded responses list zones with `null`
  /// geometry.
  ///
  /// ```swift
  /// let query = try ZoneQuery(areas: [.texas], limit: 10)
  /// let zones = try await weather.zones(matching: query, ofType: .forecast)
  /// ```
  ///
  /// - Parameters:
  ///   - query: The validated filters.
  ///   - type: The route's zone type.
  /// - Returns: The GeoJSON collection the service answered.
  /// - Throws: ``NWSError/invalidZoneType(_:)`` for an empty type or invalid encoded path, or any
  ///   error from ``value(for:)``.
  public func zones(matching query: ZoneQuery, ofType type: ZoneType) async throws(NWSError)
    -> FeatureCollection<WeatherZone>
  {
    try await value(for: .zones(matching: query, ofType: type))
  }

  /// Lists the zones of one type using a consumer-defined zone type enum.
  /// - Parameters:
  ///   - query: The validated filters.
  ///   - type: A String-backed zone type.
  /// - Returns: The GeoJSON collection the service answered.
  /// - Throws: The errors of ``zones(matching:ofType:)-(_,ZoneType)``.
  public func zones<Kind>(matching query: ZoneQuery, ofType type: Kind) async throws(NWSError)
    -> FeatureCollection<WeatherZone>
  where Kind: RawRepresentable, Kind.RawValue == String {
    try await zones(matching: query, ofType: ZoneType(type))
  }

  /// Lists zones of every type matching a query, optionally restricted to some types.
  ///
  /// Sends one request for `/zones` and returns that response. The service declares no page size
  /// or cursor for the directory and returns no continuation, so the response is the whole answer
  /// for the query, capped by its limit. Recorded responses list zones with `null` geometry.
  ///
  /// ```swift
  /// let query = try ZoneQuery(areas: [.texas], limit: 10)
  /// let zones = try await weather.zones(matching: query, types: [.county, .fire])
  /// ```
  ///
  /// - Parameters:
  ///   - query: The validated filters.
  ///   - types: Zone types to include, or an empty array for every type.
  /// - Returns: The GeoJSON collection the service answered.
  /// - Throws: Any ``NWSError`` from ``value(for:)``.
  public func zones(matching query: ZoneQuery, types: [ZoneType] = []) async throws(NWSError)
    -> FeatureCollection<WeatherZone>
  {
    try await value(for: .zones(matching: query, types: types))
  }

  /// Lists zones of every type using a consumer-defined zone type enum.
  /// - Parameters:
  ///   - query: The validated filters.
  ///   - types: String-backed zone types to include.
  /// - Returns: The GeoJSON collection the service answered.
  /// - Throws: Any ``NWSError`` from ``value(for:)``.
  public func zones<Kind>(matching query: ZoneQuery, types: [Kind]) async throws(NWSError)
    -> FeatureCollection<WeatherZone>
  where Kind: RawRepresentable, Kind.RawValue == String {
    try await zones(matching: query, types: types.map { ZoneType($0) })
  }

  private func alertCollection(
    for request: WeatherRequest<FeatureCollection<WeatherAlert>>
  ) -> (endpoint: Endpoint<FeatureCollection<WeatherAlert>>, followsLinks: Bool) {
    switch request.resolution {
    case .activeAlerts(let endpoint):
      (endpoint, true)
    case .alerts(let query):
      (.alerts(matching: query), true)
    case .endpoint(let endpoint):
      (endpoint, false)
    default:
      preconditionFailure(
        "Only active-alert, alert-history, and endpoint resolutions describe alert collections.")
    }
  }

  func collectionPages<Properties: Decodable & Sendable>(
    endpoint: Endpoint<FeatureCollection<Properties>>, followsLinks: Bool
  ) -> PageSequence<FeatureCollection<Properties>> {
    client.pages(
      request(for: endpoint, redirectPolicy: .never), as: FeatureCollection<Properties>.self
    ) { page, request in
      guard followsLinks,
        let next = try? CollectionPageSequence<Properties>.continuation(
          page.value.pagination, from: endpoint)
      else { return nil }
      var request = request
      request.path = next.path
      return .request(request)
    }
  }

  /// Resolves a coordinate's point and validates its observation-stations link.
  func nearbyObservationStationsEndpoint(
    for location: WeatherCoordinate
  ) async throws(NWSError) -> Endpoint<FeatureCollection<ObservationStation>> {
    let point = try await point(for: location)
    guard let endpoint = Endpoint.observationStations(near: point) else {
      throw .invalidLink(point.observationStations)
    }
    return endpoint
  }

  func redirectEndpoint<Value>(
    after error: TransportError, from endpoint: Endpoint<Value>
  ) throws(NWSError) -> Endpoint<Value>? {
    guard case .httpStatus(_, let code, let fields) = error,
      [301, 302, 303, 307, 308].contains(code),
      let location = fields[.location]
    else { return nil }
    guard let current = URL(string: Self.baseURL.absoluteString + endpoint.path),
      let raw = URL(string: location, encodingInvalidCharacters: false),
      let components = URLComponents(url: raw, resolvingAgainstBaseURL: false),
      let link = URL(string: location, relativeTo: current)?.absoluteURL
    else { throw .invalidRedirect(location) }
    // Validate before resolving, because relative URL resolution can remove dot segments.
    let path = components.percentEncodedPath
    let relativePath = path.hasPrefix("/") ? path : "/" + path
    let query = components.percentEncodedQuery.map { "?" + $0 } ?? ""
    guard Endpoint<Value>(path: relativePath + query) != nil,
      components.scheme != nil || components.host == nil
    else { throw .invalidLink(link) }
    guard
      let next = Endpoint<Value>(
        accept: endpoint.accept, featureFlags: endpoint.featureFlags, link: link)
    else { throw .invalidLink(link) }
    return next
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

  private func request<Response>(
    for endpoint: Endpoint<Response>, redirectPolicy: RedirectPolicy
  ) -> Request {
    var headers = HTTPFields()
    headers[.accept] = endpoint.accept.rawValue
    headers[.userAgent] = configuration.userAgent
    if !endpoint.featureFlags.isEmpty, let name = HTTPField.Name("Feature-Flags") {
      headers[name] = endpoint.featureFlags.map(\.rawValue).joined(separator: ",")
    }
    return Request(
      headers: headers, options: RequestOptions(redirectPolicy: redirectPolicy),
      path: endpoint.path)
  }

  private static let baseURL: URL = {
    guard let url = URL(string: "https://api.weather.gov") else {
      preconditionFailure("https://api.weather.gov is a valid URL.")
    }
    return url
  }()
}

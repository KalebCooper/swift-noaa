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
  /// The client sends each request once unless you pass a retry policy. With
  /// `RetryPolicy.transientServiceFailures`, a request the service answers with a
  /// transient failure is sent again after a wait on `clock`. Each step of a multi-request lookup,
  /// each redirect hop, and each page of a sequence has its own attempt budget. See
  /// <doc:UsingRequests#Retrying-transient-failures>.
  ///
  /// ```swift
  /// let client = NWSClient(
  ///   configuration: NWSConfiguration(userAgent: "(myweatherapp.com, contact@myweatherapp.com)"),
  ///   retryPolicy: .transientServiceFailures,
  ///   transport: transport
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - clock: The clock that times the waits between attempts; defaults to a continuous clock.
  ///     The point cache keeps its own clock.
  ///   - configuration: The values every request is sent with.
  ///   - pointCache: Shared point mappings, or nil to disable caching.
  ///   - retryPolicy: Which failed requests are sent again, how often, and after what wait;
  ///     defaults to `RetryPolicy.disabled`, which sends each request once.
  ///   - transport: What sends each request.
  public init(
    clock: any Clock<Duration> = ContinuousClock(), configuration: NWSConfiguration,
    pointCache: PointCache? = .init(), retryPolicy: RetryPolicy = .disabled,
    transport: any Transport
  ) {
    self.configuration = configuration
    self.pointCache = pointCache
    self.client = HTTPClient(
      baseURL: Self.baseURL, clock: clock, redirectPolicy: .never, retryPolicy: retryPolicy,
      transport: transport)
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

  /// Retrieves the glossary of weather terms the service publishes.
  ///
  /// Sends one request for a JSON-LD body. Entries keep the service's order, repeated terms are
  /// kept, and definitions keep their HTML markup, character entities, and line endings exactly as
  /// the service sent them. The service accepts no page size or cursor here and answers the whole
  /// glossary in one response, so nothing is paged, indexed, or rendered.
  ///
  /// - Returns: The glossary entries in service order.
  /// - Throws: ``NWSError/invalidLink(_:)`` for a disallowed glossary redirect,
  ///   ``NWSError/problem(_:)`` for a refusal with problem details, or any other error from
  ///   ``send(_:)``.
  public func glossary() async throws(NWSError) -> WeatherGlossary {
    try await value(for: .glossary)
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
  /// - Parameter request: A station query, a nearby-station or forecast-zone request, or a custom
  ///   one-page endpoint request.
  /// - Returns: An independent, demand-driven page sequence.
  public func observationStationPages(
    for request: WeatherRequest<FeatureCollection<ObservationStation>>
  ) -> ObservationStationPageSequence {
    switch request.resolution {
    case .endpoint(let endpoint):
      ObservationStationPageSequence(client: self, endpoint: endpoint, followsLinks: false)
    case .forecastZoneStations(let identifier):
      ObservationStationPageSequence(client: self, forecastZone: identifier)
    case .nearbyObservationStations(let location):
      ObservationStationPageSequence(client: self, nearby: location)
    case .observationStations(let query):
      ObservationStationPageSequence(
        client: self, endpoint: .observationStations(query: query), followsLinks: true)
    default:
      preconditionFailure(
        "Only endpoint, forecast-zone, nearby-station, and station-query resolutions describe station collections."
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
  /// - Parameter request: A station query, which follows links, or a nearby-station,
  ///   forecast-zone, or custom endpoint request, which yields one page.
  /// - Returns: Station features with their GeoJSON metadata.
  public func observationStations(
    for request: WeatherRequest<FeatureCollection<ObservationStation>>
  ) -> ObservationStationSequence {
    ObservationStationSequence(pages: observationStationPages(for: request))
  }

  /// Retrieves the observation stations of a forecast zone.
  ///
  /// Sends one request for `/zones/forecast/{zoneId}/stations` and returns its collection in the
  /// service's order. The page's continuation link is not followed, because it does not continue
  /// this list: it names every station again at a later offset and leads only to empty pages.
  ///
  /// ```swift
  /// let stations = try await client.observationStations(inForecastZone: "TXZ192")
  /// for station in stations.features {
  ///   print(station.properties.stationIdentifier)
  /// }
  /// ```
  ///
  /// - Parameter identifier: The forecast zone's identifier, such as `TXZ192`.
  /// - Returns: The station list, with each station's GeoJSON metadata.
  /// - Throws: ``NWSError/invalidZoneIdentifier(_:)`` for an empty identifier or invalid encoded
  ///   path, or any error from ``send(_:)``.
  public func observationStations(inForecastZone identifier: String) async throws(NWSError)
    -> FeatureCollection<ObservationStation>
  {
    try await value(for: .observationStations(inForecastZone: identifier))
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

  /// Retrieves recent observations from the stations of a forecast zone.
  ///
  /// Sends one request for `/zones/forecast/{zoneId}/observations` and returns its collection in
  /// the service's order. The page's continuation link is not followed, because it does not
  /// continue this list: it names one station's observation history instead.
  ///
  /// ```swift
  /// let query = try ZoneObservationQuery(limit: 10, zoneIdentifier: "TXZ192")
  /// let readings = try await client.observations(inForecastZone: query)
  /// ```
  ///
  /// - Parameter query: The validated zone, window, and limit.
  /// - Returns: The returned GeoJSON collection in service order; no automatic pagination.
  /// - Throws: Any ``NWSError`` from ``value(for:)``.
  public func observations(inForecastZone query: ZoneObservationQuery) async throws(NWSError)
    -> FeatureCollection<WeatherObservation>
  {
    try await value(for: .observations(inForecastZone: query))
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

  /// Retrieves one forecast office's metadata.
  ///
  /// Sends one request for a JSON-LD body and returns it unchanged. The office's zone, station,
  /// and parent office fields are links to other API resources; this method follows none of them.
  ///
  /// ```swift
  /// let office = try await weather.office(identifier: "EWX")
  /// print(office.name, office.responsibleForecastZones?.count ?? 0)
  /// ```
  ///
  /// - Parameter identifier: The office's identifier, such as `EWX`.
  /// - Returns: The office's metadata as the service reported it.
  /// - Throws: ``NWSError/invalidOfficeIdentifier(_:)`` for an empty identifier or invalid encoded
  ///   path, ``NWSError/problem(_:)`` for an unknown office, or any other error from
  ///   ``value(for:)``.
  public func office(identifier: String) async throws(NWSError) -> WeatherOffice {
    try await value(for: .office(identifier: identifier))
  }

  /// Retrieves the metadata for an office's current weather briefing.
  ///
  /// Sends one request for a JSON-LD body and returns its briefing. An office with no current
  /// briefing answers `null`, which is nil here after that one request. The briefing's
  /// `download` link is never requested; this method does not retrieve briefing documents.
  ///
  /// ```swift
  /// if let briefing = try await weather.officeBriefing(officeIdentifier: "LWX") {
  ///   print(briefing.title ?? "Untitled briefing")
  ///   if let download = briefing.download {
  ///     print(download)
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter officeIdentifier: The office's identifier, such as `LWX`.
  /// - Returns: The briefing's metadata, or nil when the office has no current briefing.
  /// - Throws: ``NWSError/invalidOfficeIdentifier(_:)`` for an empty identifier or invalid encoded
  ///   path, ``NWSError/problem(_:)`` for an unknown office, or any other error from
  ///   ``send(_:)``.
  public func officeBriefing(officeIdentifier: String) async throws(NWSError) -> OfficeBriefing? {
    try await value(for: .officeBriefing(officeIdentifier: officeIdentifier))
  }

  /// Retrieves one of an office's editorial headlines.
  ///
  /// Sends one request for a JSON-LD body and returns it unchanged. The headline's content keeps
  /// its HTML markup, and its editorial link is never requested.
  ///
  /// ```swift
  /// let headline = try await weather.officeHeadline(
  ///   identifier: "ab45482ca5f57ff412eb1320721d5ac9", officeIdentifier: "EWX")
  /// print(headline.title)
  /// ```
  ///
  /// - Parameters:
  ///   - identifier: The headline's identifier.
  ///   - officeIdentifier: The office's identifier, such as `EWX`.
  /// - Returns: The headline as the service reported it.
  /// - Throws: ``NWSError/invalidOfficeIdentifier(_:)`` for an empty office identifier or invalid
  ///   encoded path, which is checked first, ``NWSError/invalidHeadlineIdentifier(_:)`` for an
  ///   empty headline identifier or invalid encoded path, ``NWSError/problem(_:)`` for an unknown
  ///   headline, or any other error from ``value(for:)``.
  public func officeHeadline(identifier: String, officeIdentifier: String) async throws(NWSError)
    -> OfficeHeadline
  {
    try await value(
      for: .officeHeadline(identifier: identifier, officeIdentifier: officeIdentifier))
  }

  /// Retrieves an office's editorial headlines.
  ///
  /// Sends one request for a JSON-LD body and returns the headlines in the service's order. An
  /// office with nothing to say answers an empty list. The route takes no page size or cursor, so
  /// nothing is paged, sorted, or filtered by importance or issuance time.
  ///
  /// ```swift
  /// let headlines = try await weather.officeHeadlines(officeIdentifier: "EWX")
  /// print(headlines.headlines.map(\.title))
  /// ```
  ///
  /// - Parameter officeIdentifier: The office's identifier, such as `EWX`.
  /// - Returns: The headlines in service order.
  /// - Throws: ``NWSError/invalidOfficeIdentifier(_:)`` for an empty identifier or invalid encoded
  ///   path, ``NWSError/problem(_:)`` for an unknown office, or any other error from
  ///   ``value(for:)``.
  public func officeHeadlines(officeIdentifier: String) async throws(NWSError) -> OfficeHeadlines {
    try await value(for: .officeHeadlines(officeIdentifier: officeIdentifier))
  }

  /// Retrieves the latest product of one kind issued for one location.
  ///
  /// The service selects the product, so this sends one request rather than listing products and
  /// fetching one. The product includes its text.
  ///
  /// ```swift
  /// let product = try await weather.latestProduct(at: "EWX", ofType: .areaForecastDiscussion)
  /// print(product.productText ?? "")
  /// ```
  ///
  /// - Parameters:
  ///   - location: The product location's identifier, such as `EWX`.
  ///   - type: The product's code, such as `ProductCode.areaForecastDiscussion`.
  /// - Returns: The latest product the service issued for that location.
  /// - Throws: ``NWSError/invalidProductCode(_:)`` for an empty code or invalid encoded path,
  ///   ``NWSError/invalidProductLocation(_:)`` for an empty location identifier or invalid encoded
  ///   path, or any error from ``value(for:)``.
  public func latestProduct(at location: String, ofType type: ProductCode) async throws(NWSError)
    -> TextProduct
  {
    try await value(for: .latestProduct(at: location, ofType: type))
  }

  /// Retrieves the latest product of one kind using a consumer-defined product code enum.
  /// - Parameters:
  ///   - location: The product location's identifier.
  ///   - type: A String-backed product code.
  /// - Returns: The latest product the service issued for that location.
  /// - Throws: The errors of ``latestProduct(at:ofType:)-(_,ProductCode)``.
  public func latestProduct<Code>(at location: String, ofType type: Code) async throws(NWSError)
    -> TextProduct
  where Code: RawRepresentable, Code.RawValue == String {
    try await latestProduct(at: location, ofType: ProductCode(type))
  }

  /// Retrieves one text product by identifier.
  ///
  /// The product includes its text, exactly as the service sends it.
  ///
  /// ```swift
  /// let product = try await weather.product(identifier: "a6addd61-6620-4718-9d53-effd7d8c2560")
  /// print(product.issuingOffice ?? "")  // "KEWX"
  /// ```
  ///
  /// - Parameter identifier: The product's identifier, such as
  ///   `a6addd61-6620-4718-9d53-effd7d8c2560`.
  /// - Returns: The product the service issued under that identifier.
  /// - Throws: ``NWSError/invalidProductIdentifier(_:)`` for an empty identifier or invalid
  ///   encoded path, or any error from ``value(for:)``.
  public func product(identifier: String) async throws(NWSError) -> TextProduct {
    try await value(for: .product(identifier: identifier))
  }

  /// Retrieves every location the service issues text products for.
  ///
  /// Sends one request for a JSON-LD body and returns it unchanged. The service describes only
  /// some of the locations it lists and sends `null` for the rest; an undescribed location is kept
  /// with a nil description. The route takes no page size or cursor, so nothing is paged.
  ///
  /// ```swift
  /// let locations = try await weather.productLocations()
  /// print(locations.locations.count)  // 1693
  /// ```
  ///
  /// - Returns: The locations as the service reported them.
  /// - Throws: ``NWSError/invalidLink(_:)`` for a disallowed redirect,
  ///   ``NWSError/problem(_:)`` when the service refuses the request, or any other error from
  ///   ``send(_:)``.
  public func productLocations() async throws(NWSError) -> ProductLocations {
    try await value(for: .productLocations)
  }

  /// Retrieves the locations one kind of text product is issued for.
  ///
  /// Sends one request for a JSON-LD body and returns it unchanged. The route takes no page size
  /// or cursor, so nothing is paged.
  ///
  /// ```swift
  /// let locations = try await weather.productLocations(for: .areaForecastDiscussion)
  /// print(locations.locations["EWX"] ?? nil)  // "Austin/San Antonio, TX"
  /// ```
  ///
  /// - Parameter type: The product's code, such as `ProductCode.areaForecastDiscussion`.
  /// - Returns: The locations as the service reported them.
  /// - Throws: ``NWSError/invalidProductCode(_:)`` for an empty code or invalid encoded path,
  ///   ``NWSError/problem(_:)`` for a code the service does not catalog, or any other error from
  ///   ``value(for:)``.
  public func productLocations(for type: ProductCode) async throws(NWSError) -> ProductLocations {
    try await value(for: .productLocations(for: type))
  }

  /// Retrieves the locations one kind of product is issued for using a consumer-defined product
  /// code enum.
  /// - Parameter type: A String-backed product code.
  /// - Returns: The locations as the service reported them.
  /// - Throws: The errors of ``productLocations(for:)-(ProductCode)``.
  public func productLocations<Code>(for type: Code) async throws(NWSError) -> ProductLocations
  where Code: RawRepresentable, Code.RawValue == String {
    try await productLocations(for: ProductCode(type))
  }

  /// Retrieves the text products of one kind issued for one location.
  ///
  /// The entries carry the products' metadata only; `TextProduct.productText` is nil for every
  /// one of them. Retrieve a bulletin's words with ``product(identifier:)``.
  ///
  /// ```swift
  /// let products = try await weather.products(at: "EWX", ofType: .areaForecastDiscussion)
  /// print(products.products.count)  // 33
  /// ```
  ///
  /// - Parameters:
  ///   - location: The product location's identifier, such as `EWX`.
  ///   - type: The product's code, such as `ProductCode.areaForecastDiscussion`.
  /// - Returns: The products in service order.
  /// - Throws: ``NWSError/invalidProductCode(_:)`` for an empty code or invalid encoded path,
  ///   ``NWSError/invalidProductLocation(_:)`` for an empty location identifier or invalid encoded
  ///   path, or any error from ``value(for:)``.
  public func products(at location: String, ofType type: ProductCode) async throws(NWSError)
    -> TextProducts
  {
    try await value(for: .products(at: location, ofType: type))
  }

  /// Retrieves the text products of one kind issued for one location using a consumer-defined
  /// product code enum.
  /// - Parameters:
  ///   - location: The product location's identifier.
  ///   - type: A String-backed product code.
  /// - Returns: The products in service order.
  /// - Throws: The errors of ``products(at:ofType:)-(_,ProductCode)``.
  public func products<Code>(at location: String, ofType type: Code) async throws(NWSError)
    -> TextProducts
  where Code: RawRepresentable, Code.RawValue == String {
    try await products(at: location, ofType: ProductCode(type))
  }

  /// Retrieves the text products matching a query.
  ///
  /// The entries carry the products' metadata only; `TextProduct.productText` is nil for every
  /// one of them. The route declares no cursor, so this is one response and nothing continues it.
  ///
  /// ```swift
  /// let query = try ProductQuery(limit: 2, locations: ["EWX"], types: [.areaForecastDiscussion])
  /// let products = try await weather.products(matching: query)
  /// ```
  ///
  /// - Parameter query: The validated filters, window, and page size.
  /// - Returns: The products in service order.
  /// - Throws: Any error from ``value(for:)``.
  public func products(matching query: ProductQuery) async throws(NWSError) -> TextProducts {
    try await value(for: .products(matching: query))
  }

  /// Retrieves the text products of one kind.
  ///
  /// The entries carry the products' metadata only; `TextProduct.productText` is nil for every
  /// one of them.
  ///
  /// ```swift
  /// let products = try await weather.products(ofType: .areaForecastDiscussion)
  /// ```
  ///
  /// - Parameter type: The product's code, such as `ProductCode.areaForecastDiscussion`.
  /// - Returns: The products in service order.
  /// - Throws: ``NWSError/invalidProductCode(_:)`` for an empty code or invalid encoded path, or
  ///   any error from ``value(for:)``.
  public func products(ofType type: ProductCode) async throws(NWSError) -> TextProducts {
    try await value(for: .products(ofType: type))
  }

  /// Retrieves the text products of one kind using a consumer-defined product code enum.
  /// - Parameter type: A String-backed product code.
  /// - Returns: The products in service order.
  /// - Throws: The errors of ``products(ofType:)-(ProductCode)``.
  public func products<Code>(ofType type: Code) async throws(NWSError) -> TextProducts
  where Code: RawRepresentable, Code.RawValue == String {
    try await products(ofType: ProductCode(type))
  }

  /// Retrieves every kind of text product the service issues.
  ///
  /// Sends one request for a JSON-LD body and returns it unchanged, keeping the order the service
  /// listed the types in. The route takes no page size or cursor, so nothing is paged.
  ///
  /// ```swift
  /// let types = try await weather.productTypes()
  /// print(types.types.count)  // 338
  /// ```
  ///
  /// - Returns: The product types in service order.
  /// - Throws: ``NWSError/invalidLink(_:)`` for a disallowed redirect,
  ///   ``NWSError/problem(_:)`` when the service refuses the request, or any other error from
  ///   ``send(_:)``.
  public func productTypes() async throws(NWSError) -> ProductTypes {
    try await value(for: .productTypes)
  }

  /// Retrieves the kinds of text product issued for one location.
  ///
  /// Sends one request for a JSON-LD body and returns it unchanged, keeping the order the service
  /// listed the types in. The identifier is sent as one path segment and is not upper-cased or
  /// otherwise normalized. The route takes no page size or cursor, so nothing is paged.
  ///
  /// ```swift
  /// let types = try await weather.productTypes(at: "EWX")
  /// print(types.types.count)  // 20
  /// ```
  ///
  /// - Parameter location: The location's identifier, such as `EWX`.
  /// - Returns: The product types in service order.
  /// - Throws: ``NWSError/invalidProductLocation(_:)`` for an empty identifier or invalid encoded
  ///   path, ``NWSError/problem(_:)`` for a location the service does not catalog, or any other
  ///   error from ``value(for:)``.
  public func productTypes(at location: String) async throws(NWSError) -> ProductTypes {
    try await value(for: .productTypes(at: location))
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
  ///   ``NWSError/invalidOfficeIdentifier(_:)`` or ``NWSError/invalidHeadlineIdentifier(_:)`` for
  ///   an empty office or headline identifier or invalid encoded path,
  ///   ``NWSError/invalidProductCode(_:)``, ``NWSError/invalidProductIdentifier(_:)``, or
  ///   ``NWSError/invalidProductLocation(_:)`` for an empty product code, product identifier, or
  ///   location identifier or invalid encoded path,
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
    case .forecastZoneStations(let identifier):
      let endpoint = try forecastZoneStationsEndpoint(identifier: identifier)
      // Only WeatherRequest<FeatureCollection<ObservationStation>> can be created with this
      // resolution. The page's continuation link is not followed.
      return try await send(endpoint.decoding(Value.self))
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
    case .latestProduct(let location, let type):
      guard Endpoint<Value>.productSegment(type.rawValue) != nil else {
        throw .invalidProductCode(type.rawValue)
      }
      guard let endpoint = Endpoint.latestProduct(at: location, ofType: type) else {
        throw .invalidProductLocation(location)
      }
      // Only WeatherRequest<TextProduct> can be created with this resolution. The service selects
      // the product, so no list is retrieved first.
      return try await send(endpoint.decoding(Value.self))
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
    case .office(let identifier):
      guard let endpoint = Endpoint.office(identifier: identifier) else {
        throw .invalidOfficeIdentifier(identifier)
      }
      // Only WeatherRequest<WeatherOffice> can be created with this resolution.
      return try await send(endpoint.decoding(Value.self))
    case .officeBriefing(let officeIdentifier):
      guard let endpoint = Endpoint.officeBriefing(officeIdentifier: officeIdentifier) else {
        throw .invalidOfficeIdentifier(officeIdentifier)
      }
      // Only WeatherRequest<OfficeBriefing?> can be created with this resolution.
      return try await send(endpoint.decoding(BriefingEnvelope<Value>.self)).briefing
    case .officeHeadline(let identifier, let officeIdentifier):
      guard Endpoint<Value>.officeSegment(officeIdentifier) != nil else {
        throw .invalidOfficeIdentifier(officeIdentifier)
      }
      guard
        let endpoint = Endpoint.officeHeadline(
          identifier: identifier, officeIdentifier: officeIdentifier)
      else { throw .invalidHeadlineIdentifier(identifier) }
      // Only WeatherRequest<OfficeHeadline> can be created with this resolution.
      return try await send(endpoint.decoding(Value.self))
    case .officeHeadlines(let officeIdentifier):
      guard let endpoint = Endpoint.officeHeadlines(officeIdentifier: officeIdentifier) else {
        throw .invalidOfficeIdentifier(officeIdentifier)
      }
      // Only WeatherRequest<OfficeHeadlines> can be created with this resolution. The route takes
      // no page size or cursor, so nothing is paged.
      return try await send(endpoint.decoding(Value.self))
    case .product(let identifier):
      guard let endpoint = Endpoint.product(identifier: identifier) else {
        throw .invalidProductIdentifier(identifier)
      }
      // Only WeatherRequest<TextProduct> can be created with this resolution.
      return try await send(endpoint.decoding(Value.self))
    case .productLocations(let type):
      guard let endpoint = Endpoint.productLocations(for: type) else {
        throw .invalidProductCode(type.rawValue)
      }
      // Only WeatherRequest<ProductLocations> can be created with this resolution. The route takes
      // no page size or cursor, so nothing is paged.
      return try await send(endpoint.decoding(Value.self))
    case .productsOfType(let location, let type):
      guard let typed = Endpoint<TextProducts>.products(ofType: type) else {
        throw .invalidProductCode(type.rawValue)
      }
      // Only WeatherRequest<TextProducts> can be created with this resolution. The routes declare
      // no cursor, so nothing is paged.
      guard let location else { return try await send(typed.decoding(Value.self)) }
      guard let endpoint = Endpoint.products(at: location, ofType: type) else {
        throw .invalidProductLocation(location)
      }
      return try await send(endpoint.decoding(Value.self))
    case .productTypes(let location):
      guard let endpoint = Endpoint.productTypes(at: location) else {
        throw .invalidProductLocation(location)
      }
      // Only WeatherRequest<ProductTypes> can be created with this resolution. The route takes no
      // page size or cursor, so nothing is paged.
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
    case .zoneForecast(let identifier, let type):
      guard Endpoint<Feature<Value>>.zoneTypeSegment(type) != nil else {
        throw .invalidZoneType(type.rawValue)
      }
      guard let endpoint = Endpoint.zoneForecast(identifier: identifier, type: type) else {
        throw .invalidZoneIdentifier(identifier)
      }
      // Only WeatherRequest<ZoneForecast> can be created with this resolution.
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

  /// Retrieves a zone's text forecast.
  ///
  /// Sends one request for `/zones/{type}/{zoneId}/forecast` and returns the feature's
  /// properties: named periods carrying only text, with no times, temperatures, or units. The
  /// zone's polygon is available by sending `Endpoint.zoneForecast(identifier:type:)` directly.
  ///
  /// ```swift
  /// let forecast = try await weather.zoneForecast(identifier: "TXZ192", type: .forecast)
  /// print(forecast.periods.first?.detailedForecast ?? "")
  /// ```
  ///
  /// - Parameters:
  ///   - identifier: The zone's identifier, such as `TXZ192`.
  ///   - type: The route's zone type, such as `ZoneType.forecast`.
  /// - Returns: The forecast's properties.
  /// - Throws: ``NWSError/invalidZoneType(_:)`` for an empty type or invalid encoded path,
  ///   ``NWSError/invalidZoneIdentifier(_:)`` for an empty identifier or invalid encoded path, or
  ///   any error from ``send(_:)``.
  public func zoneForecast(identifier: String, type: ZoneType) async throws(NWSError)
    -> ZoneForecast
  {
    try await value(for: .zoneForecast(identifier: identifier, type: type))
  }

  /// Retrieves a zone's text forecast using a consumer-defined zone type enum.
  /// - Parameters:
  ///   - identifier: The zone's identifier.
  ///   - type: A String-backed zone type.
  /// - Returns: The forecast's properties.
  /// - Throws: The errors of ``zoneForecast(identifier:type:)-(_,ZoneType)``.
  public func zoneForecast<Kind>(identifier: String, type: Kind) async throws(NWSError)
    -> ZoneForecast
  where Kind: RawRepresentable, Kind.RawValue == String {
    try await zoneForecast(identifier: identifier, type: ZoneType(type))
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

  /// Validates a forecast zone's identifier and names its stations endpoint, without I/O.
  func forecastZoneStationsEndpoint(
    identifier: String
  ) throws(NWSError) -> Endpoint<FeatureCollection<ObservationStation>> {
    guard let endpoint = Endpoint.observationStations(inForecastZone: identifier) else {
      throw .invalidZoneIdentifier(identifier)
    }
    return endpoint
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

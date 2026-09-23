import Foundation
import HTTPCore
import HTTPTesting
import SwiftNWSModels
import SwiftNWSTestSupport
import Synchronization
import Testing

@testable import SwiftNWS

@Suite("Point cache", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct PointCacheTests {
  @Test("Cache expiry uses the injected clock and expires at the boundary")
  func cacheExpiryUsesTheInjectedClockAndExpiresAtTheBoundary() throws {
    let clock = ManualPointClock()
    let cache = PointCache(clock: clock, lifetime: .seconds(10))
    let location = try WeatherCoordinate(latitude: 30, longitude: -97)
    let point = try recordedPoint()
    cache.insert(point, for: location, generation: cache.lookup(location).generation)
    clock.advance(by: .seconds(9))
    #expect(cache.lookup(location).point == point)
    clock.advance(by: .seconds(1))
    #expect(cache.lookup(location).point == nil)
  }

  @Test("Clearing blocks an earlier lookup from repopulating the cache")
  func clearingBlocksAnEarlierLookupFromRepopulatingTheCache() throws {
    let cache = PointCache()
    let location = try WeatherCoordinate(latitude: 30, longitude: -97)
    let generation = cache.lookup(location).generation
    cache.removeAll()
    cache.insert(try recordedPoint(), for: location, generation: generation)
    #expect(cache.lookup(location).point == nil)
  }

  @Test("Concurrent cache operations stay bounded and safe")
  func concurrentCacheOperationsStayBoundedAndSafe() async throws {
    let cache = PointCache(capacity: 4)
    let point = try recordedPoint()
    let locations = try (0..<16).map { try WeatherCoordinate(latitude: Double($0), longitude: 0) }
    await withTaskGroup(of: Void.self) { group in
      for location in locations {
        group.addTask {
          let generation = cache.lookup(location).generation
          cache.insert(point, for: location, generation: generation)
        }
      }
    }
    #expect(locations.filter { cache.lookup($0).point != nil }.count == 4)
  }

  @Test("Forecasts and observations share normalized point mappings")
  func forecastsAndObservationsShareNormalizedPointMappings() async throws {
    let transport = try preparedTransport()
    let client = NWSClient(configuration: .init(userAgent: "test"), transport: transport)
    let copy = client
    let first = try WeatherCoordinate(latitude: 30.26721, longitude: -97.74306)
    let same = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
    _ = try await client.forecast(for: first)
    _ = try await copy.hourlyForecast(for: same)
    _ = try await client.latestObservation(from: .nearest(to: same))
    #expect(transport.requests.filter { $0.request.path == "/points/30.2672,-97.7431" }.count == 1)
    client.pointCache?.removeAll()
    _ = try await copy.forecast(for: same)
    #expect(transport.requests.filter { $0.request.path == "/points/30.2672,-97.7431" }.count == 2)
  }

  @Test("Least recently used points are evicted")
  func leastRecentlyUsedPointsAreEvicted() throws {
    let cache = PointCache(capacity: 2)
    let locations = try (0..<3).map { try WeatherCoordinate(latitude: Double($0), longitude: 0) }
    let point = try recordedPoint()
    for location in locations.prefix(2) {
      cache.insert(point, for: location, generation: cache.lookup(location).generation)
    }
    #expect(cache.lookup(locations[0]).point != nil)
    cache.insert(point, for: locations[2], generation: cache.lookup(locations[2]).generation)
    #expect(cache.lookup(locations[0]).point != nil)
    #expect(cache.lookup(locations[1]).point == nil)
    #expect(cache.lookup(locations[2]).point != nil)
  }

  @Test("Opting out and direct endpoints always fetch the point")
  func optingOutAndDirectEndpointsAlwaysFetchThePoint() async throws {
    let transport = try preparedTransport()
    let client = NWSClient(
      configuration: .init(userAgent: "test"), pointCache: nil, transport: transport)
    let location = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
    _ = try await client.forecast(for: location)
    _ = try await client.hourlyForecast(for: location)
    let cached = NWSClient(configuration: .init(userAgent: "test"), transport: transport)
    _ = try await cached.forecast(for: location)
    _ = try await cached.send(.point(for: location))
    #expect(transport.requests.filter { $0.request.path == "/points/30.2672,-97.7431" }.count == 4)
  }

  private func preparedTransport() throws -> MockTransport {
    let transport = MockTransport()
    for (path, fixture) in [
      ("/points/30.2672,-97.7431", Fixture.point),
      ("/gridpoints/EWX/156,91/forecast", .forecast),
      ("/gridpoints/EWX/156,91/forecast/hourly", .hourlyForecast),
      ("/gridpoints/EWX/156,91/stations", .observationStations),
      ("/stations/KATT/observations/latest", .observation),
    ] {
      let body = try fixture.data()
      transport.setHandler(forPath: path) { _ in
        .success(MockTransport.Answer(Response(body: body, status: .ok)))
      }
    }
    return transport
  }

  private func recordedPoint() throws -> WeatherPoint {
    try JSONDecoder().decode(Feature<WeatherPoint>.self, from: Fixture.point.data()).properties
  }
}

private final class ManualPointClock: Clock {
  typealias Duration = Swift.Duration
  typealias Instant = ContinuousClock.Instant

  private let instant = Mutex(ContinuousClock().now)

  var minimumResolution: Duration { .nanoseconds(1) }
  var now: Instant { instant.withLock { $0 } }

  func advance(by duration: Duration) {
    instant.withLock { $0 = $0.advanced(by: duration) }
  }

  func sleep(until deadline: Instant, tolerance: Duration?) async throws {
    throw CancellationError()
  }
}

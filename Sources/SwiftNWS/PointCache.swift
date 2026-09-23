import SwiftNWSModels
import Synchronization

/// A bounded, expiring cache of coordinate-to-grid mappings.
///
/// Copies of a client share their cache. Only successful point lookups are stored; forecasts and
/// observations are never cached here. Concurrent misses may send independent requests.
///
/// ```swift
/// let cache = PointCache(capacity: 64, lifetime: .seconds(3_600))
/// cache.removeAll()
/// ```
public final class PointCache: Sendable {
  private let storage: any PointStorage

  /// Creates a cache using a monotonic clock.
  /// - Parameters:
  ///   - capacity: The maximum number of points; must be positive.
  ///   - clock: The clock used to measure expiry.
  ///   - lifetime: How long a successful point stays valid; must be positive.
  public init<C: Clock>(
    capacity: Int = 128, clock: C = ContinuousClock(), lifetime: Duration = .seconds(86_400)
  ) where C.Duration == Duration {
    precondition(capacity > 0, "A point cache must hold at least one point.")
    precondition(lifetime > .zero, "A point cache must have a positive lifetime.")
    storage = ClockPointStorage(capacity: capacity, clock: clock, lifetime: lifetime)
  }

  /// Removes all points and prevents earlier in-flight lookups from repopulating the cache.
  public func removeAll() {
    storage.removeAll()
  }

  func insert(_ point: WeatherPoint, for location: WeatherCoordinate, generation: UInt64) {
    storage.insert(point, for: location, generation: generation)
  }

  func lookup(_ location: WeatherCoordinate) -> (point: WeatherPoint?, generation: UInt64) {
    storage.lookup(location)
  }
}

private protocol PointStorage: Sendable {
  func insert(_ point: WeatherPoint, for location: WeatherCoordinate, generation: UInt64)
  func lookup(_ location: WeatherCoordinate) -> (point: WeatherPoint?, generation: UInt64)
  func removeAll()
}

private final class ClockPointStorage<C: Clock>: PointStorage where C.Duration == Duration {
  private struct Entry: Sendable {
    let expires: C.Instant
    let point: WeatherPoint
  }

  private struct State: Sendable {
    var entries: [WeatherCoordinate: Entry] = [:]
    var generation: UInt64 = 0
    var order: [WeatherCoordinate] = []
  }

  private let capacity: Int
  private let clock: C
  private let lifetime: Duration
  private let state = Mutex(State())

  init(capacity: Int, clock: C, lifetime: Duration) {
    self.capacity = capacity
    self.clock = clock
    self.lifetime = lifetime
  }

  func insert(_ point: WeatherPoint, for location: WeatherCoordinate, generation: UInt64) {
    state.withLock { state in
      guard state.generation == generation else { return }
      let now = clock.now
      state.entries = state.entries.filter { $0.value.expires > now }
      state.order.removeAll { state.entries[$0] == nil || $0 == location }
      if state.entries[location] == nil, state.entries.count >= capacity,
        let oldest = state.order.first
      {
        state.entries.removeValue(forKey: oldest)
        state.order.removeFirst()
      }
      state.entries[location] = Entry(expires: now.advanced(by: lifetime), point: point)
      state.order.append(location)
    }
  }

  func lookup(_ location: WeatherCoordinate) -> (point: WeatherPoint?, generation: UInt64) {
    state.withLock { state in
      guard let entry = state.entries[location], entry.expires > clock.now else {
        state.entries.removeValue(forKey: location)
        state.order.removeAll { $0 == location }
        return (nil, state.generation)
      }
      state.order.removeAll { $0 == location }
      state.order.append(location)
      return (entry.point, state.generation)
    }
  }

  func removeAll() {
    state.withLock { state in
      state.entries.removeAll()
      state.order.removeAll()
      state.generation &+= 1
    }
  }
}

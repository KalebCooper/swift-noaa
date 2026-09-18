/// The alert event names the service recognizes, from `/alerts/types`.
///
/// Event names are open strings in service order, such as `Heat Advisory`. The list can grow or
/// change without a new version of this package, and it is not a guarantee that any event is
/// currently active. Pass a name to ``ActiveAlertFilter/event`` or ``AlertQuery`` to filter alerts.
///
/// ```swift
/// let types = try await weather.alertTypes()
/// let filter = ActiveAlertFilter(event: [types.eventTypes[0]])
/// ```
public struct AlertTypes: Codable, Hashable, Sendable {
  /// The recognized event names, in the order the service listed them.
  public var eventTypes: [String]

  /// Creates a list of recognized alert event names.
  ///
  /// - Parameter eventTypes: The recognized event names.
  public init(eventTypes: [String]) {
    self.eventTypes = eventTypes
  }
}

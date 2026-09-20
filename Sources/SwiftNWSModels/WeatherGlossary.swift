/// The glossary of weather terms the service publishes, from `/glossary`.
///
/// Entries keep the order the service listed them in, and the list is an array rather than a
/// dictionary because the service repeats some terms with different definitions. A body without a
/// `glossary` array, or with one that is not an array of entries, fails to decode rather than
/// producing an empty glossary.
///
/// The service returns the whole glossary in one response. It accepts no page size or cursor, so
/// this package offers no glossary pagination, search index, or term lookup policy.
///
/// ```swift
/// let glossary = try await weather.glossary()
/// let matches = glossary.entries.filter { $0.term == "AGL" }
/// ```
public struct WeatherGlossary: Codable, Hashable, Sendable {
  /// The glossary entries, in the order the service listed them, including repeated terms.
  public var entries: [GlossaryEntry]

  /// Creates a glossary.
  ///
  /// - Parameter entries: The glossary entries, in the order they should be kept.
  public init(entries: [GlossaryEntry]) {
    self.entries = entries
  }

  private enum CodingKeys: String, CodingKey {
    case entries = "glossary"
  }
}

/// One term and its definition in the service's glossary.
///
/// Both fields are required. The definition is the service's text exactly as it was sent, including
/// HTML markup such as `<br>`, character entities such as `&deg;`, and carriage return line
/// endings. This package does not render, escape, or strip that markup.
///
/// ```swift
/// let entry = GlossaryEntry(definition: "Above Ground Level", term: "AGL")
/// ```
public struct GlossaryEntry: Codable, Hashable, Sendable {
  /// The service's description of the term, with its markup and line endings unchanged.
  public var definition: String

  /// The term as the service spells it, such as `AGL`.
  ///
  /// The service repeats some terms with different definitions, so a term does not identify an
  /// entry.
  public var term: String

  /// Creates a glossary entry.
  ///
  /// - Parameters:
  ///   - definition: The description of the term.
  ///   - term: The term being defined.
  public init(definition: String, term: String) {
    self.definition = definition
    self.term = term
  }
}

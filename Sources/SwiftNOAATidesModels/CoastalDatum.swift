/// A named entry in a station's datum table.
///
/// Read `description` before interpreting `value`: some entries describe ranges or time intervals.
/// This table does not authorize converting arbitrary heights between reference systems.
public struct CoastalDatum: Codable, Hashable, Sendable {
  /// The provider's description, including any entry-specific unit qualification.
  public let description: String
  /// The provider's open datum or derived-entry name.
  public let name: String
  /// The numeric value without conversion; the table units and description establish its meaning.
  public let value: Double
}

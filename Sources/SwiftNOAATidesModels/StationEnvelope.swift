#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

package struct ProviderErrorEnvelope: Decodable {
  let error: DataError?
  let errorCode: Int?
  let errorMsg: String?

  private enum CodingKeys: String, CodingKey {
    case error
    case errorCode
    case errorMsg
  }

  package init(from decoder: any Decoder) throws {
    // Custom endpoints may decode arrays or scalar JSON as well as object envelopes.
    guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
      error = nil
      errorCode = nil
      errorMsg = nil
      return
    }
    error = container.contains(.error) ? try container.decode(DataError.self, forKey: .error) : nil
    errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode)
    errorMsg =
      container.contains(.errorMsg) ? try container.decode(String.self, forKey: .errorMsg) : nil
  }

  struct DataError: Decodable {
    let message: String
  }

  package var providerError: TidesProviderError? {
    if let error { return TidesProviderError(code: nil, message: error.message) }
    if let errorMsg { return TidesProviderError(code: errorCode, message: errorMsg) }
    return nil
  }
}

package struct StationEnvelope<Value: Decodable>: Decodable {
  package let count: Int
  package let stations: [Entry]

  package struct Entry: Decodable {
    package let identifier: String
    package let value: Value

    private enum CodingKeys: String, CodingKey {
      case identifier = "id"
    }

    package init(from decoder: any Decoder) throws {
      identifier = try decoder.container(keyedBy: CodingKeys.self).decode(
        String.self, forKey: .identifier)
      value = try Value(from: decoder)
    }
  }
}

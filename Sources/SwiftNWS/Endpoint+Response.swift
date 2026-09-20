import SwiftNWSModels

extension Endpoint {
  // Reinterpret an already validated endpoint without erasing its response type.
  func decoding<Value>(_ type: Value.Type) -> Endpoint<Value> {
    guard let endpoint = Endpoint<Value>(accept: accept, featureFlags: featureFlags, path: path)
    else {
      preconditionFailure("An existing endpoint always contains a valid path.")
    }
    return endpoint
  }
}

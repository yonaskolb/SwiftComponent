// Copyright (c) 2024 Point-Free, Inc.
// https://github.com/pointfreeco/swift-composable-architecture/blob/main/LICENSE

import Foundation
import OrderedCollections

@inlinable
func areOrderedSetsDuplicates<T>(_ lhs: OrderedSet<T>, _ rhs: OrderedSet<T>) -> Bool {
  guard lhs.count == rhs.count
  else { return false }

  return withUnsafePointer(to: lhs) { lhsPointer in
    withUnsafePointer(to: rhs) { rhsPointer in
      memcmp(lhsPointer, rhsPointer, MemoryLayout<OrderedSet<T>>.size) == 0 || lhs == rhs
    }
  }
}

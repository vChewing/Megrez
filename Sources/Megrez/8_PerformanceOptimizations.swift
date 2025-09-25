// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - StringJoinCache

/// 用於頻繁計算的字串合併操作快取
internal final class StringJoinCache: @unchecked Sendable {
  // MARK: Lifecycle

  private init() {}

  // MARK: Internal

  static let shared = StringJoinCache()

  func getCachedJoin(_ strings: [String], separator: String) -> String {
    let key = strings.joined(separator: "|") + "|\(separator)"

    return lock.withLock {
      if let cached = joinCache[key] {
        return cached
      }

      let result = strings.joined(separator: separator)

      // 防止快取無限制增長
      if joinCache.count < maxCacheSize {
        joinCache[key] = result
      }

      return result
    }
  }

  func clear() {
    lock.withLock {
      joinCache.removeAll(keepingCapacity: true)
    }
  }

  // MARK: Private

  private var joinCache: [String: String] = [:]
  private let lock = NSLock()
  private let maxCacheSize = 1_000
}

// MARK: - NodeArrayPool

/// 專用於 Node 陣列的物件池
internal final class NodeArrayPool {
  // MARK: Lifecycle

  private init() {}

  // MARK: Internal

  static let shared = NodeArrayPool()

  func borrow() -> [Megrez.Node] {
    lock.withLock {
      if let array = arrays.popLast() {
        return array
      }
      return []
    }
  }

  func returnArray(_ array: [Megrez.Node]) {
    var mutableArray = array
    lock.withLock {
      mutableArray.removeAll(keepingCapacity: true)
      arrays.append(mutableArray)
    }
  }

  func withBorrowedArray<R>(_ body: (inout [Megrez.Node]) throws -> R) rethrows -> R {
    var array = borrow()
    defer { returnArray(array) }
    return try body(&array)
  }

  // MARK: Private

  private var arrays: [[Megrez.Node]] = []
  private let lock = NSLock()
}

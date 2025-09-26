// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// This package is trying to deprecate its dependency of Foundation, hence this file.

extension StringProtocol {
  func has(string target: any StringProtocol) -> Bool {
    let selfArray = Array(unicodeScalars)
    let targetArray = Array(target.description.unicodeScalars)
    guard !target.isEmpty else { return isEmpty }
    guard count >= target.count else { return false }
    for index in selfArray.indices {
      let range = index ..< (Swift.min(index + targetArray.count, selfArray.count))
      let ripped = Array(selfArray[range])
      if ripped == targetArray { return true }
    }
    return false
  }

  func sliced(by separator: any StringProtocol = "") -> [String] {
    let selfArray = Array(unicodeScalars)
    let arrSeparator = Array(separator.description.unicodeScalars)
    var result: [String] = []
    var buffer: [Unicode.Scalar] = []
    var sleepCount = 0
    for index in selfArray.indices {
      let currentChar = selfArray[index]
      let range = index ..< (Swift.min(index + arrSeparator.count, selfArray.count))
      let ripped = Array(selfArray[range])
      if ripped.isEmpty { continue }
      if ripped == arrSeparator {
        sleepCount = range.count
        result.append(buffer.map { String($0) }.joined())
        buffer.removeAll()
      }
      if sleepCount < 1 {
        buffer.append(currentChar)
      }
      sleepCount -= 1
    }
    result.append(buffer.map { String($0) }.joined())
    buffer.removeAll()
    return result
  }

  func swapping(_ target: String, with newString: String) -> String {
    let selfArray = Array(unicodeScalars)
    let arrTarget = Array(target.description.unicodeScalars)
    var result = ""
    var buffer: [Unicode.Scalar] = []
    var sleepCount = 0
    for index in selfArray.indices {
      let currentChar = selfArray[index]
      let range = index ..< (Swift.min(index + arrTarget.count, selfArray.count))
      let ripped = Array(selfArray[range])
      if ripped.isEmpty { continue }
      if ripped == arrTarget {
        sleepCount = ripped.count
        result.append(buffer.map { String($0) }.joined())
        result.append(newString)
        buffer.removeAll()
      }
      if sleepCount < 1 {
        buffer.append(currentChar)
      }
      sleepCount -= 1
    }
    result.append(buffer.map { String($0) }.joined())
    buffer.removeAll()
    return result
  }
}

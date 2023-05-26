// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

// This package is trying to deprecate its dependency of Foundation, hence this file.

extension StringProtocol {
  fileprivate subscript(offset: Int) -> Character { self[index(startIndex, offsetBy: offset)] }
  fileprivate subscript(range: PartialRangeFrom<Int>) -> SubSequence { self[index(startIndex, offsetBy: range.lowerBound)...] }
  fileprivate subscript(range: PartialRangeThrough<Int>) -> SubSequence { self[...index(startIndex, offsetBy: range.upperBound)] }
  fileprivate subscript(range: PartialRangeUpTo<Int>) -> SubSequence { self[..<index(startIndex, offsetBy: range.upperBound)] }

  fileprivate subscript(range: Range<Int>) -> SubSequence {
    self[index(startIndex, offsetBy: range.lowerBound) ..< index(index(startIndex, offsetBy: range.lowerBound), offsetBy: range.count)]
  }

  fileprivate subscript(range: ClosedRange<Int>) -> SubSequence {
    self[index(startIndex, offsetBy: range.lowerBound) ..< index(index(startIndex, offsetBy: range.lowerBound), offsetBy: range.count)]
  }

  func has(string target: any StringProtocol) -> Bool {
    guard !target.isEmpty else { return isEmpty }
    guard count >= target.count else { return false }
    for index in 0 ..< count {
      let currentChar = self[index]
      for subIndex in 0 ..< target.count {
        if index + subIndex <= count - 1, currentChar != self[index + subIndex] {
          break
        }
        if subIndex == target.count - 1 {
          return true
        }
      }
    }
    return false
  }

  func sliced(by separator: any StringProtocol = "") -> [String] {
    var result: [String] = []
    var buffer = ""
    guard !separator.isEmpty, count >= separator.count else { return map(\.description) }
    var sleepCount = 0
    for index in 0 ..< count {
      let currentChar = self[index]
      ripCheck: if currentChar == separator.first {
        let range = index ..< (Swift.min(index + separator.count, count))
        let ripped = self[range]
        sleepCount = range.count
        if ripped != separator {
          break ripCheck
        } else {
          result.append(buffer)
          buffer.removeAll()
        }
      }
      if sleepCount < 1 {
        buffer.append(currentChar)
      }
      sleepCount -= 1
    }
    result.append(buffer)
    buffer.removeAll()
    return result
  }
}

// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular" (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

extension Megrez.Compositor {
  public struct Candidate {
    let key: String
    let value: String
  }

  /// Returns all candidate values at the location. If spans are not empty and
  /// loc is at the end of the spans, (loc - 1) is used, so that the caller does
  /// not have to care about this boundary condition.
  /// - Parameter location: Cursor Location.
  /// - Returns: An array of Candidates.
  public func candidates(at location: Int) -> [Candidate] {
    var result = [Candidate]()
    guard !keys.isEmpty, location <= keys.count else { return result }
    let nodes: [NodeInSpan] = overlappingNodes(at: location == keys.count ? location - 1 : location).stableSorted {
      // 按照讀音的長度來給節點排序。
      $0.spanLength > $1.spanLength
    }

    // TASK: This part might be optimizable by using LINQ.
    for node in nodes {
      for unigram in node.node.unigrams {
        result.append(.init(key: node.key, value: unigram.value))
      }
    }
    return result
  }

  /// Adds weight to the node with the unigram that has the designated candidate
  /// value and applies the desired override type, essentially resulting in user
  /// override. An overridden node would influence the grid walk to favor walking
  /// through it.
  /// - Parameters:
  ///   - candidate: Designated candidate value.
  ///   - location: Cursor location.
  ///   - overrideType: Desired override type.
  /// - Returns: Whether operation performed successfully.
  public func overrideCandidate(
    _ candidate: Candidate, at location: Int, overrideType: Node.OverrideType = .withHighScore
  )
    -> Bool
  {
    overrideCandidateAgainst(key: candidate.key, at: location, value: candidate.value, type: overrideType)
  }

  /// Adds weight to the node with the unigram that has the designated candidate
  /// string and applies the desired override type, essentially resulting in user
  /// override. An overridden node would influence the grid walk to favor walking
  /// through it.
  ///
  /// since the string candidate value is used, if there are multiple nodes (of
  /// different spanning length) that have the same unigram value, it's not
  ///  guaranteed which node will be selected.
  /// - Parameters:
  ///   - candidate: Designated candidate value.
  ///   - location: Cursor location.
  ///   - overrideType: Desired override type.
  /// - Returns: Whether operation performed successfully.
  public func overrideCandidateLiteral(
    _ candidate: String,
    at location: Int, overrideType: Node.OverrideType = .withHighScore
  ) -> Bool {
    overrideCandidateAgainst(key: nil, at: location, value: candidate, type: overrideType)
  }

  // MARK: Internal implementations.

  /// Internal implementation of overrideCandidate, with an optional key.
  /// - Parameters:
  ///   - key: Key.
  ///   - location: Cursor location.
  ///   - value: Value.
  ///   - type: Override type.
  /// - Returns: Whether operation performed successfully.
  internal func overrideCandidateAgainst(key: String?, at location: Int, value: String, type: Node.OverrideType)
    -> Bool
  {
    guard location <= keys.count else { return false }
    var arrOverlappedNodes: [NodeInSpan] = overlappingNodes(at: min(keys.count - 1, location))
    var overridden: NodeInSpan?
    for nis in arrOverlappedNodes {
      if let key = key, nis.node.key != key { continue }
      if nis.node.selectOverrideUnigram(value: value, type: type) {
        overridden = nis
        break
      }
    }

    guard let overridden = overridden else { return false }  // 啥也不覆寫。

    for i in overridden.spanIndex..<min(spans.count, overridden.spanIndex + overridden.node.spanLength) {
      // We also need to reset *all* nodes that share the same location in the
      // span. For example, if previously the two walked nodes are "A BC" where
      // A and BC are two nodes with overrides. The user now chooses "DEF" which
      // is a node that shares the same span location with "A". The node with BC
      // will be reset as it's part of the overlapping node, but A is not.
      arrOverlappedNodes = overlappingNodes(at: i)
      for nis in arrOverlappedNodes {
        if nis.node == overridden.node { continue }
        nis.node.reset()
      }
    }
    return true
  }
}

// MARK: - Stable Sort Extension

// Reference: https://stackoverflow.com/a/50545761/4162914

extension Sequence {
  /// Return a stable-sorted collection.
  ///
  /// - Parameter areInIncreasingOrder: Return nil when two element are equal.
  /// - Returns: The sorted collection.
  fileprivate func stableSorted(
    by areInIncreasingOrder: (Element, Element) throws -> Bool
  )
    rethrows -> [Element]
  {
    try enumerated()
      .sorted { a, b -> Bool in
        try areInIncreasingOrder(a.element, b.element)
          || (a.offset < b.offset && !areInIncreasingOrder(b.element, a.element))
      }
      .map(\.element)
  }
}

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
  /// A span is a collection of nodes that share the same starting location.
  public class Span {
    private var nodes: [Node?] = []
    private(set) var maxLength = 0
    private var maxSpanLength: Int { Megrez.Compositor.maxSpanLength }
    public init() {
      clear()
    }

    public func clear() {
      nodes.removeAll()
      for _ in 0..<maxSpanLength {
        nodes.append(nil)
      }
      maxLength = 0
    }

    /// Add a node to this span.
    /// - Parameter node: The node to add.
    /// - Returns: Whether the process is successful.
    @discardableResult public func append(node: Node) -> Bool {
      guard (1...maxSpanLength).contains(node.spanLength) else {
        return false
      }
      nodes[node.spanLength - 1] = node
      maxLength = max(maxLength, node.spanLength)
      return true
    }

    /// Drop nodes of given length or beyong the given length.
    /// - Parameter length: Given length.
    /// - Returns: Whether the process is successful.
    @discardableResult public func dropNodesOfOrBeyond(length: Int) -> Bool {
      guard (1...maxSpanLength).contains(length) else {
        return false
      }
      for i in length...maxSpanLength {
        nodes[i - 1] = nil
      }
      maxLength = 0
      guard length > 1 else { return false }
      let maxR = length - 2
      for i in 0...maxR {
        if nodes[maxR - i] != nil {
          maxLength = maxR - i + 1
          break
        }
      }
      return true
    }

    public func nodeOf(length: Int) -> Node? {
      guard (1...maxSpanLength).contains(length) else { return nil }
      return nodes[length - 1] ?? nil
    }
  }

  // MARK: Internal implementations.

  struct NodeInSpan {
    let node: Megrez.Compositor.Node
    let spanIndex: Int
    var spanLength: Int { node.spanLength }
    var unigrams: [Megrez.Unigram] { node.unigrams }
    var key: String { node.key }
    var mass: Double = 0.0
  }

  /// Find all nodes that overlap with the location. The return value is a list
  /// of nodes along with their starting location in the grid.
  /// - Parameter location: Cursor Location.
  /// - Returns: An array of NodeInSpan containing overlappingNodes.
  func overlappingNodes(at location: Int) -> [NodeInSpan] {
    var results = [NodeInSpan]()
    guard !spans.isEmpty, location < spans.count else { return results }

    // 先獲取該位置的幅位當中的所有節點。
    for theLocation in 1...spans[location].maxLength {
      guard let node = spans[location].nodeOf(length: theLocation) else { continue }
      results.append(.init(node: node, spanIndex: location))
    }

    // 再獲取其他節點。
    let begin: Int = location - min(location, Megrez.Compositor.maxSpanLength - 1)
    for theLocation in begin..<location {
      let (A, B): (Int, Int) = {
        (
          min(location - theLocation + 1, spans[theLocation].maxLength),
          max(location - theLocation + 1, spans[theLocation].maxLength)
        )
      }()
      for theLength in A...B {
        guard let node = spans[theLocation].nodeOf(length: theLength) else { continue }
        results.append(.init(node: node, spanIndex: theLocation))
      }
    }
    return results
  }
}

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
  public struct WalkResult {
    var nodes: [Node]
    var vertices: Int
    var edges: Int
    var values: [String] {
      nodes.map(\.value)
    }

    var keys: [String] {
      nodes.map(\.key)
    }
  }

  /// Find the weightiest path in the grid graph. The path represents the most
  /// likely hidden chain of events from the observations. We use the
  /// DAG-SHORTEST-PATHS algorithm in Cormen et al. 2001 to compute such path.
  /// Instead of computing the path with the shortest distance, though, we compute
  /// the path with the longest distance (so the weightiest), since with log
  /// probability a larger value means a larger probability. The algorithm runs in
  /// O(|V| + |E|) time for G = (V, E) where G is a DAG. This means the walk is
  /// fairly economical even when the grid is large.
  /// - Returns: Walked Result & whether the process is successful.
  public func walk() -> (WalkResult, Bool) {
    var result = WalkResult(nodes: .init(), vertices: 0, edges: 0)
    guard !spans.isEmpty else { return (result, true) }

    var vertexSpans = [[Vertex]]()
    for _ in spans {
      vertexSpans.append(.init())
    }

    for (i, span) in spans.enumerated() {
      for j in 1...span.maxLength {
        if let p = span.nodeOf(length: j) {
          vertexSpans[i].append(.init(node: p))
          result.vertices += 1
        }
      }
    }

    let terminal = Vertex(node: .init(key: "_TERMINAL_", spanLength: 0, unigrams: .init()))

    for (i, vertexSpan) in vertexSpans.enumerated() {
      for vertex in vertexSpan {
        let nextVertexPosition = i + vertex.node.spanLength
        if nextVertexPosition == vertexSpans.count {
          vertex.edges.append(terminal)
          continue
        }
        for nextVertex in vertexSpans[nextVertexPosition] {
          vertex.edges.append(nextVertex)
          result.edges += 1
        }
      }
    }

    let root = Vertex(node: .init(key: "_ROOT_", spanLength: 0, unigrams: .init()))
    root.distance = 0
    root.edges.append(contentsOf: vertexSpans[0])

    var ordered: [Vertex] = topologicalSort(root: root)
    for (j, neta) in ordered.enumerated() {
      for (k, _) in neta.edges.enumerated() {
        relax(u: neta, v: &neta.edges[k])
      }
      ordered[j] = neta
    }

    var walked = [Node]()
    var totalKeyLength = 0
    while totalKeyLength < keys.count + 2, let node = ordered.reversed()[totalKeyLength].edges.last?.node {
      if !node.value.isEmpty {
        walked.append(node)
      }
      let oldTotalKeyLength = totalKeyLength
      totalKeyLength += node.spanLength
      if oldTotalKeyLength == totalKeyLength { break }
    }

    guard totalKeyLength == keys.count else {
      print("!!! ERROR A")
      return (result, false)
    }
    result.nodes = Array(walked)
    return (result, true)
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

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
  /// Defines a vertex of a DAG. This is a mutable data structure used for both
  /// DAG construction and single-source shortest-path computation.
  class Vertex {
    public var prev: Vertex?
    public var edges = [Vertex]()
    /// Used during shortest-path computation. We are actually computing the
    /// path with the *largest* weight, hence distance's initial value being
    /// negative infinity. If we were to compute the *shortest* weight/distance,
    /// we would have initialized this to infinity.
    public var distance = -(Double.infinity)
    /// Used during topological-sort.
    public var topologicallySorted = false
    public var node: Node
    public init(node: Node) {
      self.node = node
    }
  }

  /// Cormen et al. 2001 explains the historical origin of the term "relax."
  func relax(u: Vertex, v: inout Vertex) {
    // The distance from u to w is simply v's score.
    let w: Double = v.node.score
    // Since we are computing the largest weight, we update v's distance and prev
    // if the current distance to v is *less* than that of u's plus the distance
    // to v (which is represented by w).
    if v.distance < u.distance + w {
      v.distance = u.distance + w
      v.prev = u
    }
  }

  /// Topological-sorts a DAG that has a single root and returns the vertices in
  /// topological order.
  ///
  /// Here, a non-recursive version is implemented using our own
  /// stack and state definitions, so that we are not constrained by the current
  /// thread's stack size. The following is the equivalent:
  /// ```
  ///  func topologicalSort(Vertex* vertex) {
  ///    for vertexNode in vertex.edges {
  ///      if !vertexNode.topologicallySorted {
  ///        dfs(vertexNode, result)
  ///      }
  ///    }
  ///    v.topologicallySorted = true
  ///    result.append(v)
  ///  }
  /// ```
  /// The recursive version is similar to the TOPOLOGICAL-SORT algorithm found in
  /// Cormen et al. 2001.
  /// - Parameter root: Root vertex.
  func topologicalSort(root: Vertex) -> [Vertex] {
    var result: [Vertex] = []
    struct State {
      var edgeIter: Int
      var edgeItered: Vertex { vertex.edges[edgeIter] }
      var vertex: Vertex
      init(vertex: Vertex) {
        self.vertex = vertex
        edgeIter = 0
      }
    }
    var stack: [State] = [.init(vertex: root)]

    while var state = stack.last {
      if state.edgeIter != state.vertex.edges.count {
        let nextVertex = state.edgeItered
        state.edgeIter += 1
        if !nextVertex.topologicallySorted {
          stack.append(.init(vertex: nextVertex))
          continue
        }
      }
      state.vertex.topologicallySorted = true
      result.append(state.vertex)
      stack.removeLast()
    }
    return result
  }
}

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

// NOTE: This file is optional. Its internal functions are not enabled yet and need to be fixed.

extension Megrez {
  /// 一個「有向無環圖的」的頂點單位。
  ///
  /// 這是一個可變的數據結構，用於有向無環圖的構建和單源最短路徑的計算。
  class Vertex {
    /// 前述頂點。
    public var prev: Vertex?
    /// 自身屬下的頂點陣列。
    public var edges = [Vertex]()
    /// 該變數用於最短路徑的計算。
    ///
    /// 我們實際上是在計算具有最大權重的路徑，因此距離的初始值是負無窮的。
    /// 如果我們要計算最短的權重/距離，我們會將其初期值設為正無窮。
    public var distance = -(Double.infinity)
    /// 在進行進行位相幾何排序時會用到的狀態標記。
    public var topologicallySorted = false
    public var node: Node
    public init(node: Node) {
      self.node = node
    }

    /// 卸勁函式。
    ///
    /// 「卸勁 (relax)」一詞出自 Cormen 在 2001 年的著作「Introduction to Algorithms」的 585 頁。
    /// - Parameters:
    ///   - u: 參照頂點，會在必要時成為 v 的前述頂點。
    ///   - v: 要影響的頂點。
    static func relax(u: Vertex, v: inout Vertex) {
      /// 從 u 到 w 的距離，也就是 v 的權重。
      let w: Double = v.node.score
      /// 這裡計算最大權重：
      /// 如果 v 目前的距離值小於「u 的距離值＋w（w 是 u 到 w 的距離，也就是 v 的權重）」，
      /// 我們就更新 v 的距離及其前述頂點。
      if v.distance < u.distance + w {
        v.distance = u.distance + w
        v.prev = u
      }
    }

    /// 對持有單個根頂點的有向無環圖進行位相幾何排序（topological
    /// sort）、且將排序結果以頂點陣列的形式給出。
    ///
    /// 這裡使用我們自己的堆棧和狀態定義實現了一個非遞迴版本，
    /// 這樣我們就不會受到當前線程的堆棧大小的限制。以下是等價的原始算法。
    /// ```
    ///  func topologicalSort(vertex: Vertex) {
    ///    for vertexNode in vertex.edges {
    ///      if !vertexNode.topologicallySorted {
    ///        dfs(vertexNode, result)
    ///        vertexNode.topologicallySorted = true
    ///      }
    ///      result.append(vertexNode)
    ///    }
    ///  }
    /// ```
    /// 至於遞迴版本則類似於 Cormen 在 2001 年的著作「Introduction to Algorithms」當中的樣子。
    /// - Parameter root: 根頂點。
    /// - Returns: 排序結果（頂點陣列）。
    static func topologicalSort(root: Vertex) -> [Vertex] {
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
}

// MARK: - Fast Walker

extension Megrez.Compositor {
  /// 爬軌結果。
  public struct WalkResult {
    var nodes: [Megrez.Node]
    var vertices: Int
    var edges: Int
    var values: [String] {
      nodes.map(\.currentPair.value)
    }

    var keys: [String] {
      nodes.map(\.currentPair.key)
    }
  }

  /// 對已給定的軌格，使用頂點算法，按照給定的位置與條件進行正向爬軌。
  ///
  /// ⚠︎ 該方法有已知問題，會無視 fixNodeWithCandidate() 的前置操作效果。
  /// - Returns: 一個包含有效結果的節錨陣列。
  @discardableResult public func fastWalk() -> [Megrez.NodeAnchor] {
    vertexWalk()
    updateCursorJumpingTables(walkedAnchors)
    return walkedAnchors
  }

  /// 找到軌格陣圖內權重最大的路徑。該路徑代表了可被觀測到的最可能的隱藏事件鏈。
  /// 這裡使用 Cormen 在 2001 年出版的教材當中提出的「有向無環圖的最短路徑」的
  /// 算法來計算這種路徑。不過，這裡不是要計算距離最短的路徑，而是計算距離最長
  /// 的路徑（所以要找最大的權重），因為在對數概率下，較大的數值意味著較大的概率。
  /// 對於 `G = (V, E)`，該算法的運行次數為 `O(|V|+|E|)`，其中 `G` 是一個有向無環圖。
  /// 這意味著，即使軌格很大，也可以用很少的算力就可以爬軌。
  /// - Returns: 爬軌結果＋該過程是否順利執行。
  @discardableResult internal func vertexWalk() -> (WalkResult, Bool) {
    var result = WalkResult(nodes: .init(), vertices: 0, edges: 0)
    guard !spans.isEmpty else {
      updateWalkedAnchors(with: .init())
      return (result, true)
    }

    var vertexSpans = [[Megrez.Vertex]]()
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

    let terminal = Megrez.Vertex(node: .init(key: "_TERMINAL_"))

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

    let root = Megrez.Vertex(node: .init(key: "_ROOT_"))
    root.distance = 0
    root.edges.append(contentsOf: vertexSpans[0])

    var ordered: [Megrez.Vertex] = Megrez.Vertex.topologicalSort(root: root)

    for (j, neta) in ordered.enumerated() {
      for (k, _) in ordered[j].edges.enumerated() {
        Megrez.Vertex.relax(u: ordered[j], v: &ordered[j].edges[k])
      }
      ordered[j] = neta
    }

    // 接下來這段處理可能有問題需要修正。
    var walked = [Megrez.Node]()
    var totalReadingLength = 0
    while totalReadingLength < readings.count + 2, let lastEdge = ordered.reversed()[totalReadingLength].edges.last {
      if let vertexPrev = lastEdge.prev, !vertexPrev.node.currentPair.value.isEmpty {
        walked.append(vertexPrev.node)
      } else if !lastEdge.node.currentPair.value.isEmpty {
        walked.append(lastEdge.node)
      }
      let oldTotalReadingLength = totalReadingLength
      totalReadingLength += lastEdge.node.spanLength
      if oldTotalReadingLength == totalReadingLength { break }
    }

    guard totalReadingLength == readings.count else {
      print("!!! ERROR A: readingLength: \(totalReadingLength), readingCount: \(readings.count)")
      updateWalkedAnchors(with: .init())
      return (result, false)
    }

    result.nodes = Array(walked)
    updateWalkedAnchors(with: result.nodes)
    return (result, true)
  }
}

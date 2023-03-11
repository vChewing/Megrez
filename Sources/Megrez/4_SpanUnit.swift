// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

public extension Megrez {
  /// 幅位乃指一組共享起點的節點。其實是個辭典：[幅位長度: 節點]。
  typealias SpanUnit = [Int: Node]
}

public extension Megrez.SpanUnit {
  /// 幅位乃指一組共享起點的節點。其實是個辭典：[幅位長度: 節點]。
  /// - Remark: 因為 Node 不是 Struct，所以會在 Compositor 被拷貝的時候無法被真實複製。
  /// 這樣一來，Compositor 複製品當中的 Node 的變化會被反應到原先的 Compositor 身上。
  /// 這在某些情況下會造成意料之外的混亂情況，所以需要引入一個拷貝用的建構子。
  init(SpanUnit target: Megrez.SpanUnit) {
    self.init()
    target.forEach { theKey, theValue in
      self[theKey] = theValue.copy
    }
  }

  /// 該幅位的硬拷貝。
  var hardCopy: Megrez.SpanUnit { .init(SpanUnit: self) }

  // MARK: - Dynamic Variables

  /// 該幅位單元內的所有節點當中持有最長幅位的節點長度。
  /// 該變數受該幅位的自身操作函式而被動更新。
  var maxLength: Int { keys.max() ?? 0 }

  /// （該變數為捷徑，代傳 Megrez.Compositor.maxSpanLength。）
  private var maxSpanLength: Int { Megrez.Compositor.maxSpanLength }
  /// 該幅位單元內的節點的幅位長度上限。
  private var allowedLengths: ClosedRange<Int> { 1 ... maxSpanLength }

  // MARK: - Functions

  /// 往該幅位塞入一個節點。
  /// - Remark: 這個函式用來防呆。一般情況下用不到。
  /// - Parameter node: 要塞入的節點。
  /// - Returns: 該操作是否成功執行。
  @discardableResult mutating func addNode(node: Megrez.Node) -> Bool {
    guard allowedLengths.contains(node.spanLength) else { return false }
    self[node.spanLength] = node
    return true
  }

  /// 丟掉任何不小於給定幅位長度的節點。
  /// - Remark: 這個函式用來防呆。一般情況下用不到。
  /// - Parameter length: 給定的幅位長度。
  /// - Returns: 該操作是否成功執行。
  @discardableResult mutating func dropNodesOfOrBeyond(length: Int) -> Bool {
    guard allowedLengths.contains(length) else { return false }
    let length = Swift.min(length, maxSpanLength)
    (length ... maxSpanLength).forEach { self[$0] = nil }
    return true
  }
}

// MARK: - Related Compositor Implementations.

extension Megrez.Compositor {
  /// 找出所有與該位置重疊的節點。其返回值為一個節錨陣列（包含節點、以及其起始位置）。
  /// - Parameters:
  ///   - givenLocation: 游標位置。
  ///   - filter: 指定內容保留類型（是在游標前方還是在後方、還是包含交叉節點在內的全部結果）。
  /// - Returns: 一個包含所有與該位置重疊的節點的陣列。
  func fetchOverlappingNodes(at givenLocation: Int, filter: CandidateFetchFilter = .all) -> [NodeAnchor] {
    var resultsOfSingleAt = Set<NodeAnchor>()
    var resultsBeginAt = Set<NodeAnchor>()
    var resultsEndAt = Set<NodeAnchor>()
    var resultsCrossingAt = Set<NodeAnchor>()
    guard !spans.isEmpty, (0 ..< spans.count).contains(givenLocation) else { return [] }
    (1 ... max(spans[givenLocation].maxLength, 1)).forEach { theSpanLength in
      guard let node = spans[givenLocation][theSpanLength] else { return }
      guard !node.keyArray.isEmpty, !node.keyArray.joined().isEmpty else { return }
      if node.spanLength == 1 {
        resultsOfSingleAt.insert(.init(node: node, spanIndex: givenLocation))
      } else {
        resultsBeginAt.insert(.init(node: node, spanIndex: givenLocation))
      }
    }
    let begin: Int = givenLocation - min(givenLocation, Megrez.Compositor.maxSpanLength - 1)
    (begin ..< givenLocation).forEach { theLocation in
      let (A, B): (Int, Int) = (givenLocation - theLocation + 1, spans[theLocation].maxLength)
      guard A <= B else { return }
      (A ... B).forEach { theLength in
        let isEndAt: Bool = theLength <= givenLocation - begin
        guard let node = spans[theLocation][theLength] else { return }
        guard !node.keyArray.isEmpty, !node.keyArray.joined().isEmpty else { return }
        let theAnchor = NodeAnchor(node: node, spanIndex: theLocation + 1)
        if resultsOfSingleAt.contains(theAnchor) || resultsBeginAt.contains(theAnchor) { return }
        if isEndAt {
          resultsEndAt.insert(theAnchor)
        } else {
          // 有 NodeCrossing 的節點是用來給權重覆寫函式專門使用的，平時得過濾掉。
          resultsCrossingAt.insert(theAnchor)
        }
      }
    }
    switch filter {
    case .beginAt: return Array(resultsOfSingleAt.union(resultsBeginAt))
    case .endAt: return Array(resultsOfSingleAt.union(resultsEndAt))
    default: return Array(resultsOfSingleAt.union(resultsEndAt).union(resultsBeginAt).union(resultsCrossingAt))
    }
  }
}

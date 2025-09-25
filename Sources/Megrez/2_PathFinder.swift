// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

extension Megrez.Compositor {
  /// 文字組句處理函式，採用 Dijkstra 路徑搜尋演算法更新當前組字器的 assembledNodes 結果。
  ///
  /// 此演算法在有向圖結構中搜尋具有最優評分的路徑，從而確定最合適的詞彙組合。
  ///
  /// 演算法所依賴的 HybridPriorityQueue 資料結構經過針對 Sandy Bridge 架構的特殊最佳化處理，
  /// 使得該演算法在 Sandy Bridge CPU 平台上相較於 DAG 演算法具備更優異的執行效能。
  ///
  /// - Returns: 組句處理結果（已選定詞彙的節點陣列）。
  @discardableResult
  public func assemble() -> [Megrez.Node] {
    Megrez.PathFinder(config: config, assembledNodes: &assembledNodes)
    return assembledNodes
  }
}

// MARK: - Megrez.PathFinder

extension Megrez {
  final class PathFinder {
    // MARK: Lifecycle

    /// 組句工具，會以 Dijkstra 演算法更新當前組字器的 assembledNodes。
    ///
    /// 該演算法會在圖中尋找具有最高分數的路徑，即最可能的字詞組合。
    ///
    /// 該演算法所依賴的 HybridPriorityQueue 針對 Sandy Bridge 經過最佳化處理，
    /// 使得該演算法在 Sandy Bridge CPU 的電腦上比 DAG 演算法擁有更優的效能。
    @discardableResult
    init(config: CompositorConfig, assembledNodes: inout [Megrez.Node]) {
      var newAssembledNodes = [Megrez.Node]()
      defer { assembledNodes = newAssembledNodes }
      guard !config.segments.isEmpty else { return }

      // 初期化資料結構。
      var openSet = HybridPriorityQueue<PrioritizedState>(reversed: true)
      var visited = Set<SearchState>()
      // 使用 ContiguousArray 提升快取效能並預配置合理容量
      var bestScore = ContiguousArray<Double>(
        repeating: Double(Int32.min),
        count: config.keys.count + 1
      )

      var stateCleaningTasks: [() -> ()] = []
      defer {
        // 確保所有資料結構都被清理
        stateCleaningTasks.forEach { $0() }
        stateCleaningTasks.removeAll()
        visited.removeAll()
        bestScore.removeAll()
      }

      // 初期化起始狀態。
      let leadingNode = Megrez.Node(keyArray: ["$LEADING"])
      let start = SearchState(
        node: leadingNode,
        position: 0,
        prev: nil,
        distance: 0,
        cleaningTaskRegister: &stateCleaningTasks,
        pathFinder: self
      )
      openSet.enqueue(PrioritizedState(state: start))
      if !bestScore.isEmpty {
        bestScore[0] = 0
      }

      // 追蹤最佳結果。
      var bestFinalState: SearchState?
      var bestFinalScore = Double(Int32.min)

      // 主要 Dijkstra 迴圈。
      while !openSet.isEmpty {
        guard let current = openSet.dequeue()?.state else { break }
        stateCleaningTasks.append(current.cleanChainRecursively)

        // 如果已經造訪過具有更好分數的狀態，則跳過。
        if visited.contains(current) { continue }
        visited.insert(current)

        // 檢查是否已到達終點。
        if current.position >= config.keys.count {
          if current.distance > bestFinalScore {
            bestFinalScore = current.distance
            bestFinalState = current
          }
          continue
        }

        // 處理下一個可能的節點。
        for (length, nextNode) in config.segments[current.position] {
          // 早期無效性檢查：確保節點有有效的單元圖
          guard !nextNode.unigrams.isEmpty else { continue }

          let nextPos = current.position + length

          // 計算新的權重分數。
          let newScore = current.distance + nextNode.score

          // 如果該位置已有更優的權重分數，則跳過。
          guard nextPos < bestScore.count, bestScore[nextPos] < newScore else { continue }

          let nextState = SearchState(
            node: nextNode,
            position: nextPos,
            prev: current,
            distance: newScore,
            cleaningTaskRegister: &stateCleaningTasks,
            pathFinder: self
          )

          if nextPos < bestScore.count {
            bestScore[nextPos] = newScore
          }
          openSet.enqueue(PrioritizedState(state: nextState))
        }
      }

      // 從最佳終止狀態重建路徑。
      guard let finalState = bestFinalState else {
        return
      }

      var pathNodes: [Megrez.Node] = []
      pathNodes.reserveCapacity(config.keys.count) // 預配置合理容量
      var current: SearchState? = finalState

      while let state = current {
        defer {
          state.prev = nil
          state.node = nil
        }
        // 排除起始和結束的虛擬節點。
        if let stateNode = state.node, stateNode !== leadingNode {
          pathNodes.insert(stateNode, at: 0)
        }
        current = state.prev
        // 備註：此處不需要手動 ASAN，因為沒有參據循環（Retain Cycle）。
      }

      // 清理路徑重建過程中的臨時陣列
      newAssembledNodes = pathNodes.map(\.copy)
      pathNodes.removeAll()
    }

    deinit {
      #if DEBUG
        if searchStateCreatedCount != searchStateDestroyedCount {
          print(
            "PathFinder 記憶體洩漏檢測: 建立了 \(searchStateCreatedCount) 個 SearchState，但只析構了 \(searchStateDestroyedCount) 個"
          )
        }
      #endif
    }

    // MARK: Private

    // MARK: - SearchState 記憶體追蹤

    private var searchStateCreatedCount: Int = 0
    private var searchStateDestroyedCount: Int = 0
  }
}

// MARK: - 搜尋狀態相關定義

extension Megrez.PathFinder {
  /// 用於追蹤搜尋過程中的狀態。
  /// - Note: 採用弱引用設計以最佳化記憶體使用。
  private final class SearchState: Hashable {
    // MARK: Lifecycle

    /// 初期化搜尋狀態。
    /// - Parameters:
    ///   - node: 當前節點。
    ///   - position: 在輸入串中的位置。
    ///   - prev: 前一個狀態。
    ///   - distance: 到達此狀態的累計分數。
    ///   - cleaningTaskRegister: 登記自毀任務池。
    ///   - pathFinder: PathFinder 實例，用於更新計數器。
    init(
      node: Megrez.Node?,
      position: Int,
      prev: SearchState?,
      distance: Double = Double(Int.min),
      cleaningTaskRegister: inout [() -> ()],
      pathFinder: Megrez.PathFinder
    ) {
      self.node = node
      self.position = position
      self.prev = prev
      self.distance = distance
      self.pathFinder = pathFinder
      // 使用不可變的標識符來確保 hash 一致性
      self.originalNodeRef = node
      self.stableHash = Self.computeStableHash(node: node, position: position)
      cleaningTaskRegister.append(cleanChainRecursively)
      // 更新建立計數器
      pathFinder.searchStateCreatedCount += 1
      #if DEBUG
        // 移除個別的建立訊息
      #endif
    }

    deinit {
      // 更新析構計數器
      pathFinder?.searchStateDestroyedCount += 1
      node = nil
      prev = nil
      pathFinder = nil
      #if DEBUG
        // 移除個別的析構訊息
      #endif
    }

    // MARK: Internal

    weak var node: Megrez.Node? // 當前節點（可變，用於清理）
    let position: Int // 在輸入串中的位置
    weak var prev: SearchState? // 前一個狀態
    var distance: Double // 累計分數
    weak var pathFinder: Megrez.PathFinder? // PathFinder 弱引用

    // MARK: - Hashable 協定實作

    static func == (lhs: SearchState, rhs: SearchState) -> Bool {
      lhs.originalNodeRef === rhs.originalNodeRef && lhs.position == rhs.position
    }

    /// 清理整個 SearchState 鏈條，從當前節點開始向後遞歸清理
    /// 採用深度優先遍歷策略，確保每個節點都被清理
    func cleanChainRecursively() {
      var visited = Set<ObjectIdentifier>()
      var stack: [SearchState] = []
      stack.append(self)

      while !stack.isEmpty {
        let current = stack.removeLast()
        let currentId = ObjectIdentifier(current)

        // 避免重複清理和無限循環
        guard !visited.contains(currentId) else { continue }
        visited.insert(currentId)

        // 在清理前，將 prev 加入堆疊（如果存在）
        if let prevState = current.prev {
          stack.append(prevState)
        }

        // 清理當前節點
        current.node = nil
        current.prev?.cleanChainRecursively()
        current.prev = nil
      }
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(stableHash)
    }

    // MARK: Private

    // 用於穩定 hash 計算的不可變參據
    private weak var originalNodeRef: Megrez.Node? // 原始節點參據（不可變，弱引用）
    private let stableHash: Int // 預計算的穩定 hash 值

    private static func computeStableHash(node: Megrez.Node?, position: Int) -> Int {
      var hasher = Hasher()
      if let node = node {
        hasher.combine(ObjectIdentifier(node))
      } else {
        hasher.combine(0) // 為 nil 節點使用固定值
      }
      hasher.combine(position)
      return hasher.finalize()
    }
  }

  /// 用於優先序列的狀態包裝結構
  private struct PrioritizedState: Comparable {
    let state: SearchState

    // MARK: - Comparable 協定實作

    static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.state.distance < rhs.state.distance
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.state == rhs.state
    }
  }
}

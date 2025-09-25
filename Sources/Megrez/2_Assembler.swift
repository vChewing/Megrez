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
    assembledNodes.removeAll()
    guard !segments.isEmpty else { return [] }

    // 初期化資料結構。
    var openSet = HybridPriorityQueue<PrioritizedState>(reversed: true)
    var visited = Set<SearchState>()
    var bestScore = [Int: Double]() // 追蹤每個位置的最佳分數

    // 初期化起始狀態。
    let leadingNode = Megrez.Node(keyArray: ["$LEADING"])
    let start = SearchState(
      node: leadingNode,
      position: 0,
      prev: nil,
      distance: 0
    )
    openSet.enqueue(PrioritizedState(state: start))
    bestScore[0] = 0

    // 追蹤最佳結果。
    var bestFinalState: SearchState?
    var bestFinalScore = Double(Int32.min)

    // 主要 Dijkstra 迴圈。
    while !openSet.isEmpty {
      guard let current = openSet.dequeue()?.state else { break }

      // 如果已經造訪過具有更好分數的狀態，則跳過。
      if visited.contains(current) { continue }
      visited.insert(current)

      // 檢查是否已到達終點。
      if current.position >= keys.count {
        if current.distance > bestFinalScore {
          bestFinalScore = current.distance
          bestFinalState = current
        }
        continue
      }

      // 處理下一個可能的節點。
      for (length, nextNode) in segments[current.position] {
        let nextPos = current.position + length

        // 計算新的權重分數。
        let newScore = current.distance + nextNode.score

        // 如果該位置已有更優的權重分數，則跳過。
        guard (bestScore[nextPos] ?? .init(Int32.min)) < newScore else { continue }

        let nextState = SearchState(
          node: nextNode,
          position: nextPos,
          prev: current,
          distance: newScore
        )

        bestScore[nextPos] = newScore
        openSet.enqueue(PrioritizedState(state: nextState))
      }

      // 即時記憶體最佳化：當 visited 集合過大時進行部分清理
      if visited.count > 1_000 { // 可調整的閾值
        Self.partialCleanVisitedStates(visited: &visited, keepRecentCount: 500)
      }
    }

    // 從最佳終止狀態重建路徑。
    guard let finalState = bestFinalState else {
      // 即使沒有找到最佳狀態，也需要清理所有建立的 SearchState 物件
      Self.batchCleanAllSearchStates(
        visited: visited,
        openSet: &openSet,
        leadingState: start
      )
      return []
    }

    var pathNodes: [Megrez.Node] = []
    var current: SearchState? = finalState

    while let state = current {
      // 排除起始和結束的虛擬節點。
      if let stateNode = state.node, stateNode !== leadingNode {
        pathNodes.insert(stateNode, at: 0)
      }
      current = state.prev
      // 備註：此處不需要手動 ASAN，因為沒有參據循環（Retain Cycle）。
    }
    assembledNodes = pathNodes.map(\.copy)

    // 手動 ASAN：批次清理所有 SearchState 物件以防止記憶體洩漏
    // 包括 visited set 中的所有狀態、openSet 中剩餘的狀態，以及 leadingState
    Self.batchCleanAllSearchStates(
      visited: visited,
      openSet: &openSet,
      leadingState: start
    )
    return assembledNodes
  }

  /// 部分清理已訪問狀態集合以控制記憶體使用
  /// - Parameters:
  ///   - visited: 已訪問的狀態集合
  ///   - keepRecentCount: 要保留的最近狀態數量
  private static func partialCleanVisitedStates(
    visited: inout Set<SearchState>,
    keepRecentCount: Int
  ) {
    guard visited.count > keepRecentCount else { return }

    // 按距離排序，保留分數較高的狀態
    let sortedStates = visited.sorted { $0.distance > $1.distance }
    let statesToRemove = Array(sortedStates.dropFirst(keepRecentCount))

    // 先從 Set 中移除，再清理參據（避免 hash 不一致）
    for state in statesToRemove {
      visited.remove(state)
      state.node = nil
      state.prev = nil
    }
  }

  /// 即時清理策略：直接清理各個資料結構，避免額外的 Set 集合
  /// - Parameters:
  ///   - visited: 已訪問的狀態集合
  ///   - openSet: 優先序列中剩餘的狀態
  ///   - leadingState: 初始狀態
  private static func batchCleanAllSearchStates(
    visited: Set<SearchState>,
    openSet: inout HybridPriorityQueue<PrioritizedState>,
    leadingState: SearchState
  ) {
    // 策略1: 直接清理 visited set 中的所有狀態
    for state in visited {
      state.node = nil
      state.prev = nil
    }

    // 策略2: 直接清理 openSet 中剩餘的所有狀態
    while !openSet.isEmpty {
      if let prioritizedState = openSet.dequeue() {
        prioritizedState.state.node = nil
        prioritizedState.state.prev = nil
      }
    }

    // 策略3: 清理 leadingState
    leadingState.node = nil
    leadingState.prev = nil
  }
}

// MARK: - 搜尋狀態相關定義

extension Megrez.Compositor {
  /// 用於追蹤搜尋過程中的狀態。
  private final class SearchState: Hashable {
    // MARK: Lifecycle

    /// 初期化搜尋狀態。
    /// - Parameters:
    ///   - node: 當前節點。
    ///   - position: 在輸入串中的位置。
    ///   - prev: 前一個狀態。
    ///   - distance: 到達此狀態的累計分數。
    init(
      node: Megrez.Node?,
      position: Int,
      prev: SearchState?,
      distance: Double = Double(Int.min)
    ) {
      self.node = node
      self.position = position
      self.prev = prev
      self.distance = distance
      // 使用不可變的標識符來確保 hash 一致性
      self.originalNodeRef = node
      self.stableHash = Self.computeStableHash(node: node, position: position)
    }

    // MARK: Internal

    var node: Megrez.Node? // 當前節點（可變，用於清理）
    let position: Int // 在輸入串中的位置
    var prev: SearchState? // 前一個狀態
    var distance: Double // 累計分數

    // MARK: - Hashable 協定實作

    static func == (lhs: SearchState, rhs: SearchState) -> Bool {
      lhs.originalNodeRef === rhs.originalNodeRef && lhs.position == rhs.position
    }

    /// 清理單一 SearchState 的參據
    /// 注意：由於新的清理策略是直接清理各個集合，這個方法現在主要用於向下相容
    func cleanState() {
      node = nil
      prev = nil
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(stableHash)
    }

    // MARK: Private

    // 用於穩定 hash 計算的不可變參據
    private let originalNodeRef: Megrez.Node? // 原始節點參據（不可變）
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

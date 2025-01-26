// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Foundation
import Megrez

// MARK: - Megrez Extensions for Test Purposes Only.

extension Megrez.Compositor {
  /// 返回在當前位置的所有候選字詞（以詞音配對的形式）。如果組字器內有幅位、且游標
  /// 位於組字器的（文字輸入順序的）最前方（也就是游標位置的數值是最大合規數值）的
  /// 話，那麼這裡會用到 location - 1、以免去在呼叫該函式後再處理的麻煩。
  /// - Remark: 該函式已被淘汰，因為有「無法徹底清除 node-crossing 內容」的故障。
  /// 現僅用於單元測試、以確認其繼任者是否有給出所有該給出的正常結果。
  /// - Parameter location: 游標位置。
  /// - Returns: 候選字音配對陣列。
  public func fetchCandidatesDeprecated(
    at location: Int,
    filter: CandidateFetchFilter = .all
  )
    -> [Megrez.KeyValuePaired] {
    var result = [Megrez.KeyValuePaired]()
    guard !keys.isEmpty else { return result }
    let location = max(min(location, keys.count - 1), 0) // 防呆
    let anchors: [(location: Int, node: Megrez.Node)] = fetchOverlappingNodes(at: location)
    let keyAtCursor = keys[location]
    anchors.map(\.node).forEach { theNode in
      theNode.unigrams.forEach { gram in
        switch filter {
        case .all:
          // 得加上這道篩選，不然會出現很多無效結果。
          if !theNode.keyArray.contains(keyAtCursor) { return }
        case .beginAt:
          if theNode.keyArray[0] != keyAtCursor { return }
        case .endAt:
          if theNode.keyArray.reversed()[0] != keyAtCursor { return }
        }
        result.append(.init(keyArray: theNode.keyArray, value: gram.value))
      }
    }
    return result
  }
}

// MARK: - ClassPtr

class ClassPtr<T: Any> {
  // MARK: Lifecycle

  init(obj: T) {
    self.obj = obj
  }

  // MARK: Internal

  var obj: T
}

extension Megrez.Compositor {
  var asPtr: ClassPtr<Self> { .init(obj: self) }
}

extension Megrez.CompositorConfig {
  public var encodedJSON: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    do {
      let encodedData = try encoder.encode(self)
      return String(data: encodedData, encoding: .utf8) ?? ""
    } catch {
      return ""
    }
  }

  public func encodedJSONThrowable() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    let encodedData = try encoder.encode(self)
    return String(data: encodedData, encoding: .utf8) ?? ""
  }
}

extension Megrez.Compositor {
  public var encodedJSON: String { config.encodedJSON }
}

extension ClassPtr<Megrez.Compositor> {
  // MARK: - Instance Properties

  /// 組字器設定。
  var config: Megrez.CompositorConfig { obj.config }
  /// 最近一次爬軌結果。
  var walkedNodes: [Megrez.Node] { obj.walkedNodes }
  /// 該組字器已經插入的的索引鍵，以陣列的形式存放。
  var keys: [String] { obj.keys }
  /// 該組字器的幅位單元陣列。
  var spans: [Megrez.SpanUnit] { obj.spans }
  /// 該組字器的敲字游標位置。
  var cursor: Int { get { obj.cursor } set { obj.cursor = newValue } }
  /// 該組字器的標記器（副游標）位置。
  var marker: Int { obj.marker }
  /// 多字讀音鍵當中用以分割漢字讀音的記號，預設為「-」。
  var separator: String { get { obj.separator } set { obj.separator = newValue } }
  /// 該組字器的長度，組字器內已經插入的單筆索引鍵的數量。
  var length: Int { obj.length }
  /// 組字器是否為空。
  var isEmpty: Bool { obj.isEmpty }
  /// 該組字器所使用的語言模型（被 LangModelRanked 所封裝）。
  var langModel: Megrez.Compositor.LangModelRanked { obj.langModel }
  /// 該組字器的硬拷貝。
  var hardCopiedPtr: ClassPtr<Megrez.Compositor> { obj.hardCopy.asPtr }
  /// 生成用以交給 GraphViz 診斷的資料檔案內容。
  var dumpDOT: String { obj.dumpDOT }

  // MARK: - Initialization

  /// 初期化一個組字器。
  convenience init(with langModel: LangModelProtocol, separator: String) {
    self.init(obj: Megrez.Compositor(with: langModel, separator: separator))
  }

  /// 以指定組字器生成拷貝。
  convenience init(from target: ClassPtr<Megrez.Compositor>) {
    self.init(obj: Megrez.Compositor(from: target.obj))
  }

  // MARK: - Instance Methods

  /// 重置包括游標在內的各項參數，且清空各種由組字器生成的內部資料。
  func clear() { obj.clear() }

  /// 在游標位置插入給定的索引鍵。
  @discardableResult
  func insertKey(_ key: String) -> Bool { obj.insertKey(key) }

  /// 朝著指定方向砍掉一個與游標相鄰的讀音。
  @discardableResult
  func dropKey(direction: Megrez.Compositor.TypingDirection) -> Bool { obj
    .dropKey(direction: direction)
  }

  /// 按幅位來前後移動游標。
  @discardableResult
  func jumpCursorBySpan(
    to direction: Megrez.Compositor.TypingDirection,
    isMarker: Bool = false
  )
    -> Bool {
    obj.jumpCursorBySpan(to: direction, isMarker: isMarker)
  }

  /// 根據當前狀況更新整個組字器的節點文脈。
  @discardableResult
  func update(updateExisting: Bool) -> Int {
    obj.update(updateExisting: updateExisting)
  }

  /// 爬軌函式，會更新當前組字器的 walkedNodes。
  @discardableResult
  func walk() -> [Megrez.Node] {
    obj.walk()
  }

  @discardableResult
  public func overrideCandidateLiteral(
    _ candidate: String,
    at location: Int, overrideType: Megrez.Node.OverrideType = .withHighScore
  )
    -> Bool {
    obj.overrideCandidateLiteral(candidate, at: location)
  }

  @discardableResult
  public func overrideCandidate(
    _ candidate: Megrez.KeyValuePaired, at location: Int,
    overrideType: Megrez.Node.OverrideType = .withHighScore
  )
    -> Bool {
    obj.overrideCandidate(candidate, at: location, overrideType: overrideType)
  }

  public func fetchCandidates(
    at givenLocation: Int? = nil, filter givenFilter: Megrez.Compositor.CandidateFetchFilter = .all
  )
    -> [Megrez.KeyValuePaired] {
    obj.fetchCandidates(at: givenLocation, filter: givenFilter)
  }

  public func fetchCandidatesDeprecated(
    at location: Int,
    filter: Megrez.Compositor.CandidateFetchFilter = .all
  )
    -> [Megrez.KeyValuePaired] {
    obj.fetchCandidatesDeprecated(at: location, filter: filter)
  }
}

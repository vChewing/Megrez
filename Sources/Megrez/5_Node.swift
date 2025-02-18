// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Megrez.Node

extension Megrez {
  /// 字詞節點。
  ///
  /// 一個節點由這些內容組成：幅位長度、索引鍵、以及一組單元圖。幅位長度就是指這個
  /// 節點在組字器內橫跨了多少個字長。組字器負責構築自身的節點。對於由多個漢字組成
  /// 的詞，組字器會將多個讀音索引鍵合併為一個讀音索引鍵、據此向語言模組請求對應的
  /// 單元圖結果陣列。舉例說，如果一個詞有兩個漢字組成的話，那麼讀音也是有兩個、其
  /// 索引鍵也是由兩個讀音組成的，那麼這個節點的幅位長度就是 2。
  public class Node: Equatable, Hashable, Codable {
    // MARK: Lifecycle

    /// 生成一個字詞節點。
    ///
    /// 一個節點由這些內容組成：幅位長度、索引鍵、以及一組單元圖。幅位長度就是指這個
    /// 節點在組字器內橫跨了多少個字長。組字器負責構築自身的節點。對於由多個漢字組成
    /// 的詞，組字器會將多個讀音索引鍵合併為一個讀音索引鍵、據此向語言模組請求對應的
    /// 單元圖結果陣列。舉例說，如果一個詞有兩個漢字組成的話，那麼讀音也是有兩個、其
    /// 索引鍵也是由兩個讀音組成的，那麼這個節點的幅位長度就是 2。
    /// - Parameters:
    ///   - keyArray: 給定索引鍵陣列，不得為空。
    ///   - spanLength: 給定幅位長度，一般情況下與給定索引鍵陣列內的索引鍵數量一致。
    ///   - unigrams: 給定單元圖陣列，不得為空。
    public init(keyArray: [String] = [], spanLength: Int = 0, unigrams: [Megrez.Unigram] = []) {
      self.keyArray = keyArray
      self.spanLength = max(spanLength, 0)
      self.unigrams = unigrams
      self.currentOverrideType = .withNoOverrides
    }

    /// 以指定字詞節點生成拷貝。
    /// - Remark: 因為 Node 不是 Struct，所以會在 Compositor 被拷貝的時候無法被真實複製。
    /// 這樣一來，Compositor 複製品當中的 Node 的變化會被反應到原先的 Compositor 身上。
    /// 這在某些情況下會造成意料之外的混亂情況，所以需要引入一個拷貝用的建構子。
    public init(node: Node) {
      self.overridingScore = node.overridingScore
      self.keyArray = node.keyArray
      self.spanLength = node.spanLength
      self.unigrams = node.unigrams
      self.currentOverrideType = node.currentOverrideType
      self.currentUnigramIndex = node.currentUnigramIndex
    }

    // MARK: Public

    /// 三種不同的針對一個節點的覆寫行為。
    /// - withNoOverrides: 無覆寫行為。
    /// - withTopUnigramScore: 使用指定的單元圖資料值來覆寫該節點，但卻使用
    /// 當前狀態下權重最高的單元圖的權重數值。打比方說，如果該節點內的單元圖陣列是
    ///  [("a", -114), ("b", -514), ("c", -1919)] 的話，指定該覆寫行為則會導致該節
    ///  點返回的結果為 ("c", -114)。該覆寫行為多用於諸如使用者半衰記憶模組的建議
    ///  行為。被覆寫的這個節點的狀態可能不會再被爬軌行為擅自改回。該覆寫行為無法
    ///  防止其它節點被爬軌函式所支配。這種情況下就需要用到 overridingScore。
    /// - withHighScore: 將該節點權重覆寫為 overridingScore，使其被爬軌函式所青睞。
    public enum OverrideType: Int, Codable {
      case withNoOverrides = 0
      case withTopUnigramScore = 1
      case withHighScore = 2
    }

    /// 一個用以覆寫權重的數值。該數值之高足以改變爬軌函式對該節點的讀取結果。這裡用
    /// 「0」可能看似足夠了，但仍會使得該節點的覆寫狀態有被爬軌函式忽視的可能。比方說
    /// 要針對索引鍵「a b c」複寫的資料值為「A B C」，使用大寫資料值來覆寫節點。這時，
    /// 如果這個獨立的 c 有一個可以拮抗權重的詞「bc」的話，可能就會導致爬軌函式的算法
    /// 找出「A->bc」的爬軌途徑（尤其是當 A 和 B 使用「0」作為複寫數值的情況下）。這樣
    /// 一來，「A-B」就不一定始終會是爬軌函式的青睞結果了。所以，這裡一定要用大於 0 的
    /// 數（比如野獸常數），以讓「c」更容易單獨被選中。
    public var overridingScore: Double = 114_514

    /// 索引鍵陣列。
    public private(set) var keyArray: [String]
    /// 幅位長度。
    public private(set) var spanLength: Int
    /// 單元圖陣列。
    public private(set) var unigrams: [Megrez.Unigram]
    /// 該節點目前的覆寫狀態種類。
    public private(set) var currentOverrideType: Node.OverrideType

    /// 當前該節點所指向的（單元圖陣列內的）單元圖索引位置。
    public private(set) var currentUnigramIndex: Int = 0 {
      didSet { currentUnigramIndex = max(min(unigrams.count - 1, currentUnigramIndex), 0) }
    }

    /// 該節點當前狀態所展示的鍵值配對。
    public var currentPair: Megrez.KeyValuePaired { .init(keyArray: keyArray, value: value) }

    /// 生成自身的拷貝。
    /// - Remark: 因為 Node 不是 Struct，所以會在 Compositor 被拷貝的時候無法被真實複製。
    /// 這樣一來，Compositor 複製品當中的 Node 的變化會被反應到原先的 Compositor 身上。
    /// 這在某些情況下會造成意料之外的混亂情況，所以需要引入一個拷貝用的建構子。
    public var copy: Node { .init(node: self) }

    /// 檢查當前節點是否「讀音字長與候選字字長不一致」。
    public var isReadingMismatched: Bool { keyArray.count != value.count }
    /// 該節點是否處於被覆寫的狀態。
    public var isOverridden: Bool { currentOverrideType != .withNoOverrides }

    /// 給出該節點內部單元圖陣列內目前被索引位置所指向的單元圖。
    public var currentUnigram: Megrez.Unigram {
      unigrams.isEmpty ? .init() : unigrams[currentUnigramIndex]
    }

    /// 給出該節點內部單元圖陣列內目前被索引位置所指向的單元圖的資料值。
    public var value: String { currentUnigram.value }

    /// 給出目前的最高權重單元圖當中的權重值。該結果可能會受節點覆寫狀態所影響。
    public var score: Double {
      guard !unigrams.isEmpty else { return 0 }
      switch currentOverrideType {
      case .withHighScore: return overridingScore
      case .withTopUnigramScore: return unigrams[0].score
      default: return currentUnigram.score
      }
    }

    public static func == (lhs: Node, rhs: Node) -> Bool {
      lhs.hashValue == rhs.hashValue
    }

    /// 做為預設雜湊函式。
    /// - Parameter hasher: 目前物件的雜湊碼。
    public func hash(into hasher: inout Hasher) {
      hasher.combine(overridingScore)
      hasher.combine(keyArray)
      hasher.combine(spanLength)
      hasher.combine(unigrams)
      hasher.combine(currentOverrideType)
      hasher.combine(currentUnigramIndex)
    }

    /// 重設該節點的覆寫狀態、及其內部的單元圖索引位置指向。
    public func reset() {
      currentUnigramIndex = 0
      currentOverrideType = .withNoOverrides
    }

    /// 將索引鍵按照給定的分隔符銜接成一個字串。
    /// - Parameter separator: 給定的分隔符，預設值為 Compositor.theSeparator。
    /// - Returns: 已經銜接完畢的字串。
    public func joinedKey(by separator: String = Megrez.Compositor.theSeparator) -> String {
      keyArray.joined(separator: separator)
    }

    /// 置換掉該節點內的單元圖陣列資料。
    /// 如果此時影響到了 currentUnigramIndex 所指的內容的話，則將其重設為 0。
    /// - Parameter source: 新的單元圖陣列資料，必須不能為空（否則必定崩潰）。
    public func syncingUnigrams(from source: [Megrez.Unigram]) {
      let oldCurrentValue = unigrams[currentUnigramIndex].value
      unigrams = source
      // if unigrams.isEmpty { unigrams.append(.init(value: key, score: -114.514)) }  // 保險，請按需啟用。
      currentUnigramIndex = max(min(unigrams.count - 1, currentUnigramIndex), 0)
      let newCurrentValue = unigrams[currentUnigramIndex].value
      if oldCurrentValue != newCurrentValue { reset() }
    }

    /// 指定要覆寫的單元圖資料值、以及覆寫行為種類。
    /// - Parameters:
    ///   - value: 給定的單元圖資料值。
    ///   - type: 覆寫行為種類。
    /// - Returns: 操作是否順利完成。
    public func selectOverrideUnigram(value: String, type: Node.OverrideType) -> Bool {
      guard type != .withNoOverrides else {
        return false
      }
      for (i, gram) in unigrams.enumerated() {
        if value != gram.value { continue }
        currentUnigramIndex = i
        currentOverrideType = type
        return true
      }
      return false
    }
  }
}

// MARK: - Array Extensions.

extension Array where Element == Megrez.Node {
  /// 從一個節點陣列當中取出目前的選字字串陣列。
  public var values: [String] { map(\.value) }

  /// 從一個節點陣列當中取出目前的索引鍵陣列。
  public func joinedKeys(by separator: String = Megrez.Compositor.theSeparator) -> [String] {
    map { $0.keyArray.lazy.joined(separator: separator) }
  }

  /// 從一個節點陣列當中取出目前的索引鍵陣列。
  public var keyArrays: [[String]] { map(\.keyArray) }

  /// 返回一連串的節點起點。結果為 (Result A, Result B) 辭典陣列。
  /// Result A 以索引查座標，Result B 以座標查索引。
  private var nodeBorderPointDictPair: (regionCursorMap: [Int: Int], cursorRegionMap: [Int: Int]) {
    // Result A 以索引查座標，Result B 以座標查索引。
    var resultA = [Int: Int]()
    var resultB: [Int: Int] = [-1: 0] // 防呆
    var cursorCounter = 0
    enumerated().forEach { nodeCounter, neta in
      resultA[nodeCounter] = cursorCounter
      neta.keyArray.forEach { _ in
        resultB[cursorCounter] = nodeCounter
        cursorCounter += 1
      }
    }
    resultA[count] = cursorCounter
    resultB[cursorCounter] = count
    return (resultA, resultB)
  }

  /// 返回一個辭典，以座標查索引。允許以游標位置查詢其屬於第幾個幅位座標（從 0 開始算）。
  public var cursorRegionMap: [Int: Int] { nodeBorderPointDictPair.cursorRegionMap }

  /// 總讀音單元數量。在絕大多數情況下，可視為總幅位長度。
  public var totalKeyCount: Int { map(\.keyArray.count).reduce(0, +) }

  /// 根據給定的游標，返回其前後最近的節點邊界。
  /// - Parameter cursor: 給定的游標。
  public func contextRange(ofGivenCursor cursor: Int) -> Range<Int> {
    guard !isEmpty else { return 0 ..< 0 }
    let lastSpanningLength = reversed()[0].keyArray.count
    var nilReturn = (totalKeyCount - lastSpanningLength) ..< totalKeyCount
    if cursor >= totalKeyCount { return nilReturn } // 防呆
    let cursor = Swift.max(0, cursor) // 防呆
    nilReturn = cursor ..< cursor
    // 下文按道理來講不應該會出現 nilReturn。
    let mapPair = nodeBorderPointDictPair
    guard let rearNodeID = mapPair.cursorRegionMap[cursor] else { return nilReturn }
    guard let rearIndex = mapPair.regionCursorMap[rearNodeID]
    else { return nilReturn }
    guard let frontIndex = mapPair.regionCursorMap[rearNodeID + 1]
    else { return nilReturn }
    return rearIndex ..< frontIndex
  }

  /// 在陣列內以給定游標位置找出對應的節點。
  /// - Parameters:
  ///   - cursor: 給定游標位置。
  ///   - outCursorPastNode: 找出的節點的前端位置。
  /// - Returns: 查找結果。
  public func findNode(at cursor: Int, target outCursorPastNode: inout Int) -> Megrez.Node? {
    guard !isEmpty else { return nil }
    let cursor = Swift.max(0, Swift.min(cursor, totalKeyCount - 1)) // 防呆
    let range = contextRange(ofGivenCursor: cursor)
    outCursorPastNode = range.upperBound
    guard let rearNodeID = nodeBorderPointDictPair.1[cursor] else { return nil }
    return count - 1 >= rearNodeID ? self[rearNodeID] : nil
  }

  /// 在陣列內以給定游標位置找出對應的節點。
  /// - Parameter cursor: 給定游標位置。
  /// - Returns: 查找結果。
  public func findNode(at cursor: Int) -> Megrez.Node? {
    var useless = 0
    return findNode(at: cursor, target: &useless)
  }

  /// 提供一組逐字的字音配對陣列（不使用 Megrez 的 KeyValuePaired 類型），但字音不匹配的節點除外。
  public var smashedPairs: [(key: String, value: String)] {
    var arrData = [(key: String, value: String)]()
    forEach { node in
      if node.isReadingMismatched, !node.keyArray.joined().isEmpty {
        arrData.append((key: node.keyArray.joined(separator: "\t"), value: node.value))
        return
      }
      let arrValueChars = node.value.map(\.description)
      node.keyArray.enumerated().forEach { i, key in
        arrData.append((key: key, value: arrValueChars[i]))
      }
    }
    return arrData
  }
}

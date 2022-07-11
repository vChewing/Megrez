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

extension Megrez {
  /// 組字器。
  public class Compositor: Grid {
    /// 給被丟掉的節點路徑施加的負權重。
    private let kDroppedPathScore: Double = -999
    /// 該組字器的游標位置。
    public var cursorIndex: Int = 0 { didSet { cursorIndex = max(0, min(cursorIndex, readings.count)) } }
    /// 該組字器的讀音陣列。
    private(set) var readings: [String] = []
    /// 該組字器所使用的語言模型。
    private var langModel: LangModelProtocol

    /// 公開：多字讀音鍵當中用以分割漢字讀音的記號，預設為空。
    public var joinSeparator: String = ""

    /// 公開：該組字器的長度，也就是內建漢字讀音的數量（唯讀）。
    public var length: Int { readings.count }

    /// 組字器。
    /// - Parameters:
    ///   - lm: 語言模型。可以是任何基於 Megrez.LangModel 的衍生型別。
    ///   - length: 指定該組字器內可以允許的最大詞長，預設為 10 字。
    ///   - separator: 多字讀音鍵當中用以分割漢字讀音的記號，預設為空。
    public init(lm: LangModelProtocol, length: Int = 10, separator: String = "") {
      langModel = lm
      super.init(spanLength: abs(length))  // 防呆
      joinSeparator = separator
    }

    /// 組字器自我清空專用函式。
    override public func clear() {
      super.clear()
      cursorIndex = 0
      readings.removeAll()
    }

    /// 在游標位置插入給定的讀音。
    /// - Parameters:
    ///   - reading: 要插入的讀音。
    public func insertReadingAtCursor(reading: String) {
      readings.insert(reading, at: cursorIndex)
      expandGridByOneAt(location: cursorIndex)
      build()
      cursorIndex += 1
    }

    /// 朝著與文字輸入方向相反的方向、砍掉一個與游標相鄰的讀音。
    /// 在威注音的術語體系當中，「與文字輸入方向相反的方向」為向後（Rear）。
    @discardableResult public func deleteReadingAtTheRearOfCursor() -> Bool {
      if cursorIndex == 0 {
        return false
      }

      readings.remove(at: cursorIndex - 1)
      cursorIndex -= 1
      shrinkGridByOneAt(location: cursorIndex)
      build()
      return true
    }

    /// 朝著往文字輸入方向、砍掉一個與游標相鄰的讀音。
    /// 在威注音的術語體系當中，「文字輸入方向」為向前（Front）。
    @discardableResult public func deleteReadingToTheFrontOfCursor() -> Bool {
      if cursorIndex == readings.count {
        return false
      }

      readings.remove(at: cursorIndex)
      shrinkGridByOneAt(location: cursorIndex)
      build()
      return true
    }

    /// 移除該組字器最先被輸入的第 X 個讀音單元。
    ///
    /// 用於輸入法組字區長度上限處理：
    /// 將該位置要溢出的敲字內容遞交之後、再執行這個函式。
    @discardableResult public func removeHeadReadings(count: Int) -> Bool {
      let count = abs(count)  // 防呆
      if count > length {
        return false
      }

      for _ in 0..<count {
        if cursorIndex > 0 {
          cursorIndex -= 1
        }
        if !readings.isEmpty {
          readings.removeFirst()
          shrinkGridByOneAt(location: 0)
        }
        build()
      }

      return true
    }

    /// 對已給定的軌格按照給定的位置與條件進行正向爬軌。
    /// - Returns: 一個包含有效結果的節錨陣列。
    public func walk() -> [NodeAnchor] {
      let newLocation = width
      // 這裡把所有空節點都過濾掉。
      return Array(
        reverseWalk(at: newLocation).reversed()
      ).lazy.filter { !$0.isEmpty }
    }

    // MARK: - Private functions

    /// 內部專用反芻函式，對已給定的軌格按照給定的位置與條件進行反向爬軌。
    /// - Parameters:
    ///   - location: 開始爬軌的位置。
    ///   - mass: 給定累計權重，非必填參數。預設值為 0。
    ///   - joinedPhrase: 用以統計累計長詞的內部參數，請勿主動使用。
    ///   - longPhrases: 用以統計累計長詞的內部參數，請勿主動使用。
    /// - Returns: 一個包含結果的節錨陣列。
    private func reverseWalk(
      at location: Int,
      mass: Double = 0.0,
      joinedPhrase: String = "",
      longPhrases: [String] = .init()
    ) -> [NodeAnchor] {
      let location = abs(location)  // 防呆
      if location == 0 || location > width {
        return .init()
      }

      var paths = [[NodeAnchor]]()
      let nodes = nodesEndingAt(location: location).stableSorted {
        $0.scoreForSort > $1.scoreForSort
      }

      guard !nodes.isEmpty else { return .init() }  // 防止下文出現範圍外索引的錯誤

      if nodes[0].node.score >= Node.kSelectedCandidateScore {
        // 在使用者有選過候選字詞的情況下，摒棄非依此據而成的節點路徑。
        var theAnchor = nodes[0]
        theAnchor.mass = mass + nodes[0].node.score
        var path: [NodeAnchor] = reverseWalk(
          at: location - theAnchor.spanLength, mass: theAnchor.mass
        )
        path.insert(theAnchor, at: 0)
        paths.append(path)
      } else if !longPhrases.isEmpty {
        var path = [NodeAnchor]()
        for theAnchor in nodes {
          var theAnchor = theAnchor
          let joinedValue = theAnchor.node.currentPair.value + joinedPhrase
          // 如果只是一堆單漢字的節點組成了同樣的長詞的話，直接棄用這個節點路徑。
          // 打比方說「八/月/中/秋/山/林/涼」與「八月/中秋/山林/涼」在使用者來看
          // 是「結果等價」的，那就扔掉前者。
          if longPhrases.contains(joinedValue) {
            theAnchor.mass = kDroppedPathScore
            path.insert(theAnchor, at: 0)
            paths.append(path)
            continue
          }
          theAnchor.mass = mass + theAnchor.node.score
          path = reverseWalk(
            at: location - theAnchor.spanLength,
            mass: theAnchor.mass,
            joinedPhrase: (joinedValue.count >= longPhrases[0].count) ? "" : joinedValue,
            longPhrases: .init()
          )
          path.insert(theAnchor, at: 0)
          paths.append(path)
        }
      } else {
        // 看看當前格位有沒有更長的候選字詞。
        var longPhrases = [String]()
        for theAnchor in nodes.lazy.filter({ $0.spanLength > 1 }) {
          longPhrases.append(theAnchor.node.currentPair.value)
        }

        longPhrases = longPhrases.stableSorted {
          $0.count > $1.count
        }
        for theAnchor in nodes {
          var theAnchor = theAnchor
          theAnchor.mass = mass + theAnchor.node.score
          var path = [NodeAnchor]()
          path = reverseWalk(
            at: location - theAnchor.spanLength, mass: theAnchor.mass,
            joinedPhrase: (theAnchor.spanLength > 1) ? "" : theAnchor.node.currentPair.value,
            longPhrases: .init()
          )
          path.insert(theAnchor, at: 0)
          paths.append(path)
        }
      }

      guard !paths.isEmpty else {
        return .init()
      }

      var result: [NodeAnchor] = paths[0]
      for neta in paths.lazy.filter({
        $0.last!.mass > result.last!.mass
      }) {
        result = neta
      }

      return result  // 空節點過濾的步驟交給 walk() 這個對外函式，以避免重複執行清理步驟。
    }

    private func build() {
      let itrBegin: Int =
        (cursorIndex < maxBuildSpanLength) ? 0 : cursorIndex - maxBuildSpanLength
      let itrEnd: Int = min(cursorIndex + maxBuildSpanLength, readings.count)

      for p in itrBegin..<itrEnd {
        for q in 1..<maxBuildSpanLength {
          if p + q > itrEnd { break }
          let arrSlice = readings[p..<(p + q)]
          let combinedReading: String = join(slice: arrSlice, separator: joinSeparator)
          if hasMatchedNode(location: p, spanLength: q, key: combinedReading) { continue }
          let unigrams: [Unigram] = langModel.unigramsFor(key: combinedReading)
          if unigrams.isEmpty { continue }
          let n = Node(key: combinedReading, unigrams: unigrams)
          insertNode(node: n, location: p, spanLength: q)
        }
      }
    }

    private func join(slice arrSlice: ArraySlice<String>, separator: String) -> String {
      arrSlice.joined(separator: separator)
    }
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

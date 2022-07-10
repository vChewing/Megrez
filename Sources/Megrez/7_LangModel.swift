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

/// 語言模組協定。
public protocol LangModelProtocol {
  /// 給定鍵，讓語言模型找給一組單元圖陣列。
  func unigramsFor(key: String) -> [Megrez.Unigram]
  /// 給定鍵，確認是否有單元圖記錄在庫。
  func hasUnigramsFor(key: String) -> Bool
}

extension Megrez.Compositor {
  /// 一個套殼語言模型，用來始終返回經過排序的單元圖。
  public class LangModelRanked: LangModelProtocol {
    private let langModel: LangModelProtocol
    /// 一個套殼語言模型，用來始終返回經過排序的單元圖。
    /// - Parameter withLM: 用來對接的語言模型。
    public init(withLM: LangModelProtocol) {
      langModel = withLM
    }

    /// 給定索引鍵，讓語言模型找給一組經過穩定排序的單元圖陣列。
    /// - Parameter key: 給定的索引鍵字串。
    /// - Returns: 對應的經過穩定排序的單元圖陣列。
    public func unigramsFor(key: String) -> [Megrez.Unigram] {
      langModel.unigramsFor(key: key).stableSorted { $0.score > $1.score }
    }

    /// 根據給定的索引鍵來確認各個資料庫陣列內是否存在對應的資料。
    /// - Parameter key: 索引鍵。
    /// - Returns: 是否在庫。
    public func hasUnigramsFor(key: String) -> Bool {
      langModel.hasUnigramsFor(key: key)
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

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

import XCTest

@testable import Megrez

final class MegrezTests: XCTestCase {
  // MARK: - Input Test (SimpleLM)

  func testInputWithForwardWalk() throws {
    print("// 開始測試語言文字輸入處理")
    let lmTestInput = SimpleLM(input: strSampleData)
    let compositor = Megrez.Compositor(lm: lmTestInput)
    var walked = [Megrez.NodeAnchor]()

    func walk() {
      walked = compositor.walk()
    }

    // 模擬輸入法的行為，每次敲字或選字都重新 walk。
    compositor.insertReadingAtCursor(reading: "gao1")
    walk()
    compositor.insertReadingAtCursor(reading: "ji4")
    walk()
    compositor.cursorIndex = 1
    compositor.insertReadingAtCursor(reading: "ke1")
    walk()
    compositor.cursorIndex = 1
    compositor.deleteReadingToTheFrontOfCursor()
    walk()
    compositor.insertReadingAtCursor(reading: "ke1")
    walk()
    compositor.cursorIndex = 0
    compositor.deleteReadingToTheFrontOfCursor()
    walk()
    compositor.insertReadingAtCursor(reading: "gao1")
    walk()
    compositor.cursorIndex = compositor.length
    compositor.insertReadingAtCursor(reading: "gong1")
    walk()
    compositor.insertReadingAtCursor(reading: "si1")
    walk()
    compositor.insertReadingAtCursor(reading: "de5")
    walk()
    compositor.insertReadingAtCursor(reading: "nian2")
    walk()
    compositor.insertReadingAtCursor(reading: "zhong1")
    walk()
    compositor.grid.fixNodeSelectedCandidate(location: 7, value: "年終")
    walk()
    compositor.insertReadingAtCursor(reading: "jiang3")
    walk()
    compositor.insertReadingAtCursor(reading: "jin1")
    walk()
    compositor.insertReadingAtCursor(reading: "ni3")
    walk()
    compositor.insertReadingAtCursor(reading: "zhe4")
    walk()
    compositor.insertReadingAtCursor(reading: "yang4")
    walk()

    // 這裡模擬一個輸入法的常見情況：每次敲一個字詞都會 walk，然後你回頭編輯完一些內容之後又會立刻重新 walk。
    // 如果只在這裡測試第一遍 walk 的話，測試通過了也無法測試之後再次 walk 是否會正常。

    compositor.cursorIndex = 1
    compositor.deleteReadingToTheFrontOfCursor()

    // 於是咱們 walk 第二遍
    walk()
    XCTAssert(!walked.isEmpty)

    // 做好第三遍的準備，這次咱們來一次插入性編輯。
    // 重點測試這句是否正常，畢竟是在 walked 過的節點內進行插入編輯。
    compositor.insertReadingAtCursor(reading: "ke1")

    // 於是咱們 walk 第三遍。
    // 這一遍會直接曝露「上述修改是否有對 compositor 造成了破壞性的損失」，
    // 所以很重要。
    walk()
    XCTAssert(!walked.isEmpty)

    var composed: [String] = walked.map(\.node.currentPair.value)
    print(composed)
    let correctResult = ["高科技", "公司", "的", "年終", "獎金", "你", "這樣"]
    print(" - 上述列印結果理應於下面這行一致：")
    print(correctResult)
    XCTAssertEqual(composed, correctResult)

    // 測試 DumpDOT
    compositor.cursorIndex = compositor.length
    compositor.deleteReadingAtTheRearOfCursor()
    compositor.deleteReadingAtTheRearOfCursor()
    compositor.deleteReadingAtTheRearOfCursor()
    let expectedDumpDOT =
      "digraph {\ngraph [ rankdir=LR ];\nBOS;\nBOS -> 高;\n高;\n高 -> 科;\n高 -> 科技;\nBOS -> 高科技;\n高科技;\n高科技 -> 工;\n高科技 -> 公司;\n科;\n科 -> 際;\n科 -> 濟公;\n科技;\n科技 -> 工;\n科技 -> 公司;\n際;\n際 -> 工;\n際 -> 公司;\n濟公;\n濟公 -> 斯;\n工;\n工 -> 斯;\n公司;\n公司 -> 的;\n斯;\n斯 -> 的;\n的;\n的 -> 年;\n的 -> 年終;\n年;\n年 -> 中;\n年終;\n年終 -> 獎;\n年終 -> 獎金;\n中;\n中 -> 獎;\n中 -> 獎金;\n獎;\n獎 -> 金;\n獎金;\n獎金 -> EOS;\n金;\n金 -> EOS;\nEOS;\n}\n"
    XCTAssertEqual(compositor.grid.dumpDOT, expectedDumpDOT)

    print("========新測試========")
    compositor.clear()
    compositor.insertReadingAtCursor(reading: "jiao4")
    walk()
    compositor.insertReadingAtCursor(reading: "yu4")
    walk()
    compositor.grid.fixNodeSelectedCandidate(location: 0, value: "較")
    walk()
    compositor.grid.fixNodeSelectedCandidate(location: 2, value: "教育")
    walk()

    composed = walked.map(\.node.currentPair.value)
    print(composed)
    let expectedResult = ["教育"]
    print(" - 上述列印結果理應於下面這行一致：")
    print(expectedResult)
    XCTAssertEqual(composed, expectedResult)
  }

  // MARK: - Test Word Segmentation (SimpleLM)

  func testWordSegmentation() throws {
    print("// 開始測試語句分節處理")
    let lmTestSegmentation = SimpleLM(input: strSampleData, swapKeyValue: true)
    let compositor = Megrez.Compositor(lm: lmTestSegmentation, separator: "")

    compositor.insertReadingAtCursor(reading: "高")
    compositor.insertReadingAtCursor(reading: "科")
    compositor.insertReadingAtCursor(reading: "技")
    compositor.insertReadingAtCursor(reading: "公")
    compositor.insertReadingAtCursor(reading: "司")
    compositor.insertReadingAtCursor(reading: "的")
    compositor.insertReadingAtCursor(reading: "年")
    compositor.insertReadingAtCursor(reading: "終")
    compositor.insertReadingAtCursor(reading: "獎")
    compositor.insertReadingAtCursor(reading: "金")

    let segmented: [String] = compositor.walk().map(\.node.currentPair.key)
    print(segmented)
    let correctResult = ["高科技", "公司", "的", "年終", "獎金"]
    print(" - 上述列印結果理應於下面這行一致：")
    print(correctResult)

    XCTAssertEqual(segmented, correctResult)
  }
}

// MARK: - 用以測試的語言模型（簡單範本型）

class SimpleLM: Megrez.LangModel {
  var database: [String: [Megrez.Unigram]] = [:]
  init(input: String, swapKeyValue: Bool = false) {
    super.init()
    let sstream = input.components(separatedBy: "\n")
    for line in sstream {
      if line.isEmpty || line.hasPrefix("#") {
        continue
      }
      let linestream = line.split(separator: " ")
      let col0 = String(linestream[0])
      let col1 = String(linestream[1])
      let col2 = Double(linestream[2]) ?? 0.0
      var u = Megrez.Unigram(keyValue: Megrez.KeyValuePaired(), score: 0)
      if swapKeyValue {
        u.keyValue.key = col1
        u.keyValue.value = col0
      } else {
        u.keyValue.key = col0
        u.keyValue.value = col1
      }
      u.score = col2
      database[u.keyValue.key, default: []].append(u)
    }
  }

  override func unigramsFor(key: String) -> [Megrez.Unigram] {
    if let f = database[key] {
      return f
    } else {
      return [Megrez.Unigram]().sorted { $0.score > $1.score }
    }
  }

  override func hasUnigramsFor(key: String) -> Bool {
    database.keys.contains(key)
  }
}

// MARK: - 用以測試的詞頻數據

private let strSampleData = #"""
  #
  # 下述詞頻資料取自 libTaBE 資料庫 (http://sourceforge.net/projects/libtabe/)
  # (2002 最終版). 該專案於 1999 年由 Pai-Hsiang Hsiao 發起、以 BSD 授權發行。
  #
  ni3 你 -6.000000 // Non-LibTaBE
  zhe4 這 -6.000000 // Non-LibTaBE
  yang4 樣 -6.000000 // Non-LibTaBE
  si1 絲 -9.495858
  si1 思 -9.006414
  si1 私 -99.000000
  si1 斯 -8.091803
  si1 司 -99.000000
  si1 嘶 -13.513987
  si1 撕 -12.259095
  gao1 高 -7.171551
  ke1 顆 -10.574273
  ke1 棵 -11.504072
  ke1 刻 -10.450457
  ke1 科 -7.171052
  ke1 柯 -99.000000
  gao1 膏 -11.928720
  gao1 篙 -13.624335
  gao1 糕 -12.390804
  de5 的 -3.516024
  di2 的 -3.516024
  di4 的 -3.516024
  zhong1 中 -5.809297
  de5 得 -7.427179
  gong1 共 -8.381971
  gong1 供 -8.501463
  ji4 既 -99.000000
  jin1 今 -8.034095
  gong1 紅 -8.858181
  ji4 際 -7.608341
  ji4 季 -99.000000
  jin1 金 -7.290109
  ji4 騎 -10.939895
  zhong1 終 -99.000000
  ji4 記 -99.000000
  ji4 寄 -99.000000
  jin1 斤 -99.000000
  ji4 繼 -9.715317
  ji4 計 -7.926683
  ji4 暨 -8.373022
  zhong1 鐘 -9.877580
  jin1 禁 -10.711079
  gong1 公 -7.877973
  gong1 工 -7.822167
  gong1 攻 -99.000000
  gong1 功 -99.000000
  gong1 宮 -99.000000
  zhong1 鍾 -9.685671
  ji4 繫 -10.425662
  gong1 弓 -99.000000
  gong1 恭 -99.000000
  ji4 劑 -8.888722
  ji4 祭 -10.204425
  jin1 浸 -11.378321
  zhong1 盅 -99.000000
  ji4 忌 -99.000000
  ji4 技 -8.450826
  jin1 筋 -11.074890
  gong1 躬 -99.000000
  ji4 冀 -12.045357
  zhong1 忠 -99.000000
  ji4 妓 -99.000000
  ji4 濟 -9.517568
  ji4 薊 -12.021587
  jin1 巾 -99.000000
  jin1 襟 -12.784206
  nian2 年 -6.086515
  jiang3 講 -9.164384
  jiang3 獎 -8.690941
  jiang3 蔣 -10.127828
  nian2 黏 -11.336864
  nian2 粘 -11.285740
  jiang3 槳 -12.492933
  gong1si1 公司 -6.299461
  ke1ji4 科技 -6.736613
  ji4gong1 濟公 -13.336653
  jiang3jin1 獎金 -10.344678
  nian2zhong1 年終 -11.668947
  nian2zhong1 年中 -11.373044
  gao1ke1ji4 高科技 -9.842421
  zhe4yang4 這樣 -6.000000 // Non-LibTaBE
  ni3zhe4 你這 -9.000000 // Non-LibTaBE
  jiao4 教 -3.676169
  jiao4 較 -3.24869962
  jiao4yu4 教育 -3.32220565
  yu4 育 -3.30192952
  """#

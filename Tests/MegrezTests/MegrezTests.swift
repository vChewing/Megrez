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

import Cocoa
import XCTest

@testable import Megrez

final class MegrezTests: XCTestCase {
  func testSpanUnitInternalAbilities() throws {
    let langModel = SimpleLM(input: strSampleData)
    var span = Megrez.SpanUnit()
    let n1 = Megrez.Node(key: "gao", unigrams: langModel.unigramsFor(key: "gao1"))
    let n3 = Megrez.Node(key: "gao1ke1ji4", unigrams: langModel.unigramsFor(key: "gao1ke1ji4"))
    XCTAssertEqual(span.maxLength, 0)
    span.insert(node: n1, length: 1)
    XCTAssertEqual(span.maxLength, 1)
    span.insert(node: n3, length: 3)
    XCTAssertEqual(span.maxLength, 3)
    XCTAssertEqual(span.nodeOf(length: 1), n1)
    XCTAssertEqual(span.nodeOf(length: 2), nil)
    XCTAssertEqual(span.nodeOf(length: 3), n3)
    span.clear()
    XCTAssertEqual(span.maxLength, 0)
    XCTAssertEqual(span.nodeOf(length: 1), nil)
    XCTAssertEqual(span.nodeOf(length: 2), nil)
    XCTAssertEqual(span.nodeOf(length: 3), nil)

    span.insert(node: n1, length: 1)
    span.insert(node: n3, length: 3)
    span.dropNodesBeyond(length: 1)
    XCTAssertEqual(span.maxLength, 1)
    XCTAssertEqual(span.nodeOf(length: 1), n1)
    XCTAssertEqual(span.nodeOf(length: 2), nil)
    XCTAssertEqual(span.nodeOf(length: 3), nil)
    span.dropNodesBeyond(length: 0)
    XCTAssertEqual(span.maxLength, 0)
    XCTAssertEqual(span.nodeOf(length: 1), nil)
  }

  func testBasicFeaturesOfCompositor() throws {
    let compositor = Megrez.Compositor(lm: MockLM())
    compositor.joinSeparator = ""
    XCTAssertEqual(compositor.joinSeparator, "")
    XCTAssertEqual(compositor.cursorIndex, 0)
    XCTAssertEqual(compositor.length, 0)

    XCTAssertTrue(compositor.insertReading("a"))
    XCTAssertEqual(compositor.cursorIndex, 1)
    XCTAssertEqual(compositor.length, 1)
    XCTAssertEqual(compositor.width, 1)
    XCTAssertEqual(compositor.spans[0].maxLength, 1)
    guard let zeroNode = compositor.spans[0].nodeOf(length: 1) else {
      return
    }
    XCTAssertEqual(zeroNode.key, "a")

    XCTAssertTrue(compositor.dropReading(direction: .rear))
    XCTAssertEqual(compositor.cursorIndex, 0)
    XCTAssertEqual(compositor.cursorIndex, 0)
    XCTAssertEqual(compositor.width, 0)
  }

  func testInvalidOperations() throws {
    class TestLM: LangModelProtocol {
      func bigramsForKeys(precedingKey _: String, key _: String) -> [Megrez.Bigram] {
        .init()
      }

      func hasUnigramsFor(key: String) -> Bool { key == "foo" }
      func unigramsFor(key: String) -> [Megrez.Unigram] {
        key == "foo" ? [.init(keyValue: .init(key: "foo", value: "foo"), score: -1)] : .init()
      }
    }

    let compositor = Megrez.Compositor(lm: TestLM())
    compositor.joinSeparator = ";"
    XCTAssertFalse(compositor.insertReading("bar"))
    XCTAssertFalse(compositor.insertReading(""))
    XCTAssertFalse(compositor.insertReading(""))
    XCTAssertFalse(compositor.dropReading(direction: .rear))
    XCTAssertFalse(compositor.dropReading(direction: .front))

    compositor.insertReading("foo")
    XCTAssertTrue(compositor.dropReading(direction: .rear))
    XCTAssertEqual(compositor.length, 0)
    compositor.insertReading("foo")
    compositor.cursorIndex = 0
    XCTAssertTrue(compositor.dropReading(direction: .front))
    XCTAssertEqual(compositor.length, 0)
  }

  func testDeleteToTheFrontOfCursor() throws {
    let compositor = Megrez.Compositor(lm: MockLM())
    compositor.insertReading("a")
    compositor.cursorIndex = 0
    XCTAssertEqual(compositor.cursorIndex, 0)
    XCTAssertEqual(compositor.length, 1)
    XCTAssertEqual(compositor.width, 1)
    XCTAssertFalse(compositor.dropReading(direction: .rear))
    XCTAssertEqual(compositor.cursorIndex, 0)
    XCTAssertEqual(compositor.length, 1)
    XCTAssertTrue(compositor.dropReading(direction: .front))
    XCTAssertEqual(compositor.cursorIndex, 0)
    XCTAssertEqual(compositor.length, 0)
    XCTAssertEqual(compositor.width, 0)
  }

  func testMultipleSpanUnits() throws {
    let compositor = Megrez.Compositor(lm: MockLM())
    compositor.joinSeparator = ";"
    compositor.insertReading("a")
    compositor.insertReading("b")
    compositor.insertReading("c")
    XCTAssertEqual(compositor.cursorIndex, 3)
    XCTAssertEqual(compositor.length, 3)
    XCTAssertEqual(compositor.width, 3)
    XCTAssertEqual(compositor.spans[0].maxLength, 3)
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 1)?.key, "a")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 2)?.key, "a;b")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 3)?.key, "a;b;c")
    XCTAssertEqual(compositor.spans[1].maxLength, 2)
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 1)?.key, "b")
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 2)?.key, "b;c")
    XCTAssertEqual(compositor.spans[2].maxLength, 1)
    XCTAssertEqual(compositor.spans[2].nodeOf(length: 1)?.key, "c")
  }

  func testSpanUnitDeletionFromFront() throws {
    let compositor = Megrez.Compositor(lm: MockLM())
    compositor.joinSeparator = ";"
    compositor.insertReading("a")
    compositor.insertReading("b")
    compositor.insertReading("c")
    XCTAssertFalse(compositor.dropReading(direction: .front))
    XCTAssertTrue(compositor.dropReading(direction: .rear))
    XCTAssertEqual(compositor.cursorIndex, 2)
    XCTAssertEqual(compositor.length, 2)
    XCTAssertEqual(compositor.width, 2)
    XCTAssertEqual(compositor.spans[0].maxLength, 2)
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 1)?.key, "a")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 2)?.key, "a;b")
    XCTAssertEqual(compositor.spans[1].maxLength, 1)
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 1)?.key, "b")
  }

  func testSpanUnitDeletionFromMiddle() throws {
    let compositor = Megrez.Compositor(lm: MockLM())
    compositor.joinSeparator = ";"
    compositor.insertReading("a")
    compositor.insertReading("b")
    compositor.insertReading("c")
    compositor.cursorIndex = 2

    XCTAssertTrue(compositor.dropReading(direction: .rear))
    XCTAssertEqual(compositor.cursorIndex, 1)
    XCTAssertEqual(compositor.length, 2)
    XCTAssertEqual(compositor.width, 2)
    XCTAssertEqual(compositor.spans[0].maxLength, 2)
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 1)?.key, "a")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 2)?.key, "a;c")
    XCTAssertEqual(compositor.spans[1].maxLength, 1)
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 1)?.key, "c")

    compositor.clear()
    compositor.insertReading("a")
    compositor.insertReading("b")
    compositor.insertReading("c")
    compositor.cursorIndex = 1

    XCTAssertTrue(compositor.dropReading(direction: .front))
    XCTAssertEqual(compositor.cursorIndex, 1)
    XCTAssertEqual(compositor.length, 2)
    XCTAssertEqual(compositor.width, 2)
    XCTAssertEqual(compositor.spans[0].maxLength, 2)
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 1)?.key, "a")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 2)?.key, "a;c")
    XCTAssertEqual(compositor.spans[1].maxLength, 1)
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 1)?.key, "c")
  }

  func testSpanUnitDeletionFromRear() throws {
    let compositor = Megrez.Compositor(lm: MockLM())
    compositor.joinSeparator = ";"
    compositor.insertReading("a")
    compositor.insertReading("b")
    compositor.insertReading("c")
    compositor.cursorIndex = 0

    XCTAssertFalse(compositor.dropReading(direction: .rear))
    XCTAssertTrue(compositor.dropReading(direction: .front))
    XCTAssertEqual(compositor.cursorIndex, 0)
    XCTAssertEqual(compositor.length, 2)
    XCTAssertEqual(compositor.width, 2)
    XCTAssertEqual(compositor.spans[0].maxLength, 2)
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 1)?.key, "b")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 2)?.key, "b;c")
    XCTAssertEqual(compositor.spans[1].maxLength, 1)
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 1)?.key, "c")
  }

  func testSpanUnitInsertion() throws {
    let compositor = Megrez.Compositor(lm: MockLM())
    compositor.joinSeparator = ";"
    compositor.insertReading("a")
    compositor.insertReading("b")
    compositor.insertReading("c")
    compositor.cursorIndex = 1
    compositor.insertReading("X")

    XCTAssertEqual(compositor.cursorIndex, 2)
    XCTAssertEqual(compositor.length, 4)
    XCTAssertEqual(compositor.width, 4)
    XCTAssertEqual(compositor.spans[0].maxLength, 4)
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 1)?.key, "a")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 2)?.key, "a;X")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 3)?.key, "a;X;b")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 4)?.key, "a;X;b;c")
    XCTAssertEqual(compositor.spans[1].maxLength, 3)
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 1)?.key, "X")
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 2)?.key, "X;b")
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 3)?.key, "X;b;c")
    XCTAssertEqual(compositor.spans[2].maxLength, 2)
    XCTAssertEqual(compositor.spans[2].nodeOf(length: 1)?.key, "b")
    XCTAssertEqual(compositor.spans[2].nodeOf(length: 2)?.key, "b;c")
    XCTAssertEqual(compositor.spans[3].maxLength, 1)
    XCTAssertEqual(compositor.spans[3].nodeOf(length: 1)?.key, "c")
  }

  func testLongGridDeletion() throws {
    let compositor = Megrez.Compositor(lm: MockLM())
    compositor.joinSeparator = ""
    compositor.insertReading("a")
    compositor.insertReading("b")
    compositor.insertReading("c")
    compositor.insertReading("d")
    compositor.insertReading("e")
    compositor.insertReading("f")
    compositor.insertReading("g")
    compositor.insertReading("h")
    compositor.insertReading("i")
    compositor.insertReading("j")
    compositor.insertReading("k")
    compositor.insertReading("l")
    compositor.insertReading("m")
    compositor.insertReading("n")
    compositor.cursorIndex = 7
    XCTAssertTrue(compositor.dropReading(direction: .rear))
    XCTAssertEqual(compositor.cursorIndex, 6)
    XCTAssertEqual(compositor.length, 13)
    XCTAssertEqual(compositor.width, 13)
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 6)?.key, "abcdef")
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 6)?.key, "bcdefh")
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 5)?.key, "bcdef")
    XCTAssertEqual(compositor.spans[2].nodeOf(length: 6)?.key, "cdefhi")
    XCTAssertEqual(compositor.spans[2].nodeOf(length: 5)?.key, "cdefh")
    XCTAssertEqual(compositor.spans[3].nodeOf(length: 6)?.key, "defhij")
    XCTAssertEqual(compositor.spans[4].nodeOf(length: 6)?.key, "efhijk")
    XCTAssertEqual(compositor.spans[5].nodeOf(length: 6)?.key, "fhijkl")
    XCTAssertEqual(compositor.spans[6].nodeOf(length: 6)?.key, "hijklm")
    XCTAssertEqual(compositor.spans[7].nodeOf(length: 6)?.key, "ijklmn")
    XCTAssertEqual(compositor.spans[8].nodeOf(length: 5)?.key, "jklmn")
  }

  func testLongGridInsertion() throws {
    let compositor = Megrez.Compositor(lm: MockLM())
    compositor.joinSeparator = ""
    compositor.insertReading("a")
    compositor.insertReading("b")
    compositor.insertReading("c")
    compositor.insertReading("d")
    compositor.insertReading("e")
    compositor.insertReading("f")
    compositor.insertReading("g")
    compositor.insertReading("h")
    compositor.insertReading("i")
    compositor.insertReading("j")
    compositor.insertReading("k")
    compositor.insertReading("l")
    compositor.insertReading("m")
    compositor.insertReading("n")
    compositor.cursorIndex = 7
    compositor.insertReading("X")
    XCTAssertEqual(compositor.cursorIndex, 8)
    XCTAssertEqual(compositor.length, 15)
    XCTAssertEqual(compositor.width, 15)
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 6)?.key, "abcdef")
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 6)?.key, "bcdefg")
    XCTAssertEqual(compositor.spans[2].nodeOf(length: 6)?.key, "cdefgX")
    XCTAssertEqual(compositor.spans[3].nodeOf(length: 6)?.key, "defgXh")
    XCTAssertEqual(compositor.spans[3].nodeOf(length: 5)?.key, "defgX")
    XCTAssertEqual(compositor.spans[4].nodeOf(length: 6)?.key, "efgXhi")
    XCTAssertEqual(compositor.spans[4].nodeOf(length: 5)?.key, "efgXh")
    XCTAssertEqual(compositor.spans[4].nodeOf(length: 4)?.key, "efgX")
    XCTAssertEqual(compositor.spans[4].nodeOf(length: 3)?.key, "efg")
    XCTAssertEqual(compositor.spans[5].nodeOf(length: 6)?.key, "fgXhij")
    XCTAssertEqual(compositor.spans[6].nodeOf(length: 6)?.key, "gXhijk")
    XCTAssertEqual(compositor.spans[7].nodeOf(length: 6)?.key, "Xhijkl")
    XCTAssertEqual(compositor.spans[8].nodeOf(length: 6)?.key, "hijklm")
  }

  func testWordSegmentation() throws {
    let compositor = Megrez.Compositor(lm: SimpleLM(input: strSampleData, swapKeyValue: true))
    compositor.joinSeparator = ""
    for i in "高科技公司的年終獎金" {
      compositor.insertReading(String(i))
    }
    XCTAssertEqual(compositor.walk().keys, ["高科技", "公司", "的", "年終", "獎金"])
  }

  func testLanguageInput() throws {
    let compositor = Megrez.Compositor(lm: SimpleLM(input: strSampleData))
    compositor.joinSeparator = ""
    compositor.insertReading("gao1")
    compositor.insertReading("ji4")
    compositor.cursorIndex = 1
    compositor.insertReading("ke1")
    compositor.cursorIndex = 0
    compositor.dropReading(direction: .front)
    compositor.insertReading("gao1")
    compositor.cursorIndex = compositor.length
    compositor.insertReading("gong1")
    compositor.insertReading("si1")
    compositor.insertReading("de5")
    compositor.insertReading("nian2")
    compositor.insertReading("zhong1")
    compositor.insertReading("jiang3")
    compositor.insertReading("jin1")
    var result = compositor.walk()
    XCTAssertEqual(result.values, ["高科技", "公司", "的", "年中", "獎金"])
    XCTAssertEqual(compositor.length, 10)
    compositor.cursorIndex = 7
    compositor.fixNodeSelectedCandidate("年終", at: 7)
    result = compositor.walk()
    XCTAssertEqual(result.values, ["高科技", "公司", "的", "年終", "獎金"])
  }

  func testOverrideOverlappingNodes() throws {
    let compositor = Megrez.Compositor(lm: SimpleLM(input: strSampleData))
    compositor.joinSeparator = ""
    compositor.insertReading("gao1")
    compositor.insertReading("ke1")
    compositor.insertReading("ji4")
    compositor.cursorIndex = 1
    compositor.fixNodeSelectedCandidate("膏", at: compositor.cursorIndex)
    var result = compositor.walk()
    XCTAssertEqual(result.values, ["膏", "科技"])
    compositor.fixNodeSelectedCandidate("高科技", at: 2)
    result = compositor.walk()
    XCTAssertEqual(result.values, ["高科技"])
    compositor.fixNodeSelectedCandidate("膏", at: 1)
    result = compositor.walk()
    XCTAssertEqual(result.values, ["膏", "科技"])

    compositor.fixNodeSelectedCandidate("柯", at: 2)
    result = compositor.walk()
    XCTAssertEqual(result.values, ["膏", "柯", "際"])

    compositor.fixNodeSelectedCandidate("暨", at: 3)
    result = compositor.walk()
    XCTAssertEqual(result.values, ["膏", "柯", "暨"])

    compositor.fixNodeSelectedCandidate("高科技", at: 3)
    result = compositor.walk()
    XCTAssertEqual(result.values, ["高科技"])
  }

  func testOverrideReset() throws {
    let compositor = Megrez.Compositor(
      lm: SimpleLM(input: strSampleData + "zhong1jiang3 終講 -11.0\n" + "jiang3jin1 槳襟 -11.0\n"))
    compositor.joinSeparator = ""
    compositor.insertReading("nian2")
    compositor.insertReading("zhong1")
    compositor.insertReading("jiang3")
    compositor.insertReading("jin1")
    var result = compositor.walk()
    XCTAssertEqual(result.values, ["年中", "獎金"])

    compositor.fixNodeSelectedCandidate("終講", at: 2)
    result = compositor.walk()
    XCTAssertEqual(result.values, ["年", "終講", "金"])

    compositor.fixNodeSelectedCandidate("槳襟", at: 3)
    result = compositor.walk()
    XCTAssertEqual(result.values, ["年中", "槳襟"])

    compositor.fixNodeSelectedCandidate("年終", at: 1)
    result = compositor.walk()
    XCTAssertEqual(result.values, ["年終", "槳襟"])
  }

  func testCandidateDisambiguation() throws {
    let compositor = Megrez.Compositor(lm: SimpleLM(input: strEmojiSampleData))
    compositor.joinSeparator = ""
    compositor.insertReading("gao1")
    compositor.insertReading("re4")
    compositor.insertReading("huo3")
    compositor.insertReading("yan4")
    compositor.insertReading("wei2")
    compositor.insertReading("xian3")
    var result = compositor.walk()
    XCTAssertEqual(result.values, ["高熱", "火焰", "危險"])

    compositor.fixNodeSelectedCandidatePair(.init(key: "huo3", value: "🔥"), at: 2)
    result = compositor.walk()
    XCTAssertEqual(result.values, ["高熱", "🔥", "焰", "危險"])

    compositor.fixNodeSelectedCandidatePair(.init(key: "huo3yan4", value: "🔥"), at: 3)
    result = compositor.walk()
    XCTAssertEqual(result.values, ["高熱", "🔥", "危險"])
  }

  func testStressBenchmark_MachineGun() throws {
    // 測試結果發現：只敲入完全雷同的某個漢字的話，想保證使用體驗就得讓一個組字區最多塞 20 字。
    // 但是呢，日常敲字都是在敲人話，不會出現這種情形，所以組字區內塞 40 字都沒問題。
    // 天權星引擎目前暫時沒有條件引入 Gramambular 2 的繁天頂（Vertex）算法，只能先這樣了。
    // 竊以為「讓組字區內容無限擴張」是個偽需求，畢竟組字區太長了的話編輯起來也很麻煩。
    NSLog("// Stress test preparation begins.")
    let compositor = Megrez.Compositor(lm: SimpleLM(input: strStressData))
    for _ in 0..<20 {  // 這個測試最多只能塞 20 字，否則會慢死。
      compositor.insertReading("yi1")
    }
    NSLog("// Stress test started.")
    let startTime = CFAbsoluteTimeGetCurrent()
    _ = compositor.walk()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    NSLog("// Stress test elapsed: \(timeElapsed)s.")
  }

  func testStressBenchmark_SpeakLikeAHuman() throws {
    // 與前一個測試相同，但這次測試的是正常人講話。可以看到在這種情況下目前的算法還是比較耐操的。
    NSLog("// Stress test preparation begins.")
    let compositor = Megrez.Compositor(lm: SimpleLM(input: strSampleData))
    let testMaterial: [String] = ["gao1", "ke1", "ji4", "gong1", "si1", "de5", "nian2", "zhong1", "jiang3", "jin1"]
    for _ in 0..<114 {  // 都敲出第一個野獸常數了，再不夠用就不像話了。
      for neta in testMaterial {
        compositor.insertReading(neta)
      }
    }
    NSLog("// Stress test started.")
    let startTime = CFAbsoluteTimeGetCurrent()
    _ = compositor.walk()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    NSLog("// Stress test elapsed: \(timeElapsed)s.")
  }
}

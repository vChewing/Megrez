// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Foundation
import Testing

@testable import Megrez

final class MegrezTests {
  @Test
  func test01_Span() throws {
    let langModel = SimpleLM(input: strSampleData)
    var span = Megrez.SpanUnit()
    let n1 = Megrez.Node(
      keyArray: ["gao1"], spanLength: 1, unigrams: langModel.unigramsFor(keyArray: ["gao1"])
    )
    let n3 = Megrez.Node(
      keyArray: ["gao1ke1ji4"], spanLength: 3,
      unigrams: langModel.unigramsFor(keyArray: ["gao1ke1ji4"])
    )
    #expect(span.maxLength == 0)
    span.addNode(node: n1)
    #expect(span.maxLength == 1)
    span.addNode(node: n3)
    #expect(span.maxLength == 3)
    #expect(span[1] == n1)
    #expect(span[2] == nil)
    #expect(span[3] == n3)
    #expect(span[Megrez.Compositor.maxSpanLength] == nil)
    span.removeAll()
    #expect(span.maxLength == 0)
    #expect(span[1] == nil)
    #expect(span[2] == nil)
    #expect(span[3] == nil)
    #expect(span[Megrez.Compositor.maxSpanLength] == nil)

    span.addNode(node: n1)
    span.addNode(node: n3)
    span.dropNodesOfOrBeyond(length: 2)
    #expect(span.maxLength == 1)
    #expect(span[1] == n1)
    #expect(span[2] == nil)
    #expect(span[3] == nil)
    span.dropNodesOfOrBeyond(length: 1)
    #expect(span.maxLength == 0)
    #expect(span[1] == nil)
    let n114514 = Megrez.Node(spanLength: 114_514)
    let spanAdded114514 = span.addNode(node: n114514)
    #expect(!spanAdded114514)
    #expect(nil == span[0])
    #expect(nil == span[Megrez.Compositor.maxSpanLength + 1])
  }

  @Test
  func test02_RankedLangModel() throws {
    class TestLM: LangModelProtocol {
      func hasUnigramsFor(keyArray: [String]) -> Bool { keyArray.joined() == "foo" }
      func unigramsFor(keyArray: [String]) -> [Megrez.Unigram] {
        keyArray.joined() == "foo"
          ? [
            .init(value: "middle", score: -5),
            .init(value: "highest", score: -2),
            .init(value: "lowest", score: -10)
          ]
          : .init()
      }
    }

    let lmRanked = Megrez.Compositor.LangModelRanked(withLM: TestLM())
    #expect(lmRanked.hasUnigramsFor(keyArray: ["foo"]))
    #expect(!lmRanked.hasUnigramsFor(keyArray: ["bar"]))
    #expect(lmRanked.unigramsFor(keyArray: ["bar"]).isEmpty)
    let unigrams = lmRanked.unigramsFor(keyArray: ["foo"])
    #expect(unigrams.count == 3)
    #expect(unigrams[0].value == "highest")
    #expect(unigrams[0].score == -2)
    #expect(unigrams[1].value == "middle")
    #expect(unigrams[1].score == -5)
    #expect(unigrams[2].value == "lowest")
    #expect(unigrams[2].score == -10)
  }

  @Test
  func test03_Compositor_BasicTests() throws {
    let compositor = Megrez.Compositor(with: MockLM()).asPtr
    #expect(compositor.separator == Megrez.Compositor.theSeparator)
    #expect(compositor.cursor == 0)
    #expect(compositor.length == 0)

    compositor.insertKey("a")
    #expect(compositor.cursor == 1)
    #expect(compositor.length == 1)
    #expect(compositor.spans.count == 1)
    #expect(compositor.spans[0].maxLength == 1)
    guard let zeroNode = compositor.spans[0][1] else {
      print("fuckme")
      return
    }
    #expect(zeroNode.keyArray.joined(separator: compositor.separator) == "a")

    compositor.dropKey(direction: .rear)
    #expect(compositor.cursor == 0)
    #expect(compositor.length == 0)
    #expect(compositor.spans.isEmpty)
  }

  @Test
  func test04_Compositor_InvalidOperations() throws {
    class TestLM: LangModelProtocol {
      func hasUnigramsFor(keyArray: [String]) -> Bool { keyArray == ["foo"] }
      func unigramsFor(keyArray: [String]) -> [Megrez.Unigram] {
        keyArray == ["foo"] ? [.init(value: "foo", score: -1)] : .init()
      }
    }
    let compositor = Megrez.Compositor(with: TestLM()).asPtr
    compositor.separator = ";"
    #expect(!compositor.insertKey("bar"))
    #expect(!compositor.insertKey(""))
    #expect(!compositor.insertKey(""))
    #expect(!compositor.dropKey(direction: .rear))
    #expect(!compositor.dropKey(direction: .front))

    #expect(compositor.insertKey("foo"))
    #expect(compositor.dropKey(direction: .rear))
    #expect(compositor.length == 0)
    #expect(compositor.insertKey("foo"))
    compositor.cursor = 0
    #expect(compositor.dropKey(direction: .front))
    #expect(compositor.length == 0)
  }

  @Test
  func test05_Compositor_DeleteToTheFrontOfCursor() throws {
    let compositor = Megrez.Compositor(with: MockLM()).asPtr
    compositor.insertKey("a")
    compositor.cursor = 0
    #expect(compositor.cursor == 0)
    #expect(compositor.length == 1)
    #expect(compositor.spans.count == 1)
    #expect(!compositor.dropKey(direction: .rear))
    #expect(compositor.cursor == 0)
    #expect(compositor.length == 1)
    #expect(compositor.spans.count == 1)
    #expect(compositor.dropKey(direction: .front))
    #expect(compositor.cursor == 0)
    #expect(compositor.length == 0)
    #expect(compositor.spans.isEmpty)
  }

  @Test
  func test06_Compositor_MultipleSpans() throws {
    let compositor = Megrez.Compositor(with: MockLM()).asPtr
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    #expect(compositor.cursor == 3)
    #expect(compositor.length == 3)
    #expect(compositor.spans.count == 3)
    #expect(compositor.spans[0].maxLength == 3)
    #expect(compositor.spans[0][1]?.keyArray.joined(separator: compositor.separator) == "a")
    #expect(compositor.spans[0][2]?.keyArray.joined(separator: compositor.separator) == "a;b")
    #expect(
      compositor.spans[0][3]?.keyArray.joined(separator: compositor.separator) == "a;b;c"
    )
    #expect(compositor.spans[1].maxLength == 2)
    #expect(compositor.spans[1][1]?.keyArray.joined(separator: compositor.separator) == "b")
    #expect(compositor.spans[1][2]?.keyArray.joined(separator: compositor.separator) == "b;c")
    #expect(compositor.spans[2].maxLength == 1)
    #expect(compositor.spans[2][1]?.keyArray.joined(separator: compositor.separator) == "c")
  }

  @Test
  func test07_Compositor_SpanDeletionFromFront() throws {
    let compositor = Megrez.Compositor(with: MockLM()).asPtr
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    #expect(!compositor.dropKey(direction: .front))
    #expect(compositor.dropKey(direction: .rear))
    #expect(compositor.cursor == 2)
    #expect(compositor.length == 2)
    #expect(compositor.spans.count == 2)
    #expect(compositor.spans[0].maxLength == 2)
    #expect(compositor.spans[0][1]?.keyArray.joined(separator: compositor.separator) == "a")
    #expect(compositor.spans[0][2]?.keyArray.joined(separator: compositor.separator) == "a;b")
    #expect(compositor.spans[1].maxLength == 1)
    #expect(compositor.spans[1][1]?.keyArray.joined(separator: compositor.separator) == "b")
  }

  @Test
  func test08_Compositor_SpanDeletionFromMiddle() throws {
    let compositor = Megrez.Compositor(with: MockLM()).asPtr
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.cursor = 2

    #expect(compositor.dropKey(direction: .rear))
    #expect(compositor.cursor == 1)
    #expect(compositor.length == 2)
    #expect(compositor.spans.count == 2)
    #expect(compositor.spans[0].maxLength == 2)
    #expect(compositor.spans[0][1]?.keyArray.joined(separator: compositor.separator) == "a")
    #expect(compositor.spans[0][2]?.keyArray.joined(separator: compositor.separator) == "a;c")
    #expect(compositor.spans[1].maxLength == 1)
    #expect(compositor.spans[1][1]?.keyArray.joined(separator: compositor.separator) == "c")

    compositor.clear()
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.cursor = 1

    #expect(compositor.dropKey(direction: .front))
    #expect(compositor.cursor == 1)
    #expect(compositor.length == 2)
    #expect(compositor.spans.count == 2)
    #expect(compositor.spans[0].maxLength == 2)
    #expect(compositor.spans[0][1]?.keyArray.joined(separator: compositor.separator) == "a")
    #expect(compositor.spans[0][2]?.keyArray.joined(separator: compositor.separator) == "a;c")
    #expect(compositor.spans[1].maxLength == 1)
    #expect(compositor.spans[1][1]?.keyArray.joined(separator: compositor.separator) == "c")
  }

  @Test
  func test09_Compositor_SpanDeletionFromRear() throws {
    let compositor = Megrez.Compositor(with: MockLM()).asPtr
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.cursor = 0

    #expect(!compositor.dropKey(direction: .rear))
    #expect(compositor.dropKey(direction: .front))
    #expect(compositor.cursor == 0)
    #expect(compositor.length == 2)
    #expect(compositor.spans.count == 2)
    #expect(compositor.spans[0].maxLength == 2)
    #expect(compositor.spans[0][1]?.keyArray.joined(separator: compositor.separator) == "b")
    #expect(compositor.spans[0][2]?.keyArray.joined(separator: compositor.separator) == "b;c")
    #expect(compositor.spans[1].maxLength == 1)
    #expect(compositor.spans[1][1]?.keyArray.joined(separator: compositor.separator) == "c")
  }

  @Test
  func test10_Compositor_SpanInsertion() throws {
    let compositor = Megrez.Compositor(with: MockLM()).asPtr
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.cursor = 1
    compositor.insertKey("X")

    #expect(compositor.cursor == 2)
    #expect(compositor.length == 4)
    #expect(compositor.spans.count == 4)
    #expect(compositor.spans[0].maxLength == 4)
    #expect(compositor.spans[0][1]?.keyArray.joined(separator: compositor.separator) == "a")
    #expect(compositor.spans[0][2]?.keyArray.joined(separator: compositor.separator) == "a;X")
    #expect(
      compositor.spans[0][3]?.keyArray.joined(separator: compositor.separator) == "a;X;b"
    )
    #expect(
      compositor.spans[0][4]?.keyArray.joined(separator: compositor.separator) == "a;X;b;c"
    )
    #expect(compositor.spans[1].maxLength == 3)
    #expect(compositor.spans[1][1]?.keyArray.joined(separator: compositor.separator) == "X")
    #expect(compositor.spans[1][2]?.keyArray.joined(separator: compositor.separator) == "X;b")
    #expect(
      compositor.spans[1][3]?.keyArray.joined(separator: compositor.separator) == "X;b;c"
    )
    #expect(compositor.spans[2].maxLength == 2)
    #expect(compositor.spans[2][1]?.keyArray.joined(separator: compositor.separator) == "b")
    #expect(compositor.spans[2][2]?.keyArray.joined(separator: compositor.separator) == "b;c")
    #expect(compositor.spans[3].maxLength == 1)
    #expect(compositor.spans[3][1]?.keyArray.joined(separator: compositor.separator) == "c")
  }

  @Test
  func test11_Compositor_LongGridDeletion() throws {
    let compositor = Megrez.Compositor(with: MockLM()).asPtr
    compositor.separator = ""
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.insertKey("d")
    compositor.insertKey("e")
    compositor.insertKey("f")
    compositor.insertKey("g")
    compositor.insertKey("h")
    compositor.insertKey("i")
    compositor.insertKey("j")
    compositor.insertKey("k")
    compositor.insertKey("l")
    compositor.insertKey("m")
    compositor.insertKey("n")
    compositor.cursor = 7
    #expect(compositor.dropKey(direction: .rear))
    #expect(compositor.cursor == 6)
    #expect(compositor.length == 13)
    #expect(compositor.spans.count == 13)
    #expect(
      compositor.spans[0][6]?.keyArray.joined(separator: compositor.separator) == "abcdef"
    )
    #expect(
      compositor.spans[1][6]?.keyArray.joined(separator: compositor.separator) == "bcdefh"
    )
    #expect(
      compositor.spans[1][5]?.keyArray.joined(separator: compositor.separator) == "bcdef"
    )
    #expect(
      compositor.spans[2][6]?.keyArray.joined(separator: compositor.separator) == "cdefhi"
    )
    #expect(
      compositor.spans[2][5]?.keyArray.joined(separator: compositor.separator) == "cdefh"
    )
    #expect(
      compositor.spans[3][6]?.keyArray.joined(separator: compositor.separator) == "defhij"
    )
    #expect(
      compositor.spans[4][6]?.keyArray.joined(separator: compositor.separator) == "efhijk"
    )
    #expect(
      compositor.spans[5][6]?.keyArray.joined(separator: compositor.separator) == "fhijkl"
    )
    #expect(
      compositor.spans[6][6]?.keyArray.joined(separator: compositor.separator) == "hijklm"
    )
    #expect(
      compositor.spans[7][6]?.keyArray.joined(separator: compositor.separator) == "ijklmn"
    )
    #expect(
      compositor.spans[8][5]?.keyArray.joined(separator: compositor.separator) == "jklmn"
    )
  }

  @Test
  func test12_Compositor_LongGridInsertion() throws {
    let compositor = Megrez.Compositor(with: MockLM()).asPtr
    compositor.separator = ""
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.insertKey("d")
    compositor.insertKey("e")
    compositor.insertKey("f")
    compositor.insertKey("g")
    compositor.insertKey("h")
    compositor.insertKey("i")
    compositor.insertKey("j")
    compositor.insertKey("k")
    compositor.insertKey("l")
    compositor.insertKey("m")
    compositor.insertKey("n")
    compositor.cursor = 7
    compositor.insertKey("X")
    #expect(compositor.cursor == 8)
    #expect(compositor.length == 15)
    #expect(compositor.spans.count == 15)
    #expect(
      compositor.spans[0][6]?.keyArray.joined(separator: compositor.separator) == "abcdef"
    )
    #expect(
      compositor.spans[1][6]?.keyArray.joined(separator: compositor.separator) == "bcdefg"
    )
    #expect(
      compositor.spans[2][6]?.keyArray.joined(separator: compositor.separator) == "cdefgX"
    )
    #expect(
      compositor.spans[3][6]?.keyArray.joined(separator: compositor.separator) == "defgXh"
    )
    #expect(
      compositor.spans[3][5]?.keyArray.joined(separator: compositor.separator) == "defgX"
    )
    #expect(
      compositor.spans[4][6]?.keyArray.joined(separator: compositor.separator) == "efgXhi"
    )
    #expect(
      compositor.spans[4][5]?.keyArray.joined(separator: compositor.separator) == "efgXh"
    )
    #expect(compositor.spans[4][4]?.keyArray.joined(separator: compositor.separator) == "efgX")
    #expect(compositor.spans[4][3]?.keyArray.joined(separator: compositor.separator) == "efg")
    #expect(
      compositor.spans[5][6]?.keyArray.joined(separator: compositor.separator) == "fgXhij"
    )
    #expect(
      compositor.spans[6][6]?.keyArray.joined(separator: compositor.separator) == "gXhijk"
    )
    #expect(
      compositor.spans[7][6]?.keyArray.joined(separator: compositor.separator) == "Xhijkl"
    )
    #expect(
      compositor.spans[8][6]?.keyArray.joined(separator: compositor.separator) == "hijklm"
    )
  }

  @Test
  func test13_Compositor_StressBench() throws {
    NSLog("// Stress test preparation begins.")
    let compositor = Megrez.Compositor(with: SimpleLM(input: strStressData)).asPtr
    (0 ..< 1919).forEach { _ in
      compositor.insertKey("yi")
    }
    NSLog("// Stress test started.")
    let startTime = CFAbsoluteTimeGetCurrent()
    compositor.walk()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    NSLog("// Stress test elapsed: \(timeElapsed)s.")
  }

  @Test
  func test14_Compositor_WordSegmentation() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strSampleData, swapKeyValue: true))
      .asPtr
    compositor.separator = ""
    "高科技公司的年終獎金".forEach { i in
      compositor.insertKey(i.description)
    }
    let result = compositor.walk()
    #expect(result.joinedKeys(by: "") == ["高科技", "公司", "的", "年終", "獎金"])
  }

  @Test
  func test15_Compositor_InputTestAndCursorJump() throws {
    var compositor = Megrez.Compositor(with: SimpleLM(input: strSampleData)).asPtr
    compositor.separator = ""
    compositor.insertKey("gao1")
    compositor.walk()
    compositor.insertKey("ji4")
    compositor.walk()
    compositor.cursor = 1
    compositor.insertKey("ke1")
    compositor.walk()
    compositor.cursor = 0
    compositor.dropKey(direction: .front)
    compositor.walk()
    compositor.insertKey("gao1")
    compositor.walk()
    compositor.cursor = compositor.length
    compositor.insertKey("gong1")
    compositor.walk()
    compositor.insertKey("si1")
    compositor.walk()
    compositor.insertKey("de5")
    compositor.walk()
    compositor.insertKey("nian2")
    compositor.walk()
    compositor.insertKey("zhong1")
    compositor.walk()
    compositor.insertKey("jiang3")
    compositor.walk()
    compositor.insertKey("jin1")
    var result = compositor.walk()
    #expect(result.values == ["高科技", "公司", "的", "年中", "獎金"])
    #expect(compositor.length == 10)
    compositor.cursor = 7
    let candidates = compositor.fetchCandidates(at: compositor.cursor).map(\.value)
    #expect(candidates.contains("年中"))
    #expect(candidates.contains("年終"))
    #expect(candidates.contains("中"))
    #expect(candidates.contains("鍾"))
    #expect(compositor.overrideCandidateLiteral("年終", at: 7))
    result = compositor.walk()
    #expect(result.values == ["高科技", "公司", "的", "年終", "獎金"])
    let candidatesBeginAt = compositor.fetchCandidates(at: 3, filter: .beginAt).map(\.value)
    let candidatesEndAt = compositor.fetchCandidates(at: 3, filter: .endAt).map(\.value)
    #expect(!candidatesBeginAt.contains("濟公"))
    #expect(!candidatesEndAt.contains("公司"))
    // Test cursor jump.
    compositor.cursor = 8
    #expect(compositor.jumpCursorBySpan(to: .rear))
    #expect(compositor.cursor == 6)
    #expect(compositor.jumpCursorBySpan(to: .rear))
    #expect(compositor.cursor == 5)
    #expect(compositor.jumpCursorBySpan(to: .rear))
    #expect(compositor.cursor == 3)
    #expect(compositor.jumpCursorBySpan(to: .rear))
    #expect(compositor.cursor == 0)
    #expect(!compositor.jumpCursorBySpan(to: .rear))
    #expect(compositor.cursor == 0)
    #expect(compositor.jumpCursorBySpan(to: .front))
    #expect(compositor.cursor == 3)
    #expect(compositor.jumpCursorBySpan(to: .front))
    #expect(compositor.cursor == 5)
    #expect(compositor.jumpCursorBySpan(to: .front))
    #expect(compositor.cursor == 6)
    #expect(compositor.jumpCursorBySpan(to: .front))
    #expect(compositor.cursor == 8)
    #expect(compositor.jumpCursorBySpan(to: .front))
    #expect(compositor.cursor == 10)
    #expect(!compositor.jumpCursorBySpan(to: .front))
    #expect(compositor.cursor == 10)
    // Test dumpDOT.
    let expectedDumpDOT =
      "digraph {\ngraph [ rankdir=LR ];\nBOS;\nBOS -> 高;\n高;\n高 -> 科;\n高 -> 科技;\nBOS -> 高科技;\n高科技;\n高科技 -> 工;\n高科技 -> 公司;\n科;\n科 -> 際;\n科 -> 濟公;\n科技;\n科技 -> 工;\n科技 -> 公司;\n際;\n際 -> 工;\n際 -> 公司;\n濟公;\n濟公 -> 斯;\n工;\n工 -> 斯;\n公司;\n公司 -> 的;\n斯;\n斯 -> 的;\n的;\n的 -> 年;\n的 -> 年終;\n年;\n年 -> 中;\n年終;\n年終 -> 獎;\n年終 -> 獎金;\n中;\n中 -> 獎;\n中 -> 獎金;\n獎;\n獎 -> 金;\n獎金;\n獎金 -> EOS;\n金;\n金 -> EOS;\nEOS;\n}\n"
    #expect(compositor.dumpDOT == expectedDumpDOT)
    // Extra tests example: Litch.
    compositor = Megrez.Compositor(with: SimpleLM(input: strSampleDataLitch)).asPtr
    compositor.separator = ""
    compositor.clear()
    compositor.insertKey("nai3")
    compositor.insertKey("ji1")
    result = compositor.walk()
    #expect(result.values == ["荔枝"])
    #expect(compositor.overrideCandidateLiteral("雞", at: 1))
    result = compositor.walk()
    #expect(result.values == ["乃", "雞"])
  }

  @Test
  func test16_Compositor_InputTest2() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strSampleData)).asPtr
    compositor.separator = ""
    compositor.insertKey("gao1")
    compositor.insertKey("ke1")
    compositor.insertKey("ji4")
    var result = compositor.walk()
    #expect(result.values == ["高科技"])
    compositor.insertKey("gong1")
    compositor.insertKey("si1")
    result = compositor.walk()
    #expect(result.values == ["高科技", "公司"])
  }

  @Test
  func test17_Compositor_OverrideOverlappingNodes() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strSampleData)).asPtr
    compositor.separator = ""
    compositor.insertKey("gao1")
    compositor.insertKey("ke1")
    compositor.insertKey("ji4")
    var result = compositor.walk()
    #expect(result.values == ["高科技"])
    compositor.cursor = 0
    #expect(compositor.overrideCandidateLiteral("膏", at: compositor.cursor))
    result = compositor.walk()
    #expect(result.values == ["膏", "科技"])
    #expect(compositor.overrideCandidateLiteral("高科技", at: 1))
    result = compositor.walk()
    #expect(result.values == ["高科技"])
    #expect(compositor.overrideCandidateLiteral("膏", at: 0))
    result = compositor.walk()
    #expect(result.values == ["膏", "科技"])

    #expect(compositor.overrideCandidateLiteral("柯", at: 1))
    result = compositor.walk()
    #expect(result.values == ["膏", "柯", "際"])

    #expect(compositor.overrideCandidateLiteral("暨", at: 2))
    result = compositor.walk()
    #expect(result.values == ["膏", "柯", "暨"])

    #expect(compositor.overrideCandidateLiteral("高科技", at: 3))
    result = compositor.walk()
    #expect(result.values == ["高科技"])
  }

  @Test
  func test18_Compositor_OverrideReset() throws {
    let compositor = Megrez.Compositor(
      with: SimpleLM(input: strSampleData + "zhong1jiang3 終講 -11.0\n" + "jiang3jin1 槳襟 -11.0\n")
    ).asPtr
    compositor.separator = ""
    compositor.insertKey("nian2")
    compositor.insertKey("zhong1")
    compositor.insertKey("jiang3")
    compositor.insertKey("jin1")
    var result = compositor.walk()
    #expect(result.values == ["年中", "獎金"])

    #expect(compositor.overrideCandidateLiteral("終講", at: 1))
    result = compositor.walk()
    #expect(result.values == ["年", "終講", "金"])

    #expect(compositor.overrideCandidateLiteral("槳襟", at: 2))
    result = compositor.walk()
    #expect(result.values == ["年中", "槳襟"])

    #expect(compositor.overrideCandidateLiteral("年終", at: 0))
    result = compositor.walk()
    #expect(result.values == ["年終", "槳襟"])
  }

  @Test
  func test19_Compositor_CandidateDisambiguation() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strEmojiSampleData)).asPtr
    compositor.separator = ""
    compositor.insertKey("gao1")
    compositor.insertKey("re4")
    compositor.insertKey("huo3")
    compositor.insertKey("yan4")
    compositor.insertKey("wei2")
    compositor.insertKey("xian3")
    var result = compositor.walk()
    #expect(result.values == ["高熱", "火焰", "危險"])
    let location = 2

    #expect(compositor.overrideCandidate(.init(keyArray: ["huo3"], value: "🔥"), at: location))
    result = compositor.walk()
    #expect(result.values == ["高熱", "🔥", "焰", "危險"])

    #expect(compositor.overrideCandidate(
      .init(keyArray: ["huo3", "yan4"], value: "🔥"),
      at: location
    ))
    result = compositor.walk()
    #expect(result.values == ["高熱", "🔥", "危險"])
  }

  @Test
  func test20_Compositor_UpdateUnigramData() throws {
    let theLM = SimpleLM(input: strSampleData)
    let compositor = Megrez.Compositor(with: theLM).asPtr
    compositor.separator = ""
    compositor.insertKey("nian2")
    compositor.insertKey("zhong1")
    compositor.insertKey("jiang3")
    compositor.insertKey("jin1")
    let oldResult = compositor.walk().values.joined()
    print(oldResult)
    theLM.trim(key: "nian2zhong1", value: "年中")
    compositor.update(updateExisting: true)
    let newResult = compositor.walk().values.joined()
    print(newResult)
    #expect([oldResult, newResult] == ["年中獎金", "年終獎金"])
    compositor.cursor = 4
    compositor.dropKey(direction: .rear)
    compositor.dropKey(direction: .rear)
    theLM.trim(key: "nian2zhong1", value: "年終")
    compositor.update(updateExisting: true)
    let newResult2 = compositor.walk().values
    print(newResult2)
    #expect(newResult2 == ["年", "中"])
  }

  @Test
  func test21_Compositor_HardCopy() throws {
    let theLM = SimpleLM(input: strSampleData)
    let rawReadings = "gao1 ke1 ji4 gong1 si1 de5 nian2 zhong1 jiang3 jin1"
    let compositorA = Megrez.Compositor(with: theLM).asPtr
    rawReadings.split(separator: " ").forEach { key in
      compositorA.insertKey(key.description)
    }
    let compositorB = compositorA.obj.hardCopy.asPtr
    let resultA = compositorA.walk()
    let resultB = compositorB.walk()
    #expect(resultA == resultB)
  }

  @Test
  func test22_Compositor_SanitizingNodeCrossing() throws {
    let theLM = SimpleLM(input: strSampleData)
    let rawReadings = "ke1 ke1"
    let compositor = Megrez.Compositor(with: theLM).asPtr
    rawReadings.split(separator: " ").forEach { key in
      compositor.insertKey(key.description)
    }
    var a = compositor.fetchCandidates(at: 1, filter: .beginAt).map(\.keyArray.count).max() ?? 0
    var b = compositor.fetchCandidates(at: 1, filter: .endAt).map(\.keyArray.count).max() ?? 0
    var c = compositor.fetchCandidates(at: 0, filter: .beginAt).map(\.keyArray.count).max() ?? 0
    var d = compositor.fetchCandidates(at: 2, filter: .endAt).map(\.keyArray.count).max() ?? 0
    #expect("\(a) \(b) \(c) \(d)" == "1 1 2 2")
    compositor.cursor = compositor.length
    compositor.insertKey("jin1")
    a = compositor.fetchCandidates(at: 1, filter: .beginAt).map(\.keyArray.count).max() ?? 0
    b = compositor.fetchCandidates(at: 1, filter: .endAt).map(\.keyArray.count).max() ?? 0
    c = compositor.fetchCandidates(at: 0, filter: .beginAt).map(\.keyArray.count).max() ?? 0
    d = compositor.fetchCandidates(at: 2, filter: .endAt).map(\.keyArray.count).max() ?? 0
    #expect("\(a) \(b) \(c) \(d)" == "1 1 2 2")
  }

  @Test
  func test23_Compositor_CheckGetCandidates() throws {
    let theLM = SimpleLM(input: strSampleData)
    let rawReadings = "gao1 ke1 ji4 gong1 si1 de5 nian2 zhong1 jiang3 jin1"
    let compositor = Megrez.Compositor(with: theLM).asPtr
    rawReadings.split(separator: " ").forEach { key in
      compositor.insertKey(key.description)
    }
    var stack1A = [String]()
    var stack1B = [String]()
    var stack2A = [String]()
    var stack2B = [String]()
    for i in 0 ... compositor.keys.count {
      stack1A
        .append(
          compositor.fetchCandidates(at: i, filter: .beginAt).map(\.value)
            .joined(separator: "-")
        )
      stack1B
        .append(
          compositor.fetchCandidates(at: i, filter: .endAt).map(\.value)
            .joined(separator: "-")
        )
      stack2A
        .append(
          compositor.fetchCandidatesDeprecated(at: i, filter: .beginAt).map(\.value)
            .joined(separator: "-")
        )
      stack2B
        .append(
          compositor.fetchCandidatesDeprecated(at: i, filter: .endAt).map(\.value)
            .joined(separator: "-")
        )
    }
    stack1B.removeFirst()
    stack2B.removeLast()
    #expect(stack1A == stack2A)
    #expect(stack1B == stack2B)
  }
}

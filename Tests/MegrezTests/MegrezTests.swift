// Swiftified by (c) 2022 and onwards The vChewing Project (MIT License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Cocoa
import XCTest

@testable import Megrez

final class MegrezTests: XCTestCase {
  func testSpan() throws {
    let langModel = SimpleLM(input: strSampleData)
    let span = Megrez.Compositor.Span()
    let n1 = Megrez.Compositor.Node(keyArray: ["gao1"], spanLength: 1, unigrams: langModel.unigramsFor(key: "gao1"))
    let n3 = Megrez.Compositor.Node(
      keyArray: ["gao1ke1ji4"], spanLength: 3, unigrams: langModel.unigramsFor(key: "gao1ke1ji4")
    )
    XCTAssertEqual(span.maxLength, 0)
    span.append(node: n1)
    XCTAssertEqual(span.maxLength, 1)
    span.append(node: n3)
    XCTAssertEqual(span.maxLength, 3)
    XCTAssertEqual(span.nodeOf(length: 1), n1)
    XCTAssertEqual(span.nodeOf(length: 2), nil)
    XCTAssertEqual(span.nodeOf(length: 3), n3)
    XCTAssertEqual(span.nodeOf(length: Megrez.Compositor.maxSpanLength), nil)
    span.clear()
    XCTAssertEqual(span.maxLength, 0)
    XCTAssertEqual(span.nodeOf(length: 1), nil)
    XCTAssertEqual(span.nodeOf(length: 2), nil)
    XCTAssertEqual(span.nodeOf(length: 3), nil)
    XCTAssertEqual(span.nodeOf(length: Megrez.Compositor.maxSpanLength), nil)

    span.append(node: n1)
    span.append(node: n3)
    span.dropNodesOfOrBeyond(length: 2)
    XCTAssertEqual(span.maxLength, 1)
    XCTAssertEqual(span.nodeOf(length: 1), n1)
    XCTAssertEqual(span.nodeOf(length: 2), nil)
    XCTAssertEqual(span.nodeOf(length: 3), nil)
    span.dropNodesOfOrBeyond(length: 1)
    XCTAssertEqual(span.maxLength, 0)
    XCTAssertEqual(span.nodeOf(length: 1), nil)
    let n114514 = Megrez.Compositor.Node(spanLength: 114_514)
    XCTAssertFalse(span.append(node: n114514))
    XCTAssertNil(span.nodeOf(length: 0))
    XCTAssertNil(span.nodeOf(length: Megrez.Compositor.maxSpanLength + 1))
  }

  func testRankedLangModel() throws {
    class TestLM: LangModelProtocol {
      func hasUnigramsFor(key: String) -> Bool { key == "foo" }
      func unigramsFor(key: String) -> [Megrez.Unigram] {
        key == "foo"
          ? [.init(value: "middle", score: -5), .init(value: "highest", score: -2), .init(value: "lowest", score: -10)]
          : .init()
      }
    }

    let lmRanked = Megrez.Compositor.LangModelRanked(withLM: TestLM())
    XCTAssertTrue(lmRanked.hasUnigramsFor(key: "foo"))
    XCTAssertFalse(lmRanked.hasUnigramsFor(key: "bar"))
    XCTAssertTrue(lmRanked.unigramsFor(key: "bar").isEmpty)
    let unigrams = lmRanked.unigramsFor(key: "foo")
    XCTAssertEqual(unigrams.count, 3)
    XCTAssertEqual(unigrams[0].value, "highest")
    XCTAssertEqual(unigrams[0].score, -2)
    XCTAssertEqual(unigrams[1].value, "middle")
    XCTAssertEqual(unigrams[1].score, -5)
    XCTAssertEqual(unigrams[2].value, "lowest")
    XCTAssertEqual(unigrams[2].score, -10)
  }

  func testCompositor_BasicTests() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    XCTAssertEqual(compositor.separator, Megrez.Compositor.kDefaultSeparator)
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 0)

    compositor.insertKey("a")
    XCTAssertEqual(compositor.cursor, 1)
    XCTAssertEqual(compositor.length, 1)
    XCTAssertEqual(compositor.spans.count, 1)
    XCTAssertEqual(compositor.spans[0].maxLength, 1)
    guard let zeroNode = compositor.spans[0].nodeOf(length: 1) else {
      print("fuckme")
      return
    }
    XCTAssertEqual(zeroNode.key, "a")

    compositor.dropKey(direction: .rear)
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.spans.count, 0)
  }

  func testCompositor_InvalidOperations() throws {
    class TestLM: LangModelProtocol {
      func hasUnigramsFor(key: String) -> Bool { key == "foo" }
      func unigramsFor(key: String) -> [Megrez.Unigram] {
        key == "foo" ? [.init(value: "foo", score: -1)] : .init()
      }
    }

    let compositor = Megrez.Compositor(with: TestLM())
    compositor.separator = ";"
    XCTAssertFalse(compositor.insertKey("bar"))
    XCTAssertFalse(compositor.insertKey(""))
    XCTAssertFalse(compositor.insertKey(""))
    XCTAssertFalse(compositor.dropKey(direction: .rear))
    XCTAssertFalse(compositor.dropKey(direction: .front))

    XCTAssertTrue(compositor.insertKey("foo"))
    XCTAssertTrue(compositor.dropKey(direction: .rear))
    XCTAssertEqual(compositor.length, 0)
    XCTAssertTrue(compositor.insertKey("foo"))
    compositor.cursor = 0
    XCTAssertTrue(compositor.dropKey(direction: .front))
    XCTAssertEqual(compositor.length, 0)
  }

  func testCompositor_DeleteToTheFrontOfCursor() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.insertKey("a")
    compositor.cursor = 0
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 1)
    XCTAssertEqual(compositor.spans.count, 1)
    XCTAssertFalse(compositor.dropKey(direction: .rear))
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 1)
    XCTAssertTrue(compositor.dropKey(direction: .front))
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 0)
    XCTAssertEqual(compositor.spans.count, 0)
  }

  func testCompositor_MultipleSpans() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    XCTAssertEqual(compositor.cursor, 3)
    XCTAssertEqual(compositor.length, 3)
    XCTAssertEqual(compositor.spans.count, 3)
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

  func testCompositor_SpanDeletionFromFront() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    XCTAssertFalse(compositor.dropKey(direction: .front))
    XCTAssertTrue(compositor.dropKey(direction: .rear))
    XCTAssertEqual(compositor.cursor, 2)
    XCTAssertEqual(compositor.length, 2)
    XCTAssertEqual(compositor.spans.count, 2)
    XCTAssertEqual(compositor.spans[0].maxLength, 2)
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 1)?.key, "a")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 2)?.key, "a;b")
    XCTAssertEqual(compositor.spans[1].maxLength, 1)
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 1)?.key, "b")
  }

  func testCompositor_SpanDeletionFromMiddle() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.cursor = 2

    XCTAssertTrue(compositor.dropKey(direction: .rear))
    XCTAssertEqual(compositor.cursor, 1)
    XCTAssertEqual(compositor.length, 2)
    XCTAssertEqual(compositor.spans.count, 2)
    XCTAssertEqual(compositor.spans[0].maxLength, 2)
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 1)?.key, "a")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 2)?.key, "a;c")
    XCTAssertEqual(compositor.spans[1].maxLength, 1)
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 1)?.key, "c")

    compositor.clear()
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.cursor = 1

    XCTAssertTrue(compositor.dropKey(direction: .front))
    XCTAssertEqual(compositor.cursor, 1)
    XCTAssertEqual(compositor.length, 2)
    XCTAssertEqual(compositor.spans.count, 2)
    XCTAssertEqual(compositor.spans[0].maxLength, 2)
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 1)?.key, "a")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 2)?.key, "a;c")
    XCTAssertEqual(compositor.spans[1].maxLength, 1)
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 1)?.key, "c")
  }

  func testCompositor_SpanDeletionFromRear() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.cursor = 0

    XCTAssertFalse(compositor.dropKey(direction: .rear))
    XCTAssertTrue(compositor.dropKey(direction: .front))
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertEqual(compositor.length, 2)
    XCTAssertEqual(compositor.spans.count, 2)
    XCTAssertEqual(compositor.spans[0].maxLength, 2)
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 1)?.key, "b")
    XCTAssertEqual(compositor.spans[0].nodeOf(length: 2)?.key, "b;c")
    XCTAssertEqual(compositor.spans[1].maxLength, 1)
    XCTAssertEqual(compositor.spans[1].nodeOf(length: 1)?.key, "c")
  }

  func testCompositor_SpanInsertion() throws {
    let compositor = Megrez.Compositor(with: MockLM())
    compositor.separator = ";"
    compositor.insertKey("a")
    compositor.insertKey("b")
    compositor.insertKey("c")
    compositor.cursor = 1
    compositor.insertKey("X")

    XCTAssertEqual(compositor.cursor, 2)
    XCTAssertEqual(compositor.length, 4)
    XCTAssertEqual(compositor.spans.count, 4)
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

  func testCompositor_LongGridDeletion() throws {
    let compositor = Megrez.Compositor(with: MockLM())
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
    XCTAssertTrue(compositor.dropKey(direction: .rear))
    XCTAssertEqual(compositor.cursor, 6)
    XCTAssertEqual(compositor.length, 13)
    XCTAssertEqual(compositor.spans.count, 13)
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

  func testCompositor_LongGridInsertion() throws {
    let compositor = Megrez.Compositor(with: MockLM())
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
    XCTAssertEqual(compositor.cursor, 8)
    XCTAssertEqual(compositor.length, 15)
    XCTAssertEqual(compositor.spans.count, 15)
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

  func testCompositor_StressBench() throws {
    NSLog("// Stress test preparation begins.")
    let compositor = Megrez.Compositor(with: SimpleLM(input: strStressData))
    for _ in 0..<1919 {
      compositor.insertKey("yi")
    }
    NSLog("// Stress test started.")
    let startTime = CFAbsoluteTimeGetCurrent()
    compositor.walk()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    NSLog("// Stress test elapsed: \(timeElapsed)s.")
  }

  func testCompositor_WordSegmentation() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strSampleData, swapKeyValue: true))
    compositor.separator = ""
    for i in "高科技公司的年終獎金" {
      compositor.insertKey(String(i))
    }
    let result = compositor.walk().0
    XCTAssertEqual(result.keys, ["高科技", "公司", "的", "年終", "獎金"])
  }

  func testCompositor_InputTestAndCursorJump() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strSampleData))
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
    var result = compositor.walk().0
    XCTAssertEqual(result.values, ["高科技", "公司", "的", "年中", "獎金"])
    XCTAssertEqual(compositor.length, 10)
    compositor.cursor = 7
    let candidates = compositor.fetchCandidates(at: compositor.cursor).map(\.value)
    XCTAssertTrue(candidates.contains("年中"))
    XCTAssertTrue(candidates.contains("年終"))
    XCTAssertTrue(candidates.contains("中"))
    XCTAssertTrue(candidates.contains("鍾"))
    XCTAssertTrue(compositor.overrideCandidateLiteral("年終", at: 7))
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["高科技", "公司", "的", "年終", "獎金"])
    let candidatesAll = compositor.fetchCandidates(at: 3).map(\.value)
    let candidatesBeginAt = compositor.fetchCandidates(at: 3, filter: .beginAt).map(\.value)
    let candidatesEndAt = compositor.fetchCandidates(at: 3, filter: .endAt).map(\.value)
    XCTAssertFalse(candidatesBeginAt.contains("濟公"))
    XCTAssertFalse(candidatesEndAt.contains("公司"))
    print(candidatesAll.joined(separator: ", "))
    print(candidatesBeginAt.joined(separator: ", "))
    print(candidatesEndAt.joined(separator: ", "))
    compositor.cursor = 8
    print(compositor.cursorRegionMap)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .rear))
    XCTAssertEqual(compositor.cursor, 6)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .rear))
    XCTAssertEqual(compositor.cursor, 5)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .rear))
    XCTAssertEqual(compositor.cursor, 3)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .rear))
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertFalse(compositor.jumpCursorBySpan(to: .rear))
    XCTAssertEqual(compositor.cursor, 0)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .front))
    XCTAssertEqual(compositor.cursor, 3)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .front))
    XCTAssertEqual(compositor.cursor, 5)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .front))
    XCTAssertEqual(compositor.cursor, 6)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .front))
    XCTAssertEqual(compositor.cursor, 8)
    XCTAssertTrue(compositor.jumpCursorBySpan(to: .front))
    XCTAssertEqual(compositor.cursor, 10)
    XCTAssertFalse(compositor.jumpCursorBySpan(to: .front))
    XCTAssertEqual(compositor.cursor, 10)
  }

  func testCompositor_InputTest2() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strSampleData))
    compositor.separator = ""
    compositor.insertKey("gao1")
    compositor.insertKey("ke1")
    compositor.insertKey("ji4")
    var result = compositor.walk().0
    XCTAssertEqual(result.values, ["高科技"])
    compositor.insertKey("gong1")
    compositor.insertKey("si1")
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["高科技", "公司"])
  }

  func testCompositor_OverrideOverlappingNodes() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strSampleData))
    compositor.separator = ""
    compositor.insertKey("gao1")
    compositor.insertKey("ke1")
    compositor.insertKey("ji4")
    var result = compositor.walk().0
    XCTAssertEqual(result.values, ["高科技"])
    compositor.cursor = 0
    XCTAssertTrue(compositor.overrideCandidateLiteral("膏", at: compositor.cursor))
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["膏", "科技"])
    XCTAssertTrue(compositor.overrideCandidateLiteral("高科技", at: 1))
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["高科技"])
    XCTAssertTrue(compositor.overrideCandidateLiteral("膏", at: 0))
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["膏", "科技"])

    XCTAssertTrue(compositor.overrideCandidateLiteral("柯", at: 1))
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["膏", "柯", "際"])

    XCTAssertTrue(compositor.overrideCandidateLiteral("暨", at: 2))
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["膏", "柯", "暨"])

    XCTAssertTrue(compositor.overrideCandidateLiteral("高科技", at: 3))
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["高科技"])
  }

  func testCompositor_OverrideReset() throws {
    let compositor = Megrez.Compositor(
      with: SimpleLM(input: strSampleData + "zhong1jiang3 終講 -11.0\n" + "jiang3jin1 槳襟 -11.0\n"))
    compositor.separator = ""
    compositor.insertKey("nian2")
    compositor.insertKey("zhong1")
    compositor.insertKey("jiang3")
    compositor.insertKey("jin1")
    var result = compositor.walk().0
    XCTAssertEqual(result.values, ["年中", "獎金"])

    XCTAssertTrue(compositor.overrideCandidateLiteral("終講", at: 1))
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["年", "終講", "金"])

    XCTAssertTrue(compositor.overrideCandidateLiteral("槳襟", at: 2))
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["年中", "槳襟"])

    XCTAssertTrue(compositor.overrideCandidateLiteral("年終", at: 0))
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["年終", "槳襟"])
  }

  func testCompositor_CandidateDisambiguation() throws {
    let compositor = Megrez.Compositor(with: SimpleLM(input: strEmojiSampleData))
    compositor.separator = ""
    compositor.insertKey("gao1")
    compositor.insertKey("re4")
    compositor.insertKey("huo3")
    compositor.insertKey("yan4")
    compositor.insertKey("wei2")
    compositor.insertKey("xian3")
    var result = compositor.walk().0
    XCTAssertEqual(result.values, ["高熱", "火焰", "危險"])
    let location = 2

    XCTAssertTrue(compositor.overrideCandidate(.init(key: "huo3", value: "🔥"), at: location))
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["高熱", "🔥", "焰", "危險"])

    XCTAssertTrue(compositor.overrideCandidate(.init(key: "huo3yan4", value: "🔥"), at: location))
    result = compositor.walk().0
    XCTAssertEqual(result.values, ["高熱", "🔥", "危險"])
  }
}

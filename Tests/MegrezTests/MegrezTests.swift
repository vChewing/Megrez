import OrderedCollections
import XCTest

@testable import Megrez

final class MegrezTests: XCTestCase {
	// MARK: - Input Test

	func testInput() throws {
		print("// 開始測試語言文字輸入處理")
		let lmTestInput = SimpleLM(input: strSampleData)
		let builder = Megrez.BlockReadingBuilder(lm: lmTestInput)

		builder.insertReadingAtCursor(reading: "gao1")
		builder.insertReadingAtCursor(reading: "ji4")
		builder.setCursorIndex(newIndex: 1)
		builder.insertReadingAtCursor(reading: "ke1")
		builder.setCursorIndex(newIndex: 0)
		builder.deleteReadingAfterCursor()
		builder.insertReadingAtCursor(reading: "gao1")
		builder.setCursorIndex(newIndex: builder.length())
		builder.insertReadingAtCursor(reading: "gong1")
		builder.insertReadingAtCursor(reading: "si1")
		builder.insertReadingAtCursor(reading: "de5")
		builder.insertReadingAtCursor(reading: "nian2")
		builder.insertReadingAtCursor(reading: "zhong1")
		builder.insertReadingAtCursor(reading: "jiang3")
		builder.insertReadingAtCursor(reading: "jin1")
		builder.insertReadingAtCursor(reading: "ni3")
		builder.insertReadingAtCursor(reading: "zhe4")
		builder.insertReadingAtCursor(reading: "yang4")

		
		let walker = Megrez.Walker(grid: builder.grid())

		var walked: [Megrez.NodeAnchor] = walker.reverseWalk(at: builder.grid().width(), score: 0.0)
		walked = walked.reversed()

		var composed: [String] = []
		for phrase in walked {
			if let value = phrase.node?.currentKeyValue().value {
				composed.append(value)
			}
		}
		print(composed)
		let correctResult = ["高科技", "公司", "的", "年中", "獎金", "你", "這樣"]
		print(" - 上述列印結果理應於下面這行一致：")
		print(correctResult)

		XCTAssertEqual(composed, correctResult)
	}

	// MARK: - Test Word Segmentation

	func testWordSegmentation() throws {
		print("// 開始測試語句分節處理")
		let lmTestSegmentation = SimpleLM(input: strSampleData, swapKeyValue: true)
		let builder = Megrez.BlockReadingBuilder(lm: lmTestSegmentation)

		builder.insertReadingAtCursor(reading: "高")
		builder.insertReadingAtCursor(reading: "科")
		builder.insertReadingAtCursor(reading: "技")
		builder.insertReadingAtCursor(reading: "公")
		builder.insertReadingAtCursor(reading: "司")
		builder.insertReadingAtCursor(reading: "的")
		builder.insertReadingAtCursor(reading: "年")
		builder.insertReadingAtCursor(reading: "終")
		builder.insertReadingAtCursor(reading: "獎")
		builder.insertReadingAtCursor(reading: "金")

		let walker = Megrez.Walker(grid: builder.grid())
		var walked: [Megrez.NodeAnchor] = walker.reverseWalk(at: builder.grid().width(), score: 0.0)
		walked = walked.reversed()

		var segmented: [String] = []
		for phrase in walked {
			if let key = phrase.node?.currentKeyValue().key {
				segmented.append(key)
			}
		}
		print(segmented)
		let correctResult = ["高科技", "公司", "的", "年終", "獎金"]
		print(" - 上述列印結果理應於下面這行一致：")
		print(correctResult)

		XCTAssertEqual(segmented, correctResult)
	}
}

// MARK: - 用以測試的型別

class SimpleLM: Megrez.LanguageModel {
	var mutDatabase: OrderedDictionary<String, [Megrez.Unigram]> = [:]

	init(input: String, swapKeyValue: Bool = false) {
		super.init()
		let sstream = input.components(separatedBy: "\n")
		for line in sstream {
			if line.isEmpty || line.hasPrefix("#") {
				continue
			}

			let linestream = line.components(separatedBy: " ")
			let col0 = linestream[0]
			let col1 = linestream[1]
			let col2 = linestream[2]

			var u = Megrez.Unigram(keyValue: Megrez.KeyValuePair(), score: 0)

			if swapKeyValue {
				u.keyValue.key = col1
				u.keyValue.value = col0
			} else {
				u.keyValue.key = col0
				u.keyValue.value = col1
			}

			u.score = Double(col2)!
			mutDatabase[u.keyValue.key, default: []].append(u)
		}
	}

	override func unigramsFor(key: String) -> [Megrez.Unigram] {
		if let f = mutDatabase[key] {
			return f
		} else {
			return [Megrez.Unigram]()
		}
	}

	override func hasUnigramsFor(key: String) -> Bool {
		mutDatabase.keys.contains(key)
	}
}

// MARK: - 用以測試的詞頻數據

let strSampleData = #"""
#
# 下述詞頻資料取自 libTaBE 資料庫 (http://sourceforge.net/projects/libtabe/)
# (2002 最終版). 該專案於 1999 年由 Pai-Hsiang Hsiao 發起、以 BSD 授權發行。
#
ni3 你 -6.000000 // Non-LibTaBE
zhe4 這 -6.000000 // Non-LibTaBE
yang4 樣 -6.000000 // Non-LibTaBE
si1 絲 -9.495858
si1 思 -9.00644
si1 私 -99.000000
si1 斯 -8.091803
si1 司 -99.000000
si1 嘶 -3.53987
si1 撕 -2.259095
gao1 高 -7.17551
ke1 顆 -10.574273
ke1 棵 -11.504072
ke1 刻 -10.450457
ke1 科 -7.171052
ke1 柯 -99.000000
gao1 膏 -11.928720
gao1 篙 -3.624335
gao1 糕 -2.390804
de5 的 -3.516024
di2 的 -3.516024
di4 的 -3.516024
zhong1 中 -5.809297
de5 得 -7.427179
gong1 共 -8.381971
gong1 供 -8.50463
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
ji4 繼 -9.75317
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
ji4 冀 -2.045357
zhong1 忠 -99.000000
ji4 妓 -99.000000
ji4 濟 -9.517568
ji4 薊 -2.02587
jin1 巾 -99.000000
jin1 襟 -2.784206
nian2 年 -6.08655
jiang3 講 -9.164384
jiang3 獎 -8.690941
jiang3 蔣 -10.27828
nian2 黏 -11.336864
nian2 粘 -11.285740
jiang3 槳 -2.492933
gong1si1 公司 -6.299461
ke1ji4 科技 -6.73663
ji4gong1 濟公 -3.336653
jiang3jin1 獎金 -10.344678
nian2zhong1 年終 -11.668947
nian2zhong1 年中 -11.373044
gao1ke1ji4 高科技 -9.842421
zhe4yang4 這樣 -6.000000 // Non-LibTaBE
ni3zhe4 你這 -9.000000 // Non-LibTaBE
"""#

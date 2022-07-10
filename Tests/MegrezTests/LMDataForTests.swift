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

import Megrez

// MARK: - 用以測試的語言模型（簡單範本型）

class SimpleLM: LangModelProtocol {
  var mutDatabase: [String: [Megrez.Unigram]] = [:]
  init(input: String, swapKeyValue: Bool = false) {
    let sstream = input.components(separatedBy: "\n")
    for line in sstream {
      if line.isEmpty || line.hasPrefix("#") {
        continue
      }
      let linestream = line.split(separator: " ")
      let col0 = String(linestream[0])
      let col1 = String(linestream[1])
      let col2 = Double(linestream[2]) ?? 0.0
      var u = Megrez.Unigram(value: swapKeyValue ? col0 : col1, score: 0)
      u.score = col2
      mutDatabase[swapKeyValue ? col1 : col0, default: []].append(u)
    }
  }

  func unigramsFor(key: String) -> [Megrez.Unigram] {
    if let f = mutDatabase[key] {
      return f
    } else {
      return [Megrez.Unigram]().sorted { $0.score > $1.score }
    }
  }

  func hasUnigramsFor(key: String) -> Bool {
    mutDatabase.keys.contains(key)
  }
}

class MockLM: LangModelProtocol {
  func unigramsFor(key: String) -> [Megrez.Unigram] {
    [Megrez.Unigram(value: key, score: -1)]
  }

  func hasUnigramsFor(key: String) -> Bool {
    !key.isEmpty
  }
}

// MARK: - 用以測試的詞頻數據

public let strStressData = #"""
yi 一 -2.08170692
yi-yi 一一 -4.38468400

"""#

public let strEmojiSampleData = #"""
gao1 高 -2.9396
re4 熱 -3.6024
gao1re4 高熱 -6.526
huo3 火 -3.6966
huo3 🔥 -8
yan4 焰 -5.4466
huo3yan4 火焰 -5.6231
huo3yan4 🔥 -8
wei2 危 -3.9832
xian3 險 -3.7810
wei2xian3 危險 -4.2623

"""#

public let strSampleData = #"""
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

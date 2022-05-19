# Megrez Engine 天權星引擎

該引擎已經實裝於基於純 Swift 語言完成的 **威注音輸入法** 內，歡迎好奇者嘗試：[GitHub](https://github.com/ShikiSuen/vChewing-macOS ) | [Gitee](https://gitee.com/vchewing/vChewing-macOS ) 。

天權星引擎是用來處理輸入法語彙庫的一個模組。該倉庫乃威注音專案的弒神行動（Operation Longinus）的一部分。

Megrez Engine is a module made for processing lingual data of an input method. This repository is part of Operation Longinus of The vChewing Project.

## 使用說明

### §1. 初期化

在你的 ctlInputMethod (InputMethodController) 或者 KeyHandler 內初期化一份 Megrez.BlockReadingBuilder 分節讀音槽副本（這裡將該副本命名為「`_builder`」）。由於 Megrez.BlockReadingBuilder 的型別是 Class 型別，所以其副本可以用 let 來宣告。

以 KeyHandler 為例：
```swift
class KeyHandler: NSObject {
  // 先設定好變數
  let _builder: Megrez.BlockReadingBuilder = .init()
  ...
}
```

以 ctlInputMethod 為例：
```swift
@objc(ctlInputMethod)  // 根據 info.plist 內的情況來確定型別的命名
class ctlInputMethod: IMKInputController {
  // 先設定好變數
  let _builder: Megrez.BlockReadingBuilder = .init()
  ...
}
```

由於 Swift 會在某個大副本（KeyHandler 或者 ctlInputMethod 副本）被銷毀的時候自動銷毀其中的全部副本，所以 Megrez.BlockReadingBuilder 的副本初期化沒必要寫在 init() 當中。但你很可能會想在 init() 時指定 Tekkon.Composer 所對接的語言模組型別、以及其可以允許的最大詞長。

這裡就需要在 init() 時使用參數：
```swift
  /// 分節讀音槽。
  /// - Parameters:
  ///   - lm: 語言模型。可以是任何基於 Megrez.LanguageModel 的衍生型別。
  ///   - length: 指定該分節讀音曹內可以允許的最大詞長，預設為 10 字。
  ///   - separator: 多字讀音鍵當中用以分割漢字讀音的記號，預設為空。
  let _builder: Megrez.BlockReadingBuilder = .init(lm: lmTest, length: 13, separator: "-")
```

### §2. 使用範例

請結合 MegrezTests.swift 檔案來學習。這裡只是給個概述。

#### // 1. 準備用作語言模型的專用型別

首先，Megrez 內建的 LanguageModel 型別是遠遠不夠用的，只能說是個類似於 protocol 一樣的存在。你需要自己單獨寫一個新的衍生型別：

```swift
class ExampleLM: Megrez.LanguageModel {
...
  override func unigramsFor(key: String) -> [Megrez.Unigram] {
    ...
  }
...
}
```

這個型別需要下述兩個函數能夠針對給定的鍵回饋對應的資料值、或其存無狀態：
- unigramsFor(key: String) -> [Megrez.Unigram]
- hasUnigramsFor(key: String) -> Bool

MegrezTests.swift 檔案內的 SimpleLM 可以作為範例。

如果需要更實戰的範例的話，可以洽威注音專案的倉庫內的 LMInstantiator.swift。

#### // 2. 怎樣與 builder 互動：

這裡只講幾個常用函數：

- 游標位置 `builder.cursorIndex` 是可以賦值與取值的動態變數，且會在賦值內容為超出位置範圍的數值時自動修正。初期值為 0。
- `builder.insertReadingAtCursor(reading: "gao1")` 可以在當前的游標位置插入讀音「gao1」。
- `builder.deleteReadingToTheFrontOfCursor()` 的作用是：朝著往文字輸入方向、砍掉一個與游標相鄰的讀音。反之，`deleteReadingAtTheRearOfCursor` 則朝著與文字輸入方向相反的方向、砍掉一個與游標相鄰的讀音。
  - 在威注音的術語體系當中，「文字輸入方向」為向前（Front）、與此相反的方向為向後（Rear）。
- `builder.grid.fixNodeSelectedCandidate(location: ?, value: "??")` 用來根據輸入法選中的候選字詞、據此更新當前游標位置選中的候選字詞節點當中的候選字詞。

輸入完內容之後，可以聲明一個用來接收結果的變數：

```swift
  /// 對已給定的軌格按照給定的位置與條件進行正向爬軌。
  ///
  /// 其實就是將反向爬軌的結果顛倒順序再給出來而已，省得使用者自己再顛倒一遍。
  /// - Parameters:
  ///   - at: 開始爬軌的位置。
  ///   - score: 給定累計權重，非必填參數。預設值為 0。
  ///   - nodesLimit: 限定最多只爬多少個節點。
  ///   - balanced: 啟用平衡權重，在節點權重的基礎上根據節點幅位長度來加權。
  var walked = _builder.walk(at: builder.grid.width, score: 0.0, nodesLimit: 3, balanced: true)
```

MegrezTests.swift 是輸入了很多內容之後再 walk 的。實際上一款輸入法會在你每次插入讀音或刪除讀音的時候都重新 walk。那些處於候選字詞鎖定狀態的節點不會再受到之後的 walk 的行為的影響，但除此之外的節點會因為每次 walk 而可能各自的候選字詞會出現自動變化。如果給了 nodesLimit 一個非零的數值的話，則 walk 的範圍外的節點不會受到影響。

walk 之後的取值的方法及利用方法可以有很多種。這裡有其中的一個：

```swift
    var composed: [String] = []
    for phrase in walked {
      if let node = phrase.node {
        composed.append(node.currentKeyValue.value)
      }
    }
    print(composed)
```

上述 print 結果就是 _builder 目前的組句，是這種陣列格式（以吳宗憲的詩句為例）：
```swift
    ["八月", "中秋", "山林", "涼", "風吹", "大地", "草枝", "擺"]
```

自己看 MegrezTests.swift 慢慢研究吧。

## 著作權 (Credits)

- Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
  - Swift programmer: Shiki Suen
  - C++ migration review: Hiraku Wong
- Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular" (MIT License).

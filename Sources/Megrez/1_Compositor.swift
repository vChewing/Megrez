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
  // A Compositor for deriving the most likely hidden values from a series of
  // observations. For our purpose, the observations are phonabet keys, and
  // the hidden values are the actual Mandarin words. This can also be used for
  // segmentation: in that case, the observations are Mandarin words, and the
  // hidden values are the most likely groupings.
  //
  // While we use the terminology from hidden Markov model (HMM), the actual
  // implementation is a much simpler Bayesian inference, since the underlying
  // language model consists of only unigrams. Once we have put all plausible
  // unigrams as nodes on the grid, a simple DAG shortest-path walk will give us
  // the maximum likelihood estimation (MLE) for the hidden values.
  public class Compositor {
    public enum TypingDirection { case front, rear }
    public enum GridResizeAction { case expand, shrink }
    public static var maxSpanLength: Int = 10 { didSet { maxSpanLength = max(6, maxSpanLength) } }
    public static let kDefaultSeparator: String = "-"
    public var cursor: Int = 0 { didSet { cursor = max(0, min(cursor, length)) } }
    public var separator = kDefaultSeparator
    public var width: Int { keys.count }
    private(set) var keys = [String]()
    private(set) var spans = [Span]()
    private(set) var langModel: LangModelRanked
    public var length: Int { keys.count }

    public init(with langModel: LangModelProtocol) {
      self.langModel = .init(withLM: langModel)
    }

    public func clear() {
      cursor = 0
      keys.removeAll()
      spans.removeAll()
    }

    /// Insert the key at the current cursor index.
    /// - Parameter key: The key to insert.
    /// - Returns: Whether the process is successful.
    @discardableResult public func insertKey(_ key: String) -> Bool {
      guard !key.isEmpty, key != separator, langModel.hasUnigramsFor(key: key) else { return false }
      keys.insert(key, at: cursor)
      resizeGrid(at: cursor, do: .expand)
      update()
      cursor += 1  // 游標必須得在執行 update() 之後才可以變動。
      return true
    }

    /// Delete the key at the rear of the cursor like Backspace
    /// (or to the front of the cursor like PC Delete).
    /// Cursor will decrement by one if the direction is to the rear.
    /// - Parameter direction: Typing direction.
    /// - Returns: Whether the process is successful.
    @discardableResult public func dropKey(direction: TypingDirection) -> Bool {
      let isBackSpace: Bool = direction == .rear ? true : false
      guard cursor != (isBackSpace ? 0 : keys.count) else { return false }
      keys.remove(at: cursor - (isBackSpace ? 1 : 0))
      cursor -= isBackSpace ? 1 : 0  // 在縮節之前。
      resizeGrid(at: cursor, do: .shrink)
      update()
      return true
    }
  }
}

// MARK: - Internal Methods

extension Megrez.Compositor {
  // MARK: Internal methods for maintaining the grid.

  /// Expand or shrink a span at designated cursor location.
  /// - Parameters:
  ///   - location: Designated cursor location.
  ///   - action: Tell this function to expand or shrink.
  func resizeGrid(at location: Int, do action: GridResizeAction) {
    switch action {
      case .expand:
        // if location > spans.count { return }  // TASK: 這句話該不該用還不好說
        spans.insert(Span(), at: location)
        if [0, spans.count].contains(location) { return }
      case .shrink:
        if spans.count == location { return }
        spans.remove(at: location)
    }
    dropWreckedNodes(at: location)
  }

  /// Drop wrecked nodes which are results of the resizeGrid() function.
  ///
  /// Because of the resizeGrid(), certain spans now have wrecked nodes. We need
  /// to drop them. For example (expansion), before:
  /// ```
  /// Span index 0   1   2   3
  ///                (---)
  ///                (-------)
  ///            (-----------)
  /// ```
  /// After we've inserted a span at 2:
  /// ```
  /// Span index 0   1   2   3   4
  ///                (---)
  ///                (XXX?   ?XXX) <-Wrecked
  ///            (XXXXXXX?   ?XXX) <-Wrecked
  /// ```
  /// Similarly for shrinkage, before:
  /// ```
  /// Span index 0   1   2   3
  ///                (---)
  ///                (-------)
  ///            (-----------)
  /// ```
  /// After we've deleted the span at 2:
  /// ```
  /// Span index 0   1   2   3   4
  ///                (---)
  ///                (XXX? <-Wrecked
  ///            (XXXXXXX? <-Wrecked
  /// ```
  /// - Parameter location: Designated cursor location.
  func dropWreckedNodes(at location: Int) {
    let location = max(0, location)  // 防呆
    guard !spans.isEmpty else { return }
    let affectedLength = Megrez.Compositor.maxSpanLength - 1
    let begin = max(0, location - affectedLength)
    guard location >= begin else { return }
    for i in begin..<location {
      spans[i].dropNodesOfOrBeyond(length: location - i + 1)
    }
  }

  @discardableResult func insertNode(_ node: Node, at location: Int) -> Bool {
    guard location < spans.count else { return false }
    spans[location].append(node: node)
    return true
  }

  func getJointKey(range: Range<Int>) -> String {
    guard range.upperBound <= keys.count, range.lowerBound >= 0 else { return "" }
    return keys[range].joined(separator: separator)
  }

  func hasNode(at location: Int, length: Int, key: String) -> Bool {
    guard location >= spans.count else { return false }
    guard let node = spans[location].nodeOf(length: length) else { return false }
    return key == node.key
  }

  func update() {
    let maxSpanLength = Megrez.Compositor.maxSpanLength
    let range = max(0, cursor - maxSpanLength)..<min(cursor + maxSpanLength, keys.count)
    for position in range {
      for theLength in 1...min(maxSpanLength, range.upperBound - position) {
        let jointKey = getJointKey(range: position..<(position + theLength))
        if hasNode(at: position, length: theLength, key: jointKey) { continue }
        let unigrams = langModel.unigramsFor(key: jointKey)
        guard !unigrams.isEmpty else { continue }
        insertNode(.init(key: jointKey, spanLength: theLength, unigrams: unigrams), at: position)
      }
    }
  }
}

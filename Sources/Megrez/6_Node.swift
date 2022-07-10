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

extension Megrez.Compositor {
  /// A Node consists of a set of unigrams, a key, and a spanning length.
  /// The spanning length denotes the length of the node in the grid. The grid
  /// is responsible for constructing its nodes. For Mandarin multi-character
  /// phrases, the grid will join separate keys into a single combined
  /// key, and use that key to retrieve the unigrams with that key.
  /// Node with two-character phrases (so two keys, or two syllables) will
  /// then have a spanning length of 2.
  public class Node: Equatable {
    /// Override-Type of a Node.
    /// - withNoOverrides: Override the node with a unigram value and a score
    /// such that the node will almost always be favored by the walk.
    /// - withHighScore: Override the node with a unigram value but with the
    /// score of the top unigram. For example, if the unigrams in the node are
    /// ("a", -1), ("b", -2), ("c", -10), overriding using this type for "c"
    /// will cause the node to return the value "c" with the score -1. This is
    /// used for soft-override such as from a suggestion. The node with the
    /// override value will very likely be favored by a walk, but it does not
    /// prevent other nodes from prevailing, which would be the case if
    /// kOverrideValueWithHighScore was used.
    public enum OverrideType {
      case withNoOverrides, withHighScore, withTopUnigramScore
    }

    /// A sufficiently high score to cause the walk to go through an overriding
    /// node. Although this can be 0, setting it to a positive value has the
    /// desirable side effect that it reduces the competition of "free-floating"
    /// multiple-character phrases. For example, if the user override for
    /// key "a b c" is "A B c", using the uppercase as the overriding node,
    /// now the standalone c may have to compete with a phrase with key "bc",
    /// which in some pathological cases may actually cause the shortest path to
    /// be A->bc, especially when A and B use the zero overriding score, as they
    /// leave "c" alone to compete with "bc", and whether the path A-B is favored
    /// now solely depends on that competition. A positive value favors the route
    /// A->B, which gives "c" a better chance.
    public static let kOverridingScore: Double = 114_514

    private(set) var key: String
    private(set) var spanLength: Int
    private(set) var unigrams: [Megrez.Unigram]
    private(set) var currentUnigramIndex: Int = 0 {
      didSet { currentUnigramIndex = min(max(0, currentUnigramIndex), unigrams.count - 1) }
    }

    private(set) var overrideType: Node.OverrideType

    public static func == (lhs: Node, rhs: Node) -> Bool {
      lhs.key == rhs.key && lhs.spanLength == rhs.spanLength
        && lhs.unigrams == rhs.unigrams && lhs.overrideType == rhs.overrideType
    }

    public init(key: String = "", spanLength: Int, unigrams: [Megrez.Unigram] = []) {
      self.key = key
      self.spanLength = spanLength
      self.unigrams = unigrams
      overrideType = .withNoOverrides
    }

    /// Returns the top or overridden unigram.
    /// - Returns: The top or overridden unigram.
    public var currentUnigram: Megrez.Unigram {
      unigrams.isEmpty ? .init() : unigrams[currentUnigramIndex]
    }

    public var value: String { currentUnigram.value }

    public var score: Double {
      guard !unigrams.isEmpty else { return 0 }
      switch overrideType {
        case .withHighScore: return Megrez.Compositor.Node.kOverridingScore
        case .withTopUnigramScore: return unigrams[0].score
        default: return currentUnigram.score
      }
    }

    public var isOverriden: Bool {
      overrideType != .withNoOverrides
    }

    public func reset() {
      currentUnigramIndex = 0
      overrideType = .withNoOverrides
    }

    public func selectOverrideUnigram(value: String, type: Node.OverrideType) -> Bool {
      guard type != .withNoOverrides else {
        return false
      }
      for (i, gram) in unigrams.enumerated() {
        if value != gram.value { continue }
        currentUnigramIndex = i
        overrideType = type
        return true
      }
      return false
    }
  }
}

import Foundation

/// An amount of money, held as a whole number of cents.
///
/// Nothing in Tallyroll adds floating-point numbers together: a till that is a
/// cent out at the end of the day is a till nobody trusts.
struct Money: Hashable, Comparable, Codable, CustomStringConvertible {
    var cents: Int

    init(cents: Int) { self.cents = cents }

    static let zero = Money(cents: 0)

    /// Parses loose input from a keypad — "12", "12.5", "$12.50" all land the same.
    init(text: String) {
        let cleaned = text.filter { $0.isNumber || $0 == "." || $0 == "-" }
        guard let value = Double(cleaned), value.isFinite else {
            self.cents = 0
            return
        }
        self.cents = Int((value * 100).rounded())
    }

    /// Plain decimal with no symbol, for spreadsheets: `12.50`.
    var plain: String { String(format: "%.2f", Double(cents) / 100) }

    var description: String { plain }

    func formatted(_ symbol: String) -> String {
        let body = symbol + String(format: "%.2f", Double(abs(cents)) / 100)
        return cents < 0 ? "-" + body : body
    }

    static func + (a: Money, b: Money) -> Money { Money(cents: a.cents + b.cents) }
    static func - (a: Money, b: Money) -> Money { Money(cents: a.cents - b.cents) }
    static func * (a: Money, n: Int) -> Money { Money(cents: a.cents * n) }
    static func += (a: inout Money, b: Money) { a = a + b }
    static func < (a: Money, b: Money) -> Bool { a.cents < b.cents }

    /// Rounds half away from zero, so 10% of $13.75 is $1.38 off rather than $1.37.
    func percentage(basisPoints: Int) -> Money {
        Money(cents: Int((Double(cents) * Double(basisPoints) / 10_000).rounded()))
    }

    // Encoded as a bare integer so the saved file stays readable.
    init(from decoder: Decoder) throws {
        cents = try decoder.singleValueContainer().decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(cents)
    }
}

/// A rate held in basis points: 825 is 8.25%.
enum BasisPoints {
    static func parse(_ text: String) -> Int {
        let cleaned = text.filter { $0.isNumber || $0 == "." }
        guard let value = Double(cleaned), value.isFinite, value >= 0 else { return 0 }
        return Int((value * 100).rounded())
    }

    static func describe(_ points: Int) -> String {
        var s = String(format: "%.2f", Double(points) / 100)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return (s.isEmpty ? "0" : s) + "%"
    }
}

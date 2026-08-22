import Foundation

/// One size of an item, with its own price. An item with a single unnamed
/// variant is simply a thing with one price.
struct Variant: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var label: String = ""
    var price: Money = .zero
}

struct Item: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    /// File name inside the photos directory, when the item carries a photo.
    var photo: String?
    var variants: [Variant] = [Variant()]

    var hasSizes: Bool {
        variants.count > 1 || (variants.count == 1 && !variants[0].label.isEmpty)
    }

    func priceRange(_ symbol: String) -> String {
        let prices = variants.map(\.price)
        guard let low = prices.min(), let high = prices.max() else { return "" }
        return low == high ? low.formatted(symbol)
                           : "\(low.formatted(symbol))–\(high.formatted(symbol))"
    }
}

enum DiscountKind: String, Codable, Hashable {
    case percent, amount
}

struct Discount: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var label: String = ""
    var kind: DiscountKind = .percent
    /// Basis points for `.percent`, cents for `.amount`.
    var value: Int = 0

    func summary(_ symbol: String) -> String {
        switch kind {
        case .percent: return BasisPoints.describe(value)
        case .amount: return "-" + Money(cents: value).formatted(symbol)
        }
    }
}

/// A discount as it was actually applied, keeping the amount and the figure it
/// was worked out from so the price stays justifiable long afterwards.
struct AppliedDiscount: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var label: String
    var kind: DiscountKind
    var value: Int
    var amount: Money
    var base: Money

    func reason(_ symbol: String) -> String {
        switch kind {
        case .percent: return "\(BasisPoints.describe(value)) of \(base.formatted(symbol))"
        case .amount: return "flat \(Money(cents: value).formatted(symbol)) off"
        }
    }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash, card, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cash: return "Cash"
        case .card: return "Card"
        case .other: return "Other"
        }
    }
}

struct SaleLine: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var itemID: UUID?
    var name: String
    var size: String
    var unitPrice: Money
    var qty: Int

    var lineTotal: Money { unitPrice * qty }
}

struct Sale: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var lines: [SaleLine] = []
    var subtotal: Money = .zero
    var discounts: [AppliedDiscount] = []
    var taxRate: Int = 0
    var tax: Money = .zero
    var total: Money = .zero
    var method: PaymentMethod = .cash
    var tendered: Money = .zero
    var change: Money = .zero
    var note: String = ""
    var voided: Bool = false

    var summary: String {
        let parts = lines.map { line -> String in
            let count = line.qty > 1 ? "\(line.qty)× " : ""
            let size = line.size.isEmpty ? "" : " (\(line.size))"
            return count + line.name + size
        }
        return parts.isEmpty ? "Empty sale" : parts.joined(separator: ", ")
    }
}

struct CartLine: Identifiable, Codable, Hashable {
    /// Item and variant together, so the same size taken twice stacks up.
    var id: String
    var itemID: UUID
    var variantID: UUID
    var name: String
    var size: String
    var unitPrice: Money
    var qty: Int

    var lineTotal: Money { unitPrice * qty }
}

struct Cart: Codable {
    var lines: [CartLine] = []
    var discountIDs: [UUID] = []
    var method: PaymentMethod = .cash
    var note: String = ""
    var tendered: Money = .zero

    var isEmpty: Bool { lines.isEmpty }
    var count: Int { lines.reduce(0) { $0 + $1.qty } }

    func count(of itemID: UUID) -> Int {
        lines.filter { $0.itemID == itemID }.reduce(0) { $0 + $1.qty }
    }
}

struct AppSettings: Codable {
    var currency: String = "$"
    var business: String = ""
    var taxEnabled: Bool = false
    /// Basis points.
    var taxRate: Int = 0
}

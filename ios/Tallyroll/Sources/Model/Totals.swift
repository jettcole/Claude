import Foundation

struct Totals {
    var subtotal: Money = .zero
    var applied: [AppliedDiscount] = []
    var discountTotal: Money = .zero
    var taxRate: Int = 0
    var tax: Money = .zero
    var total: Money = .zero
}

/// What the drawer owes, once the cash is in hand.
enum ChangeState: Equatable {
    case idle
    case due(Money)
    case owed(Money)

    var label: String {
        switch self {
        case .idle, .due: return "Change due"
        case .owed: return "Still owed"
        }
    }

    func amount(_ symbol: String) -> String {
        switch self {
        case .idle: return "—"
        case .due(let m), .owed(let m): return m.formatted(symbol)
        }
    }

    var isShort: Bool {
        if case .owed = self { return true }
        return false
    }
}

/// The arithmetic of a sale, kept free of any UI so it can be tested directly.
enum Register {

    /// Discounts apply in the order they were added, each working on what is
    /// left after the one before it. Tax lands on the discounted figure.
    static func totals(lines: [CartLine],
                       discounts: [Discount],
                       applying ids: [UUID],
                       taxRate: Int) -> Totals {

        var result = Totals()
        result.subtotal = lines.reduce(Money.zero) { $0 + $1.lineTotal }

        var running = result.subtotal
        for id in ids {
            guard let discount = discounts.first(where: { $0.id == id }) else { continue }
            let base = running

            var amount: Money
            switch discount.kind {
            case .percent: amount = running.percentage(basisPoints: discount.value)
            case .amount: amount = Money(cents: discount.value)
            }
            if amount > running { amount = running }
            if amount < .zero { amount = .zero }

            running = running - amount
            result.applied.append(AppliedDiscount(label: discount.label,
                                                  kind: discount.kind,
                                                  value: discount.value,
                                                  amount: amount,
                                                  base: base))
        }

        result.discountTotal = result.subtotal - running
        result.taxRate = taxRate
        result.tax = running.percentage(basisPoints: taxRate)
        result.total = running + result.tax
        return result
    }

    static func change(total: Money, tendered: Money) -> ChangeState {
        if tendered == .zero { return .idle }
        if tendered < total { return .owed(total - tendered) }
        return .due(tendered - total)
    }

    /// The exact money first, then the notes someone is most likely to hand over.
    static func tenderSuggestions(for total: Money) -> [Money] {
        var out: [Money] = [total]
        for step in [100, 500, 1_000, 2_000, 5_000] where out.count < 4 {
            let rounded = Money(cents: Int((Double(total.cents) / Double(step)).rounded(.up)) * step)
            if rounded > total, !out.contains(rounded) { out.append(rounded) }
        }
        return out
    }
}

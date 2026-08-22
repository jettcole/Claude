import XCTest
@testable import Tallyroll

final class RegisterTests: XCTestCase {

    private func line(_ name: String, _ cents: Int, qty: Int = 1) -> CartLine {
        CartLine(id: name, itemID: UUID(), variantID: UUID(), name: name, size: "",
                 unitPrice: Money(cents: cents), qty: qty)
    }

    private let tenPercent = Discount(label: "Regular", kind: .percent, value: 1_000)
    private let twoOff = Discount(label: "Staff", kind: .amount, value: 200)

    func testSubtotalMultipliesQuantity() {
        let totals = Register.totals(lines: [line("Latte", 500, qty: 2), line("Croissant", 375)],
                                     discounts: [], applying: [], taxRate: 0)
        XCTAssertEqual(totals.subtotal.cents, 1375)
        XCTAssertEqual(totals.total.cents, 1375)
    }

    func testPercentDiscountRecordsWhatItWasBasedOn() {
        let totals = Register.totals(lines: [line("Latte", 500, qty: 2), line("Croissant", 375)],
                                     discounts: [tenPercent], applying: [tenPercent.id], taxRate: 0)
        XCTAssertEqual(totals.applied.count, 1)
        XCTAssertEqual(totals.applied[0].amount.cents, 138)
        XCTAssertEqual(totals.applied[0].base.cents, 1375)
        XCTAssertEqual(totals.applied[0].reason("$"), "10% of $13.75")
        XCTAssertEqual(totals.total.cents, 1237)
    }

    /// Each discount works on what is left after the one before it.
    func testDiscountsStackInOrder() {
        let totals = Register.totals(lines: [line("Latte", 500, qty: 2), line("Croissant", 375)],
                                     discounts: [tenPercent, twoOff],
                                     applying: [tenPercent.id, twoOff.id], taxRate: 0)
        XCTAssertEqual(totals.applied.map(\.amount.cents), [138, 200])
        XCTAssertEqual(totals.applied[1].base.cents, 1237)
        XCTAssertEqual(totals.discountTotal.cents, 338)
        XCTAssertEqual(totals.total.cents, 1037)
    }

    func testFlatDiscountExplainsItself() {
        let totals = Register.totals(lines: [line("Latte", 500)],
                                     discounts: [twoOff], applying: [twoOff.id], taxRate: 0)
        XCTAssertEqual(totals.applied[0].reason("$"), "flat $2.00 off")
    }

    /// A sale can be free, never negative.
    func testDiscountNeverTakesTheTotalBelowZero() {
        let huge = Discount(label: "Comp", kind: .amount, value: 9_999)
        let totals = Register.totals(lines: [line("Croissant", 375)],
                                     discounts: [huge], applying: [huge.id], taxRate: 0)
        XCTAssertEqual(totals.applied[0].amount.cents, 375)
        XCTAssertEqual(totals.total.cents, 0)
    }

    func testTaxAppliesAfterDiscounts() {
        let totals = Register.totals(lines: [line("Croissant", 375)],
                                     discounts: [], applying: [], taxRate: 825)
        XCTAssertEqual(totals.tax.cents, 31)
        XCTAssertEqual(totals.total.cents, 406)

        let discounted = Register.totals(lines: [line("Latte", 500, qty: 2), line("Croissant", 375)],
                                         discounts: [tenPercent], applying: [tenPercent.id],
                                         taxRate: 825)
        XCTAssertEqual(discounted.tax.cents, Money(cents: 1237).percentage(basisPoints: 825).cents)
        XCTAssertEqual(discounted.total.cents, 1237 + discounted.tax.cents)
    }

    func testUnknownDiscountIsIgnored() {
        let totals = Register.totals(lines: [line("Latte", 500)],
                                     discounts: [], applying: [UUID()], taxRate: 0)
        XCTAssertTrue(totals.applied.isEmpty)
        XCTAssertEqual(totals.total.cents, 500)
    }

    // MARK: - Change

    func testChangeStates() {
        let total = Money(cents: 1037)
        XCTAssertEqual(Register.change(total: total, tendered: .zero), .idle)
        XCTAssertEqual(Register.change(total: total, tendered: Money(cents: 2000)),
                       .due(Money(cents: 963)))
        XCTAssertEqual(Register.change(total: total, tendered: Money(cents: 1000)),
                       .owed(Money(cents: 37)))
        XCTAssertEqual(Register.change(total: total, tendered: total), .due(.zero))
    }

    func testShortPaymentIsFlagged() {
        XCTAssertTrue(Register.change(total: Money(cents: 1375), tendered: Money(cents: 1000)).isShort)
        XCTAssertFalse(Register.change(total: Money(cents: 1375), tendered: Money(cents: 2000)).isShort)
        XCTAssertEqual(Register.change(total: Money(cents: 1375), tendered: Money(cents: 1000)).label,
                       "Still owed")
    }

    func testTenderSuggestionsOfferExactThenLikelyNotes() {
        let suggestions = Register.tenderSuggestions(for: Money(cents: 1375)).map(\.cents)
        XCTAssertEqual(suggestions, [1375, 1400, 1500, 2000])
    }

    /// A round total must not suggest itself twice.
    func testTenderSuggestionsSkipDuplicates() {
        let suggestions = Register.tenderSuggestions(for: Money(cents: 1000)).map(\.cents)
        XCTAssertEqual(suggestions.first, 1000)
        XCTAssertEqual(Set(suggestions).count, suggestions.count)
        XCTAssertFalse(suggestions.dropFirst().contains(1000))
    }
}

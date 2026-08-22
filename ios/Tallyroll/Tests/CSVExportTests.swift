import XCTest
@testable import Tallyroll

final class CSVExportTests: XCTestCase {

    private func sale(note: String = "", voided: Bool = false) -> Sale {
        Sale(date: Date(timeIntervalSince1970: 1_700_000_000),
             lines: [
                SaleLine(name: "Latte", size: "Large", unitPrice: Money(cents: 500), qty: 2),
                SaleLine(name: "Croissant", size: "", unitPrice: Money(cents: 375), qty: 1)
             ],
             subtotal: Money(cents: 1375),
             discounts: [
                AppliedDiscount(label: "Regular", kind: .percent, value: 1_000,
                                amount: Money(cents: 138), base: Money(cents: 1375)),
                AppliedDiscount(label: "Staff", kind: .amount, value: 200,
                                amount: Money(cents: 200), base: Money(cents: 1237))
             ],
             taxRate: 0,
             tax: .zero,
             total: Money(cents: 1037),
             method: .cash,
             tendered: Money(cents: 2000),
             change: Money(cents: 963),
             note: note,
             voided: voided)
    }

    private func rows(_ csv: String) -> [String] {
        csv.replacingOccurrences(of: "\u{FEFF}", with: "")
            .components(separatedBy: "\r\n")
            .filter { !$0.isEmpty }
    }

    func testHeaderNamesEveryColumn() {
        let csv = CSVExport.make(sales: [sale()], symbol: "$")
        XCTAssertEqual(rows(csv)[0], CSVExport.columns.joined(separator: ","))
        XCTAssertTrue(rows(csv)[0].contains("cash_received,change_given,discounts_applied"))
    }

    func testOneRowPerItemSoldCarryingSize() {
        let lines = rows(CSVExport.make(sales: [sale()], symbol: "$"))
        XCTAssertEqual(lines.count, 3, "a header plus one row per line sold")
        XCTAssertTrue(lines[1].contains(",Latte,Large,2,5.00,10.00,"), lines[1])
        XCTAssertTrue(lines[2].contains(",Croissant,,1,3.75,3.75,"), lines[2])
    }

    func testCashAndChangeAreExported() {
        let lines = rows(CSVExport.make(sales: [sale()], symbol: "$"))
        XCTAssertTrue(lines[1].contains(",Cash,20.00,9.63,"), lines[1])
    }

    func testDiscountReasoningIsExported() {
        let lines = rows(CSVExport.make(sales: [sale()], symbol: "$"))
        XCTAssertTrue(lines[1].contains("Regular (10% of $13.75); Staff (flat $2.00 off)"), lines[1])
    }

    /// A note containing a comma must not shift every later column.
    func testFieldsWithCommasAndQuotesAreEscaped() {
        let lines = rows(CSVExport.make(sales: [sale(note: "Jo, \"the regular\"")], symbol: "$"))
        XCTAssertTrue(lines[1].hasSuffix("\"Jo, \"\"the regular\"\"\""), lines[1])
    }

    func testVoidedSalesStayInTheExportAndAreMarked() {
        let lines = rows(CSVExport.make(sales: [sale(voided: true)], symbol: "$"))
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[1].contains(",yes,"), lines[1])
    }

    func testNonCashSaleLeavesTheCashColumnsEmpty() {
        var card = sale()
        card.method = .card
        card.tendered = .zero
        card.change = .zero
        let lines = rows(CSVExport.make(sales: [card], symbol: "$"))
        XCTAssertTrue(lines[1].contains(",Card,,,"), lines[1])
    }

    func testAmountsCarryNoCurrencySymbolSoSheetsCanSumThem() {
        let csv = CSVExport.make(sales: [sale()], symbol: "£")
        let dataRow = rows(csv)[1]
        // The reasoning column is prose and may name the symbol; the figures must not.
        let upToReasoning = dataRow.components(separatedBy: ",Cash,")[0]
        XCTAssertFalse(upToReasoning.contains("£"), upToReasoning)
    }

    func testEmptyLedgerStillProducesAHeader() {
        XCTAssertEqual(rows(CSVExport.make(sales: [], symbol: "$")).count, 1)
    }
}

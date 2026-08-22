import XCTest
@testable import Tallyroll

@MainActor
final class StoreTests: XCTestCase {

    private func makeStore() -> Store {
        Store(loadFromDisk: false, persists: false)
    }

    private func stockedStore() -> (Store, Item) {
        let store = makeStore()
        let item = Item(name: "Latte", variants: [
            Variant(label: "Small", price: Money(cents: 350)),
            Variant(label: "Large", price: Money(cents: 500))
        ])
        store.items = [item]
        return (store, item)
    }

    func testAddingTheSameSizeTwiceStacksIntoOneLine() {
        let (store, item) = stockedStore()
        let large = item.variants[1]
        store.add(item: item, variant: large)
        store.add(item: item, variant: large)

        XCTAssertEqual(store.cart.lines.count, 1)
        XCTAssertEqual(store.cart.lines[0].qty, 2)
        XCTAssertEqual(store.cart.count, 2)
        XCTAssertEqual(store.cartTotals.total.cents, 1000)
    }

    func testDifferentSizesAreSeparateLines() {
        let (store, item) = stockedStore()
        store.add(item: item, variant: item.variants[0])
        store.add(item: item, variant: item.variants[1])

        XCTAssertEqual(store.cart.lines.count, 2)
        XCTAssertEqual(store.cart.count(of: item.id), 2)
        XCTAssertEqual(store.cartTotals.subtotal.cents, 850)
    }

    func testDroppingTheLastOneRemovesTheLine() {
        let (store, item) = stockedStore()
        store.add(item: item, variant: item.variants[0])
        store.changeQty(store.cart.lines[0].id, by: -1)
        XCTAssertTrue(store.cart.isEmpty)
    }

    func testCompletingRecordsSizeAndReturnsChange() {
        let (store, item) = stockedStore()
        store.add(item: item, variant: item.variants[1])
        store.cart.method = .cash
        store.cart.tendered = Money(cents: 1000)

        let change = store.completeSale()

        XCTAssertEqual(change.cents, 500)
        XCTAssertEqual(store.sales.count, 1)
        let sale = store.sales[0]
        XCTAssertEqual(sale.lines[0].size, "Large")
        XCTAssertEqual(sale.lines[0].unitPrice.cents, 500)
        XCTAssertEqual(sale.total.cents, 500)
        XCTAssertEqual(sale.tendered.cents, 1000)
        XCTAssertEqual(sale.change.cents, 500)
        XCTAssertTrue(store.cart.isEmpty, "the cart should be cleared after a sale")
    }

    /// Cash entered then switched to card must not be recorded as cash taken.
    func testCardSaleRecordsNoCash() {
        let (store, item) = stockedStore()
        store.add(item: item, variant: item.variants[1])
        store.cart.tendered = Money(cents: 1000)
        store.cart.method = .card

        store.completeSale()

        XCTAssertEqual(store.sales[0].tendered.cents, 0)
        XCTAssertEqual(store.sales[0].change.cents, 0)
    }

    func testUnderpaymentRecordsNoChange() {
        let (store, item) = stockedStore()
        store.add(item: item, variant: item.variants[1])
        store.cart.method = .cash
        store.cart.tendered = Money(cents: 300)

        let change = store.completeSale()

        XCTAssertEqual(change.cents, 0)
        XCTAssertEqual(store.sales[0].tendered.cents, 300)
    }

    func testCompletingAnEmptyCartDoesNothing() {
        let store = makeStore()
        store.completeSale()
        XCTAssertTrue(store.sales.isEmpty)
    }

    /// Voiding keeps the record but stops it counting, which is what makes a
    /// day's takings reconcile.
    func testVoidedSalesLeaveTheTotalsButStayInTheLog() {
        let (store, item) = stockedStore()
        store.add(item: item, variant: item.variants[1])
        store.completeSale()
        XCTAssertEqual(store.allTimeTakings.cents, 500)

        store.toggleVoid(store.sales[0].id)
        XCTAssertEqual(store.allTimeTakings.cents, 0)
        XCTAssertEqual(store.sales.count, 1)
        XCTAssertEqual(store.takings(on: Date()).cents, 0)
        XCTAssertEqual(store.salesCount(on: Date()), 0)

        store.toggleVoid(store.sales[0].id)
        XCTAssertEqual(store.allTimeTakings.cents, 500)
    }

    /// History must survive its item being deleted from the menu.
    func testDeletingAnItemLeavesRecordedSalesIntact() {
        let (store, item) = stockedStore()
        store.add(item: item, variant: item.variants[1])
        store.completeSale()

        store.delete(item: item.id)

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.sales.count, 1)
        XCTAssertEqual(store.sales[0].lines[0].name, "Latte")
        XCTAssertEqual(store.sales[0].lines[0].size, "Large")
    }

    func testDeletingAnItemPullsItFromTheOpenSale() {
        let (store, item) = stockedStore()
        store.add(item: item, variant: item.variants[1])
        store.delete(item: item.id)
        XCTAssertTrue(store.cart.isEmpty)
    }

    func testDeletingADiscountUnapplesItFromTheOpenSale() {
        let (store, item) = stockedStore()
        let discount = Discount(label: "Regular", kind: .percent, value: 1_000)
        store.discounts = [discount]
        store.add(item: item, variant: item.variants[1])
        store.toggleDiscount(discount.id)
        XCTAssertEqual(store.cartTotals.total.cents, 450)

        store.delete(discount: discount.id)

        XCTAssertTrue(store.cart.discountIDs.isEmpty)
        XCTAssertEqual(store.cartTotals.total.cents, 500)
    }

    func testTaxOnlyCountsWhenSwitchedOn() {
        let (store, item) = stockedStore()
        store.add(item: item, variant: item.variants[1])
        store.settings.taxRate = 825

        XCTAssertEqual(store.cartTotals.total.cents, 500, "tax is off, so nothing is added")

        store.settings.taxEnabled = true
        XCTAssertEqual(store.cartTotals.tax.cents, 41)
        XCTAssertEqual(store.cartTotals.total.cents, 541)
    }

    func testSampleMenuLoads() {
        let store = makeStore()
        store.loadSampleMenu()
        XCTAssertEqual(store.items.count, 5)
        XCTAssertEqual(store.discounts.count, 2)
        XCTAssertTrue(store.items.contains { $0.hasSizes })
        XCTAssertTrue(store.items.contains { !$0.hasSizes })
    }

    func testBackupRoundTripsEverything() {
        let (store, item) = stockedStore()
        store.settings.business = "Fern & Filter"
        store.add(item: item, variant: item.variants[1])
        store.completeSale()

        guard let data = store.backupData() else {
            return XCTFail("backup could not be encoded")
        }

        let restored = makeStore()
        guard case .restored(let count) = restored.restore(from: data) else {
            return XCTFail("backup was not recognised")
        }

        XCTAssertEqual(count, 1)
        XCTAssertEqual(restored.items.count, 1)
        XCTAssertEqual(restored.sales.count, 1)
        XCTAssertEqual(restored.settings.business, "Fern & Filter")
        XCTAssertEqual(restored.sales[0].total.cents, 500)
    }

    func testRestoringRubbishIsRejected() {
        let store = makeStore()
        let data = Data("not a backup".utf8)
        guard case .notABackup = store.restore(from: data) else {
            return XCTFail("random data should not be accepted as a backup")
        }
    }

    func testPriceRangeReadsAsARange() {
        let (_, item) = stockedStore()
        XCTAssertEqual(item.priceRange("$"), "$3.50–$5.00")

        let single = Item(name: "Croissant", variants: [Variant(label: "", price: Money(cents: 375))])
        XCTAssertEqual(single.priceRange("$"), "$3.75")
        XCTAssertFalse(single.hasSizes)
    }
}

import XCTest
@testable import Tallyroll

final class MoneyTests: XCTestCase {

    func testParsesLooseKeypadInput() {
        XCTAssertEqual(Money(text: "12").cents, 1200)
        XCTAssertEqual(Money(text: "12.5").cents, 1250)
        XCTAssertEqual(Money(text: "12.50").cents, 1250)
        XCTAssertEqual(Money(text: "$12.50").cents, 1250)
        XCTAssertEqual(Money(text: "").cents, 0)
        XCTAssertEqual(Money(text: "abc").cents, 0)
    }

    /// The classic float trap: 0.1 + 0.2 must be exactly 0.30.
    func testAdditionIsExact() {
        let total = Money(text: "0.10") + Money(text: "0.20")
        XCTAssertEqual(total.cents, 30)
        XCTAssertEqual(total.plain, "0.30")
    }

    func testFormatsWithSymbolAndNegatives() {
        XCTAssertEqual(Money(cents: 1250).formatted("$"), "$12.50")
        XCTAssertEqual(Money(cents: -250).formatted("$"), "-$2.50")
        XCTAssertEqual(Money(cents: 1250).formatted("£"), "£12.50")
        XCTAssertEqual(Money(cents: 0).plain, "0.00")
    }

    /// 10% of $13.75 is $1.375; rounding half up takes $1.38 off.
    func testPercentageRoundsHalfAwayFromZero() {
        XCTAssertEqual(Money(cents: 1375).percentage(basisPoints: 1000).cents, 138)
        XCTAssertEqual(Money(cents: 1000).percentage(basisPoints: 825).cents, 83)
        XCTAssertEqual(Money(cents: 375).percentage(basisPoints: 825).cents, 31)
    }

    func testBasisPoints() {
        XCTAssertEqual(BasisPoints.parse("8.25"), 825)
        XCTAssertEqual(BasisPoints.parse("10"), 1000)
        XCTAssertEqual(BasisPoints.parse(""), 0)
        XCTAssertEqual(BasisPoints.describe(825), "8.25%")
        XCTAssertEqual(BasisPoints.describe(1000), "10%")
        XCTAssertEqual(BasisPoints.describe(0), "0%")
    }

    func testMoneySurvivesEncoding() throws {
        let data = try JSONEncoder().encode(Money(cents: 1375))
        XCTAssertEqual(String(data: data, encoding: .utf8), "1375")
        XCTAssertEqual(try JSONDecoder().decode(Money.self, from: data).cents, 1375)
    }
}

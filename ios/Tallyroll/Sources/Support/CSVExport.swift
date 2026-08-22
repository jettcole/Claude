import Foundation

/// One row per item sold, with the reasoning behind any discount carried
/// along so a price can still be justified months later.
enum CSVExport {

    static let columns = ["till", "sale_id", "date", "time", "item", "size", "qty",
                          "unit_price", "line_total", "sale_subtotal", "sale_discount",
                          "sale_tax", "sale_total", "payment_method", "cash_received",
                          "change_given", "discounts_applied", "voided", "note"]

    private static func cell(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"")
            || value.contains("\n") || value.contains("\r")
        guard needsQuoting else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }

    static func make(sales: [Sale], symbol: String) -> String {
        let dayFormat = formatter("yyyy-MM-dd")
        let timeFormat = formatter("HH:mm:ss")

        var rows = [columns.joined(separator: ",")]

        for sale in sales.sorted(by: { $0.date < $1.date }) {
            let discountTotal = sale.discounts.reduce(Money.zero) { $0 + $1.amount }
            let reasoning = sale.discounts
                .map { "\($0.label) (\($0.reason(symbol)))" }
                .joined(separator: "; ")

            for line in sale.lines {
                let values = [
                    sale.till,
                    sale.id.uuidString,
                    dayFormat.string(from: sale.date),
                    timeFormat.string(from: sale.date),
                    line.name,
                    line.size,
                    String(line.qty),
                    line.unitPrice.plain,
                    line.lineTotal.plain,
                    sale.subtotal.plain,
                    discountTotal.plain,
                    sale.tax.plain,
                    sale.total.plain,
                    sale.method.label,
                    sale.tendered == .zero ? "" : sale.tendered.plain,
                    sale.tendered == .zero ? "" : sale.change.plain,
                    reasoning,
                    sale.voided ? "yes" : "no",
                    sale.note
                ]
                rows.append(values.map(cell).joined(separator: ","))
            }
        }
        // A leading byte-order mark keeps Excel from mangling accented names.
        return "\u{FEFF}" + rows.joined(separator: "\r\n") + "\r\n"
    }

    /// Writes to a temporary file so it can be handed to the iOS share sheet.
    static func writeTemporary(_ text: String, named name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    static func stampedName(_ ext: String, date: Date = Date()) -> String {
        "tallyroll-" + formatter("yyyyMMdd").string(from: date) + "." + ext
    }
}

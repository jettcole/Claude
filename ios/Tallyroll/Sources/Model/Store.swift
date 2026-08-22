import Foundation
import SwiftUI

/// Everything the app knows, saved to a JSON file in the app's own Documents
/// directory. Photos live beside it as ordinary JPEGs rather than being inlined,
/// which keeps the file small enough to rewrite on every change.
@MainActor
final class Store: ObservableObject {

    @Published var items: [Item] = [] { didSet { persist() } }
    @Published var discounts: [Discount] = [] { didSet { persist() } }
    @Published var sales: [Sale] = [] { didSet { persist() } }
    @Published var settings = AppSettings() { didSet { persist() } }
    @Published var cart = Cart() { didSet { persist() } }

    /// Suspended while loading so reading the file back does not rewrite it.
    private var loaded = false

    var symbol: String { settings.currency.isEmpty ? "$" : settings.currency }

    // MARK: - Locations

    private static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private static var dataFile: URL { documents.appendingPathComponent("tallyroll.json") }
    static var photoDirectory: URL { documents.appendingPathComponent("Photos", isDirectory: true) }

    // MARK: - Persistence

    private struct Payload: Codable {
        var items: [Item] = []
        var discounts: [Discount] = []
        var sales: [Sale] = []
        var settings = AppSettings()
        var cart = Cart()
    }

    /// Tests build a store that neither reads nor writes the shared file.
    init(loadFromDisk: Bool = true, persists: Bool = true) {
        self.persists = persists
        if loadFromDisk { load() }
        loaded = true
    }

    private let persists: Bool

    private func load() {
        guard let data = try? Data(contentsOf: Self.dataFile) else { return }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        items = payload.items
        discounts = payload.discounts
        sales = payload.sales
        settings = payload.settings
        cart = payload.cart
    }

    private func persist() {
        guard loaded, persists else { return }
        let payload = Payload(items: items, discounts: discounts, sales: sales,
                              settings: settings, cart: cart)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: Self.dataFile, options: .atomic)
    }

    // MARK: - Photos

    func photoURL(_ name: String) -> URL { Self.photoDirectory.appendingPathComponent(name) }

    func image(named name: String?) -> UIImage? {
        guard let name, let data = try? Data(contentsOf: photoURL(name)) else { return nil }
        return UIImage(data: data)
    }

    /// Centre-crops to a square and scales down before writing: a raw camera
    /// frame is several megabytes and none of that detail survives a tile.
    @discardableResult
    func savePhoto(_ image: UIImage) -> String? {
        let side = min(image.size.width, image.size.height)
        let crop = CGRect(x: (image.size.width - side) / 2,
                          y: (image.size.height - side) / 2,
                          width: side, height: side)

        let target = CGSize(width: 420, height: 420)
        let renderer = UIGraphicsImageRenderer(size: target)
        let square = renderer.image { _ in
            let drawn = CGRect(x: -crop.origin.x * target.width / side,
                               y: -crop.origin.y * target.height / side,
                               width: image.size.width * target.width / side,
                               height: image.size.height * target.height / side)
            image.draw(in: drawn)
        }

        guard let data = square.jpegData(compressionQuality: 0.75) else { return nil }
        try? FileManager.default.createDirectory(at: Self.photoDirectory,
                                                 withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: photoURL(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    func deletePhoto(_ name: String?) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: photoURL(name))
    }

    // MARK: - Selling

    func add(item: Item, variant: Variant) {
        let key = "\(item.id)::\(variant.id)"
        if let index = cart.lines.firstIndex(where: { $0.id == key }) {
            cart.lines[index].qty += 1
        } else {
            cart.lines.append(CartLine(id: key, itemID: item.id, variantID: variant.id,
                                       name: item.name, size: variant.label,
                                       unitPrice: variant.price, qty: 1))
        }
    }

    func changeQty(_ lineID: String, by delta: Int) {
        guard let index = cart.lines.firstIndex(where: { $0.id == lineID }) else { return }
        cart.lines[index].qty += delta
        if cart.lines[index].qty <= 0 { cart.lines.remove(at: index) }
    }

    func toggleDiscount(_ id: UUID) {
        if let index = cart.discountIDs.firstIndex(of: id) {
            cart.discountIDs.remove(at: index)
        } else {
            cart.discountIDs.append(id)
        }
    }

    var cartTotals: Totals {
        Register.totals(lines: cart.lines,
                        discounts: discounts,
                        applying: cart.discountIDs,
                        taxRate: settings.taxEnabled ? settings.taxRate : 0)
    }

    func clearCart() {
        cart.lines = []
        cart.discountIDs = []
        cart.note = ""
        cart.tendered = .zero
    }

    /// Records the sale and hands back the change to give, if any.
    @discardableResult
    func completeSale() -> Money {
        guard !cart.isEmpty else { return .zero }
        let totals = cartTotals
        let tendered = cart.method == .cash ? cart.tendered : .zero
        let change = tendered > totals.total ? tendered - totals.total : .zero

        let lines = cart.lines.map {
            SaleLine(itemID: $0.itemID, name: $0.name, size: $0.size,
                     unitPrice: $0.unitPrice, qty: $0.qty)
        }

        sales.append(Sale(lines: lines,
                          subtotal: totals.subtotal,
                          discounts: totals.applied,
                          taxRate: totals.taxRate,
                          tax: totals.tax,
                          total: totals.total,
                          method: cart.method,
                          tendered: tendered,
                          change: change,
                          note: cart.note))
        clearCart()
        return change
    }

    // MARK: - Records

    var liveSales: [Sale] { sales.filter { !$0.voided } }

    func takings(on day: Date) -> Money {
        let calendar = Calendar.current
        return liveSales
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(Money.zero) { $0 + $1.total }
    }

    func salesCount(on day: Date) -> Int {
        let calendar = Calendar.current
        return liveSales.filter { calendar.isDate($0.date, inSameDayAs: day) }.count
    }

    var allTimeTakings: Money { liveSales.reduce(Money.zero) { $0 + $1.total } }

    func toggleVoid(_ id: UUID) {
        guard let index = sales.firstIndex(where: { $0.id == id }) else { return }
        sales[index].voided.toggle()
    }

    func deleteSale(_ id: UUID) {
        sales.removeAll { $0.id == id }
    }

    func delete(item id: UUID) {
        if let item = items.first(where: { $0.id == id }) { deletePhoto(item.photo) }
        items.removeAll { $0.id == id }
        cart.lines.removeAll { $0.itemID == id }
    }

    func delete(discount id: UUID) {
        discounts.removeAll { $0.id == id }
        cart.discountIDs.removeAll { $0 == id }
    }

    func eraseEverything() {
        for item in items { deletePhoto(item.photo) }
        items = []
        discounts = []
        sales = []
        clearCart()
    }

    func loadSampleMenu() {
        items = [
            Item(name: "Latte", variants: [
                Variant(label: "Small", price: Money(cents: 350)),
                Variant(label: "Medium", price: Money(cents: 425)),
                Variant(label: "Large", price: Money(cents: 500))]),
            Item(name: "Drip coffee", variants: [
                Variant(label: "Small", price: Money(cents: 250)),
                Variant(label: "Large", price: Money(cents: 325))]),
            Item(name: "Croissant", variants: [Variant(label: "", price: Money(cents: 375))]),
            Item(name: "Cold brew", variants: [
                Variant(label: "12 oz", price: Money(cents: 400)),
                Variant(label: "16 oz", price: Money(cents: 475))]),
            Item(name: "Tote bag", variants: [Variant(label: "", price: Money(cents: 1200))])
        ]
        discounts = [
            Discount(label: "Regular", kind: .percent, value: 1_000),
            Discount(label: "Staff", kind: .amount, value: 200)
        ]
    }
}

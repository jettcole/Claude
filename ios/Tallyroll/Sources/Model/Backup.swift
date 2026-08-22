import Foundation
import UIKit

/// A single file holding everything, photos included, so a new phone can pick up
/// exactly where the old one left off.
struct Backup: Codable {
    var app = "tallyroll"
    var version = 1
    var exportedAt = Date()
    var settings = AppSettings()
    var items: [Item] = []
    var discounts: [Discount] = []
    var sales: [Sale] = []
    /// File name to base64 JPEG. Photos live outside the working data file, so
    /// they have to be folded in here explicitly or a restore loses them.
    var photos: [String: String] = [:]
}

extension Store {

    func makeBackup() -> Backup {
        var photos: [String: String] = [:]
        for item in items {
            guard let name = item.photo,
                  let data = try? Data(contentsOf: photoURL(name)) else { continue }
            photos[name] = data.base64EncodedString()
        }
        return Backup(settings: settings, items: items, discounts: discounts,
                      sales: sales, photos: photos)
    }

    func backupData() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(makeBackup())
    }

    enum RestoreResult {
        case restored(sales: Int)
        case notABackup
    }

    func restore(from data: Data) -> RestoreResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(Backup.self, from: data) else {
            return .notABackup
        }

        try? FileManager.default.createDirectory(at: Store.photoDirectory,
                                                 withIntermediateDirectories: true)
        for (name, encoded) in backup.photos {
            guard let bytes = Data(base64Encoded: encoded) else { continue }
            try? bytes.write(to: photoURL(name), options: .atomic)
        }

        settings = backup.settings
        items = backup.items
        discounts = backup.discounts
        sales = backup.sales
        clearCart()
        return .restored(sales: backup.sales.count)
    }
}

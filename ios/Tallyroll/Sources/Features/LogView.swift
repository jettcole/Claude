import SwiftUI

struct LogView: View {
    @EnvironmentObject private var store: Store
    @State private var sharing: ShareItem?

    var body: some View {
        NavigationStack {
            Group {
                if store.sales.isEmpty {
                    ContentUnavailableView {
                        Label("No sales recorded", systemImage: "list.bullet.rectangle.portrait")
                    } description: {
                        Text("Every completed purchase lands here — what sold, in what size, and for how much.")
                    }
                } else {
                    list
                }
            }
            .navigationTitle("Sales log")
            .toolbar {
                if !store.sales.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            exportCSV()
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(item: $sharing) { ShareSheet(url: $0.url) }
        }
    }

    private var list: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    stat("Today", store.takings(on: Date()).formatted(store.symbol), accent: true)
                    stat("Sales today", "\(store.salesCount(on: Date()))", accent: false)
                    stat("All time", store.allTimeTakings.formatted(store.symbol), accent: false)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }

            ForEach(grouped, id: \.day) { group in
                Section {
                    ForEach(group.sales) { sale in
                        NavigationLink {
                            SaleDetailView(saleID: sale.id)
                        } label: {
                            SaleRow(sale: sale)
                        }
                    }
                } header: {
                    HStack {
                        Text(Self.dayLabel(group.day))
                        Spacer()
                        Text(group.sales.filter { !$0.voided }
                                .reduce(Money.zero) { $0 + $1.total }
                                .formatted(store.symbol))
                            .font(.register(13, weight: .medium))
                    }
                }
            }
        }
    }

    private func stat(_ key: String, _ value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(key)
                .font(.register(10, weight: .medium))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Palette.ink3)
            Text(value)
                .font(.register(19, weight: .semibold))
                .foregroundStyle(accent ? Palette.register : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var grouped: [(day: Date, sales: [Sale])] {
        let calendar = Calendar.current
        return Dictionary(grouping: store.sales) { calendar.startOfDay(for: $0.date) }
            .map { (day: $0.key, sales: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    static func dayLabel(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func exportCSV() {
        let csv = CSVExport.make(sales: store.sales, symbol: store.symbol)
        guard let url = CSVExport.writeTemporary(csv, named: CSVExport.stampedName("csv")) else { return }
        sharing = ShareItem(url: url)
    }
}

struct SaleRow: View {
    @EnvironmentObject private var store: Store
    let sale: Sale

    var body: some View {
        HStack(spacing: 11) {
            Text(sale.date.formatted(date: .omitted, time: .shortened))
                .font(.register(12.5))
                .foregroundStyle(Palette.ink3)
                .frame(width: 66, alignment: .leading)

            Circle()
                .fill(dotColour)
                .frame(width: 7, height: 7)

            Text(sale.summary)
                .font(.system(size: 14.5))
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(sale.total.formatted(store.symbol))
                .font(.register(15, weight: .semibold))
        }
        .strikethrough(sale.voided)
        .foregroundStyle(sale.voided ? Palette.ink3 : Palette.ink)
    }

    private var dotColour: Color {
        switch sale.method {
        case .cash: return Palette.register
        case .card: return Palette.brass
        case .other: return Palette.ink3
        }
    }
}

struct SaleDetailView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let saleID: UUID
    @State private var confirmingDelete = false

    private var sale: Sale? { store.sales.first { $0.id == saleID } }

    var body: some View {
        ScrollView {
            if let sale {
                VStack(spacing: 16) {
                    ReceiptView(sale: sale)
                    Button(sale.voided ? "Restore this sale" : "Void this sale") {
                        store.toggleVoid(saleID)
                    }
                    .buttonStyle(.bordered)

                    Button("Delete permanently", role: .destructive) {
                        confirmingDelete = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
            }
        }
        .background(Palette.bg)
        .navigationTitle(sale.map { LogView.dayLabel($0.date) } ?? "Sale")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this sale?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                store.deleteSale(saleID)
                dismiss()
            }
        } message: {
            Text("It disappears from the log and from every export. Voiding keeps the record instead.")
        }
    }
}

struct ReceiptView: View {
    @EnvironmentObject private var store: Store
    let sale: Sale

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if !store.settings.business.isEmpty {
                    Text(store.settings.business)
                        .font(.register(13.5, weight: .semibold))
                }
                HStack {
                    Text(sale.date.formatted(date: .abbreviated, time: .shortened))
                    Spacer()
                    Text(sale.method.label)
                }
                .font(.register(11.5))
                .foregroundStyle(Palette.ink3)

                if sale.voided {
                    Text("Voided — not counted")
                        .font(.register(11.5, weight: .semibold))
                        .tracking(1)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.oxblood)
                        .padding(.top, 4)
                }

                Divider().overlay(Palette.rule).padding(.vertical, 8)

                ForEach(sale.lines) { line in
                    ReceiptRow(name: line.size.isEmpty ? line.name : "\(line.name) · \(line.size)",
                               amount: line.lineTotal.formatted(store.symbol),
                               style: .quiet)
                    Text("\(line.qty) × \(line.unitPrice.formatted(store.symbol))")
                        .font(.register(11.5))
                        .foregroundStyle(Palette.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider().overlay(Palette.rule).padding(.vertical, 8)
                ReceiptRow(name: "Subtotal", amount: sale.subtotal.formatted(store.symbol), style: .quiet)

                ForEach(sale.discounts) { applied in
                    ReceiptRow(name: applied.label,
                               amount: "-" + applied.amount.formatted(store.symbol),
                               style: .discount)
                    Text(applied.reason(store.symbol))
                        .font(.register(11.5))
                        .foregroundStyle(Palette.brass.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if sale.taxRate > 0 {
                    ReceiptRow(name: "Tax " + BasisPoints.describe(sale.taxRate),
                               amount: sale.tax.formatted(store.symbol), style: .quiet)
                }

                Divider().overlay(Palette.rule).padding(.vertical, 8)
                ReceiptRow(name: "Total", amount: sale.total.formatted(store.symbol), style: .total)

                if sale.tendered > .zero {
                    ReceiptRow(name: "Cash received",
                               amount: sale.tendered.formatted(store.symbol), style: .quiet)
                    ReceiptRow(name: "Change given",
                               amount: sale.change.formatted(store.symbol), style: .quiet)
                }

                if !sale.note.isEmpty {
                    Text(sale.note)
                        .font(.register(11.5))
                        .foregroundStyle(Palette.ink3)
                        .padding(.top, 6)
                }
            }
            .padding(14)
            .background(Palette.surfaceHigh)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            TornEdge()
        }
    }
}

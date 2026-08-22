import SwiftUI

struct CheckoutView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var cashText = ""
    @State private var changeGiven: Money?
    @FocusState private var cashFocused: Bool

    private var totals: Totals { store.cartTotals }
    private var change: ChangeState {
        Register.change(total: totals.total, tendered: store.cart.tendered)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let changeGiven {
                    RecordedView(change: changeGiven, symbol: store.symbol) { dismiss() }
                } else {
                    checkout
                }
            }
            .background(Palette.bg)
            .navigationTitle(changeGiven == nil ? "Checkout" : "Recorded")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if changeGiven == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { cashFocused = false }
                }
            }
        }
        .onAppear {
            cashText = store.cart.tendered == .zero ? "" : store.cart.tendered.plain
        }
    }

    private var checkout: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                receipt
                discounts
                paidWith
                if store.cart.method == .cash { cashPad }
                note
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { footer }
    }

    // MARK: - Receipt

    private var receipt: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(store.cart.lines.enumerated()), id: \.element.id) { index, line in
                    if index > 0 { Divider().overlay(Palette.rule) }
                    CartLineRow(line: line)
                }

                if !store.cart.lines.isEmpty {
                    Divider().overlay(Palette.rule).padding(.vertical, 8)
                    ReceiptRow(name: "Subtotal", amount: totals.subtotal.formatted(store.symbol),
                               style: .quiet)

                    ForEach(totals.applied) { applied in
                        ReceiptRow(name: applied.label,
                                   amount: "-" + applied.amount.formatted(store.symbol),
                                   style: .discount)
                        // Spells out the arithmetic, so an odd price can be
                        // justified to whoever is standing there.
                        Text(applied.reason(store.symbol))
                            .font(.register(11.5))
                            .foregroundStyle(Palette.brass.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if totals.applied.count > 1 {
                        ReceiptRow(name: "Taken off in total",
                                   amount: "-" + totals.discountTotal.formatted(store.symbol),
                                   style: .discountStrong)
                    }

                    if totals.taxRate > 0 {
                        ReceiptRow(name: "Tax " + BasisPoints.describe(totals.taxRate),
                                   amount: totals.tax.formatted(store.symbol),
                                   style: .quiet)
                    }

                    Divider().overlay(Palette.rule).padding(.vertical, 8)
                    ReceiptRow(name: "Total", amount: totals.total.formatted(store.symbol),
                               style: .total)
                } else {
                    Text("Nothing in this sale yet.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(Palette.surfaceHigh)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            TornEdge()
        }
    }

    // MARK: - Discounts

    @ViewBuilder private var discounts: some View {
        if store.discounts.isEmpty {
            Text("No discounts set up yet — you can add them under Items.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Discounts").eyebrow()
                FlowRow(spacing: 8) {
                    ForEach(store.discounts) { discount in
                        let on = store.cart.discountIDs.contains(discount.id)
                        Button { store.toggleDiscount(discount.id) } label: {
                            HStack(spacing: 6) {
                                Text(discount.label).font(.system(size: 14, weight: .semibold))
                                Text(discount.summary(store.symbol)).font(.register(12.5))
                            }
                            .padding(.horizontal, 13)
                            .frame(height: 38)
                            .background(on ? Palette.brassSoft : Palette.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(on ? Palette.brass : Palette.rule))
                            .foregroundStyle(on ? Palette.brass : Palette.ink2)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var paidWith: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Paid with").eyebrow()
            Picker("Paid with", selection: Binding(
                get: { store.cart.method },
                set: { store.cart.method = $0 }
            )) {
                ForEach(PaymentMethod.allCases) { method in
                    Text(method.label).tag(method)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Cash

    private var cashPad: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cash").eyebrow()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Received").eyebrow()
                    TextField("0.00", text: $cashText)
                        .keyboardType(.decimalPad)
                        .focused($cashFocused)
                        .multilineTextAlignment(.trailing)
                        .font(.register(23, weight: .semibold))
                        .onChange(of: cashText) { _, entered in
                            store.cart.tendered = Money(text: entered)
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                FlowRow(spacing: 8) {
                    ForEach(Register.tenderSuggestions(for: totals.total), id: \.cents) { amount in
                        tenderChip(amount == totals.total ? "Exact" : amount.formatted(store.symbol),
                                   selected: store.cart.tendered == amount) {
                            cashText = amount.plain
                        }
                    }
                    tenderChip("Clear", selected: false) { cashText = "" }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 13)

                changeReadout(compact: false)
            }
            .background(Palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.rule.opacity(0.6)))
        }
    }

    private func tenderChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 13)
                .frame(height: 38)
                .background(selected ? Palette.registerSoft : Palette.surfaceHigh, in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? Palette.register : Palette.rule))
                .foregroundStyle(selected ? Palette.register : Palette.ink2)
        }
        .buttonStyle(.plain)
    }

    private func changeReadout(compact: Bool) -> some View {
        HStack {
            Text(change.label).eyebrow()
            Spacer()
            Text(change.amount(store.symbol))
                .font(.register(compact ? 20 : 27, weight: .semibold))
                .foregroundStyle(changeColour)
        }
        .padding(.horizontal, compact ? 14 : 16)
        .padding(.vertical, compact ? 9 : 13)
        .background(changeBackground)
    }

    private var changeColour: Color {
        switch change {
        case .idle: return Palette.ink3
        case .due: return Palette.register
        case .owed: return Palette.oxblood
        }
    }

    private var changeBackground: Color {
        switch change {
        case .idle: return Palette.sunk
        case .due: return Palette.registerSoft
        case .owed: return Palette.oxbloodSoft
        }
    }

    private var note: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (optional)").eyebrow()
            TextField("Customer name, stall, anything", text: Binding(
                get: { store.cart.note },
                set: { store.cart.note = $0 }
            ))
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.rule.opacity(0.6)))
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 9) {
            // The change owed is the one number that must never need a scroll.
            if store.cart.method == .cash && !store.cart.isEmpty {
                changeReadout(compact: true)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                cashFocused = false
                let given = store.completeSale()
                if given > .zero {
                    changeGiven = given
                } else {
                    dismiss()
                }
            } label: {
                Text("Complete purchase · \(totals.total.formatted(store.symbol))")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.cart.isEmpty)

            Button("Clear this sale") {
                store.clearCart()
                cashText = ""
                dismiss()
            }
            .disabled(store.cart.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }
}

/// Shown after recording a cash sale, so the change to hand back cannot be missed.
struct RecordedView: View {
    let change: Money
    let symbol: String
    let done: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 46))
                .foregroundStyle(Palette.register)
            Text("Give change").eyebrow()
            Text(change.formatted(symbol))
                .font(.register(46, weight: .semibold))
                .foregroundStyle(Palette.register)
            Spacer()
            Button("Done", action: done)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CartLineRow: View {
    @EnvironmentObject private var store: Store
    let line: CartLine

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(line.name).font(.system(size: 15.5, weight: .semibold))
                    if !line.size.isEmpty {
                        Text("· \(line.size)")
                            .font(.system(size: 15.5))
                            .foregroundStyle(Palette.ink3)
                    }
                }
                Text("\(line.unitPrice.formatted(store.symbol)) each")
                    .font(.register(11.5))
                    .foregroundStyle(Palette.ink3)
            }
            Spacer(minLength: 6)

            HStack(spacing: 0) {
                stepButton("minus", label: "One fewer \(line.name)") {
                    store.changeQty(line.id, by: -1)
                }
                Text("\(line.qty)")
                    .font(.register(14.5, weight: .semibold))
                    .frame(minWidth: 22)
                stepButton("plus", label: "One more \(line.name)") {
                    store.changeQty(line.id, by: 1)
                }
            }
            .background(Palette.sunk, in: RoundedRectangle(cornerRadius: 8))

            Text(line.lineTotal.formatted(store.symbol))
                .font(.register(15, weight: .medium))
                .frame(minWidth: 62, alignment: .trailing)
        }
        .padding(.vertical, 9)
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

enum ReceiptRowStyle { case quiet, discount, discountStrong, total }

struct ReceiptRow: View {
    let name: String
    let amount: String
    var style: ReceiptRowStyle = .quiet

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name).font(font).foregroundStyle(colour)
            Spacer(minLength: 8)
            Text(amount).font(font).foregroundStyle(colour)
        }
        .padding(.vertical, 2)
    }

    private var font: Font {
        switch style {
        case .quiet: return .register(13.5)
        case .discount: return .register(13.5)
        case .discountStrong: return .register(13.5, weight: .semibold)
        case .total: return .register(19, weight: .semibold)
        }
    }

    private var colour: Color {
        switch style {
        case .quiet: return Palette.ink2
        case .discount, .discountStrong: return Palette.brass
        case .total: return Palette.ink
        }
    }
}

/// The perforated tear-off at the bottom of a receipt roll.
struct TornEdge: View {
    var body: some View {
        Canvas { context, size in
            let tooth: CGFloat = 14
            var path = Path()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: size.width, y: 0))
            var x = size.width
            while x > 0 {
                path.addLine(to: CGPoint(x: max(x - tooth / 2, 0), y: size.height))
                path.addLine(to: CGPoint(x: max(x - tooth, 0), y: 0))
                x -= tooth
            }
            path.closeSubpath()
            context.fill(path, with: .color(Palette.surfaceHigh))
        }
        .frame(height: 9)
    }
}

/// Chips that wrap onto the next line, which SwiftUI has no built-in layout for.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

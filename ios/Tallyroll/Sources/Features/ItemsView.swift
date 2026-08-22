import SwiftUI

struct ItemsView: View {
    @EnvironmentObject private var store: Store
    @State private var editingItem: Item?
    @State private var addingItem = false
    @State private var editingDiscount: Discount?
    @State private var addingDiscount = false

    var body: some View {
        NavigationStack {
            List {
                Section("What you sell") {
                    if store.items.isEmpty {
                        Button("Load a sample menu") { store.loadSampleMenu() }
                    }
                    ForEach(store.items) { item in
                        Button { editingItem = item } label: { ItemRow(item: item) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        offsets.map { store.items[$0].id }.forEach(store.delete(item:))
                    }
                    Button {
                        addingItem = true
                    } label: {
                        Label("Add item", systemImage: "plus")
                    }
                }

                Section {
                    ForEach(store.discounts) { discount in
                        Button { editingDiscount = discount } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(discount.label)
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(discount.summary(store.symbol) + " off")
                                        .font(.register(12))
                                        .foregroundStyle(Palette.ink3)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Palette.ink3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        offsets.map { store.discounts[$0].id }.forEach(store.delete(discount:))
                    }
                    Button {
                        addingDiscount = true
                    } label: {
                        Label("Add discount", systemImage: "plus")
                    }
                } header: {
                    Text("Discounts")
                } footer: {
                    Text("Discounts become tap-to-apply buttons at checkout. Several can stack, each working on what is left after the one before it.")
                }
            }
            .navigationTitle("Items")
            .sheet(item: $editingItem) { ItemEditorView(editing: $0) }
            .sheet(isPresented: $addingItem) { ItemEditorView(editing: nil) }
            .sheet(item: $editingDiscount) { DiscountEditorView(editing: $0) }
            .sheet(isPresented: $addingDiscount) { DiscountEditorView(editing: nil) }
        }
    }
}

struct ItemRow: View {
    @EnvironmentObject private var store: Store
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            if let image = store.image(named: item.photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.system(size: 16, weight: .semibold))
                Text(detail)
                    .font(.register(12))
                    .foregroundStyle(Palette.ink3)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink3)
        }
    }

    private var detail: String {
        guard item.hasSizes else {
            return item.variants.first?.price.formatted(store.symbol) ?? ""
        }
        return item.variants
            .map { "\($0.label.isEmpty ? "—" : $0.label) \($0.price.formatted(store.symbol))" }
            .joined(separator: "   ")
    }
}

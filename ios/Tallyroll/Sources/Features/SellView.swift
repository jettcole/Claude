import SwiftUI

struct SellView: View {
    @EnvironmentObject private var store: Store
    @State private var picking: Item?
    @State private var checkingOut = false
    @State private var addingItem = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.items.isEmpty {
                    emptyMenu
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(store.items) { item in
                            ItemTile(item: item, count: store.cart.count(of: item.id)) {
                                tapped(item)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(Palette.bg)
            .navigationTitle("Sell")
            .safeAreaInset(edge: .bottom) { drawer }
            .sheet(item: $picking) { item in
                SizePickerSheet(item: item)
            }
            .sheet(isPresented: $checkingOut) {
                CheckoutView()
            }
            .sheet(isPresented: $addingItem) {
                ItemEditorView(editing: nil)
            }
        }
    }

    private func tapped(_ item: Item) {
        if item.variants.count == 1, let only = item.variants.first {
            store.add(item: item, variant: only)
        } else {
            picking = item
        }
    }

    private var emptyMenu: some View {
        VStack(spacing: 10) {
            Text("No items yet")
                .font(.title3.weight(.semibold))
            Text("Add the things you sell — each one can carry as many sizes and prices as it needs.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .padding(.bottom, 6)
            Button("Add an item") { addingItem = true }
                .buttonStyle(.borderedProminent)
            Button("Load a sample menu") { store.loadSampleMenu() }
                .buttonStyle(.borderless)
        }
        .padding(32)
        .frame(maxWidth: 380)
    }

    /// The running total, pinned above the tab bar the way a drawer sits under
    /// the counter.
    @ViewBuilder private var drawer: some View {
        if !store.cart.isEmpty {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(store.cart.count) \(store.cart.count == 1 ? "item" : "items")")
                        .font(.register(11, weight: .medium))
                        .tracking(0.9)
                        .textCase(.uppercase)
                        .opacity(0.78)
                    Text(store.cartTotals.total.formatted(store.symbol))
                        .font(.register(21, weight: .semibold))
                }
                Spacer(minLength: 8)
                Button("Checkout") { checkingOut = true }
                    .font(.headline)
                    .foregroundStyle(Palette.register)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 12))
            }
            .foregroundStyle(.white)
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 10)
            .background(Palette.register, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }
}

struct ItemTile: View {
    @EnvironmentObject private var store: Store
    let item: Item
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                if let image = store.image(named: item.photo) {
                    photoTile(image)
                } else {
                    textTile
                }
                if count > 0 {
                    Text("\(count)")
                        .font(.register(12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Palette.register, in: Capsule())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(item.priceRange(store.symbol))")
    }

    /// With a photo, the picture takes the place of the name — quicker to hit
    /// accurately with a queue waiting.
    private func photoTile(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(height: 132)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomLeading) {
                footer(onPhoto: true)
                    .padding(.horizontal, 11)
                    .padding(.bottom, 9)
                    .padding(.top, 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(colors: [.black.opacity(0.85), .black.opacity(0)],
                                       startPoint: .bottom, endPoint: .top)
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var textTile: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.name)
                .font(.system(size: 16.5, weight: .semibold))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            footer(onPhoto: false)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Palette.rule.opacity(0.6)))
    }

    private func footer(onPhoto: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.priceRange(store.symbol))
                .font(.register(13.5, weight: onPhoto ? .semibold : .medium))
                .foregroundStyle(onPhoto ? Color.white : Palette.ink2)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if item.variants.count > 1 {
                Text("\(item.variants.count) sizes")
                    .font(.register(9.5, weight: .medium))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(onPhoto ? Palette.ink : Palette.register)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(onPhoto ? Color.white.opacity(0.92) : Palette.registerSoft,
                                in: RoundedRectangle(cornerRadius: 5))
            }
        }
    }
}

struct SizePickerSheet: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    let item: Item

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if let image = store.image(named: item.photo) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    ForEach(item.variants) { variant in
                        Button {
                            store.add(item: item, variant: variant)
                            dismiss()
                        } label: {
                            HStack {
                                Text(variant.label.isEmpty ? item.name : variant.label)
                                    .font(.system(size: 16.5, weight: .semibold))
                                Spacer()
                                Text(variant.price.formatted(store.symbol))
                                    .font(.register(16, weight: .medium))
                                    .foregroundStyle(Palette.register)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 58)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.rule.opacity(0.7)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Palette.bg)
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

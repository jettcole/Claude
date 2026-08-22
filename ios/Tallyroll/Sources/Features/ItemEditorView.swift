import SwiftUI
import PhotosUI

/// A variant being edited, with its price still as typed text.
struct VariantDraft: Identifiable {
    var id = UUID()
    var label: String = ""
    var priceText: String = ""
}

struct ItemEditorView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let editing: Item?

    @State private var name = ""
    @State private var drafts: [VariantDraft] = [VariantDraft()]
    @State private var photoName: String?
    @State private var showCamera = false
    @State private var libraryChoice: PhotosPickerItem?
    @State private var problem: String?
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Item name") {
                    TextField("Latte, T-shirt, Cinnamon bun", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    if let image = store.image(named: photoName) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 190)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    }
                    if UIImagePickerController.cameraAvailable {
                        Button {
                            showCamera = true
                        } label: {
                            Label(photoName == nil ? "Take photo" : "Retake photo",
                                  systemImage: "camera")
                        }
                    }
                    PhotosPicker(selection: $libraryChoice, matching: .images) {
                        Label(photoName == nil ? "Choose photo" : "Replace photo",
                              systemImage: "photo.on.rectangle")
                    }
                    if photoName != nil {
                        Button(role: .destructive) {
                            discardUnsavedPhoto()
                            photoName = nil
                        } label: {
                            Label("Remove photo", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Photo")
                } footer: {
                    Text("With a photo, the Sell screen shows the picture instead of the name — quicker to hit accurately with a queue waiting. The name still appears on receipts and in exports.")
                }

                Section {
                    ForEach($drafts) { $draft in
                        HStack(spacing: 10) {
                            TextField(drafts.count > 1 ? "Size or option" : "Size (leave blank if none)",
                                      text: $draft.label)
                            TextField("0.00", text: $draft.priceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.register(15))
                                .frame(width: 90)
                        }
                    }
                    .onDelete { offsets in
                        guard drafts.count > 1 else { return }
                        drafts.remove(atOffsets: offsets)
                    }
                    Button {
                        drafts.append(VariantDraft())
                    } label: {
                        Label("Add another size", systemImage: "plus")
                    }
                } header: {
                    Text("Sizes & prices")
                } footer: {
                    Text("One size with a blank name goes straight into the sale on a single tap. Two or more, and Tallyroll asks which size first.")
                }

                if editing != nil {
                    Section {
                        Button("Delete item", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(editing == nil ? "New item" : "Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        discardUnsavedPhoto()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { image in
                    replacePhoto(with: image)
                }
                .ignoresSafeArea()
            }
            .onChange(of: libraryChoice) { _, choice in
                guard let choice else { return }
                Task {
                    if let data = try? await choice.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        replacePhoto(with: image)
                    }
                    libraryChoice = nil
                }
            }
            .alert("Can't save yet", isPresented: Binding(
                get: { problem != nil },
                set: { if !$0 { problem = nil } }
            )) {
                Button("OK", role: .cancel) { problem = nil }
            } message: {
                Text(problem ?? "")
            }
            .confirmationDialog("Delete this item?", isPresented: $confirmingDelete,
                                titleVisibility: .visible) {
                Button("Delete item", role: .destructive) {
                    if let editing { store.delete(item: editing.id) }
                    dismiss()
                }
            } message: {
                Text("Sales already recorded keep their own copy of the name, size and price, so the log stays intact.")
            }
            .onAppear(perform: loadExisting)
        }
    }

    private func loadExisting() {
        guard let editing, drafts.count == 1, drafts[0].label.isEmpty, drafts[0].priceText.isEmpty else { return }
        name = editing.name
        photoName = editing.photo
        drafts = editing.variants.map {
            VariantDraft(id: $0.id, label: $0.label, priceText: $0.price.plain)
        }
    }

    private func replacePhoto(with image: UIImage) {
        discardUnsavedPhoto()
        photoName = store.savePhoto(image)
    }

    /// Removes a photo written during this edit that is not the one already on
    /// the item, so cancelling leaves no orphan file behind.
    private func discardUnsavedPhoto() {
        if let photoName, photoName != editing?.photo {
            store.deletePhoto(photoName)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            problem = "Give the item a name first."
            return
        }

        let variants = drafts.map {
            Variant(id: $0.id,
                    label: $0.label.trimmingCharacters(in: .whitespacesAndNewlines),
                    price: Money(text: $0.priceText))
        }

        guard variants.allSatisfy({ $0.price > .zero }) else {
            problem = "Every size needs a price above zero."
            return
        }
        if variants.count > 1, variants.contains(where: { $0.label.isEmpty }) {
            problem = "Name each size when there is more than one."
            return
        }

        if let editing, let index = store.items.firstIndex(where: { $0.id == editing.id }) {
            if editing.photo != photoName { store.deletePhoto(editing.photo) }
            store.items[index].name = trimmedName
            store.items[index].variants = variants
            store.items[index].photo = photoName
        } else {
            store.items.append(Item(name: trimmedName, photo: photoName, variants: variants))
        }
        dismiss()
    }
}

struct DiscountEditorView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss

    let editing: Discount?

    @State private var label = ""
    @State private var kind: DiscountKind = .percent
    @State private var valueText = ""
    @State private var problem: String?
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Regular, Staff, Market day", text: $label)
                        .textInputAutocapitalization(.words)
                }
                Section("Kind") {
                    Picker("Kind", selection: $kind) {
                        Text("Percent off").tag(DiscountKind.percent)
                        Text("Amount off").tag(DiscountKind.amount)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text(kind == .percent ? "Percent" : "Amount")
                        Spacer()
                        TextField(kind == .percent ? "10" : "2.00", text: $valueText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.register(16))
                            .frame(width: 110)
                    }
                }
                if editing != nil {
                    Section {
                        Button("Delete discount", role: .destructive) {
                            if let editing { store.delete(discount: editing.id) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "New discount" : "Edit discount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .alert("Can't save yet", isPresented: Binding(
                get: { problem != nil },
                set: { if !$0 { problem = nil } }
            )) {
                Button("OK", role: .cancel) { problem = nil }
            } message: {
                Text(problem ?? "")
            }
            .onAppear {
                guard let editing, !loaded else { return }
                loaded = true
                label = editing.label
                kind = editing.kind
                valueText = editing.kind == .percent
                    ? String(format: "%g", Double(editing.value) / 100)
                    : Money(cents: editing.value).plain
            }
        }
    }

    private func save() {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            problem = "Give the discount a name first."
            return
        }

        let value = kind == .percent ? BasisPoints.parse(valueText) : Money(text: valueText).cents
        guard value > 0 else {
            problem = "Enter how much comes off."
            return
        }
        if kind == .percent, value > 10_000 {
            problem = "A percentage discount can't go above 100%."
            return
        }

        if let editing, let index = store.discounts.firstIndex(where: { $0.id == editing.id }) {
            store.discounts[index].label = trimmed
            store.discounts[index].kind = kind
            store.discounts[index].value = value
        } else {
            store.discounts.append(Discount(label: trimmed, kind: kind, value: value))
        }
        dismiss()
    }
}

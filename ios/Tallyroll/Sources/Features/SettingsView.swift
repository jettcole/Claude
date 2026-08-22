import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: Store
    @State private var taxText = ""
    @State private var sharing: ShareItem?
    @State private var importing = false
    @State private var confirmingErase = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Your stall") {
                    TextField("Business name", text: Binding(
                        get: { store.settings.business },
                        set: { store.settings.business = $0 }
                    ))
                    .textInputAutocapitalization(.words)

                    HStack {
                        Text("Currency symbol")
                        Spacer()
                        TextField("$", text: Binding(
                            get: { store.settings.currency },
                            set: { store.settings.currency = String($0.prefix(3)) }
                        ))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                    }
                }

                Section {
                    Toggle("Add tax at checkout", isOn: Binding(
                        get: { store.settings.taxEnabled },
                        set: { store.settings.taxEnabled = $0 }
                    ))
                    if store.settings.taxEnabled {
                        HStack {
                            Text("Rate (%)")
                            Spacer()
                            TextField("8.25", text: $taxText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.register(16))
                                .frame(width: 90)
                                .onChange(of: taxText) { _, entered in
                                    store.settings.taxRate = BasisPoints.parse(entered)
                                }
                        }
                    }
                } header: {
                    Text("Tax")
                } footer: {
                    Text("Calculated on the total after any discounts.")
                }

                Section {
                    Button {
                        exportCSV()
                    } label: {
                        Label("Export sales (CSV)", systemImage: "tablecells")
                    }
                    .disabled(store.sales.isEmpty)

                    Button {
                        exportBackup()
                    } label: {
                        Label("Export backup", systemImage: "arrow.up.doc")
                    }

                    Button {
                        importing = true
                    } label: {
                        Label("Restore from backup", systemImage: "arrow.down.doc")
                    }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("A backup holds your items, photos, discounts and every sale, so you can move to another phone. Restoring replaces what is on this one.")
                }

                Section {
                    Button("Erase everything", role: .destructive) { confirmingErase = true }
                } footer: {
                    Text("Everything lives on this phone only — nothing is uploaded anywhere. Export a backup now and then so a lost phone doesn't take the takings with it.\n\nTALLYROLL · \(store.items.count) items · \(store.sales.count) sales recorded")
                        .font(.footnote)
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $sharing) { ShareSheet(url: $0.url) }
            .fileImporter(isPresented: $importing,
                          allowedContentTypes: [.json, .plainText]) { result in
                restore(result)
            }
            .confirmationDialog("Erase everything?", isPresented: $confirmingErase,
                                titleVisibility: .visible) {
                Button("Erase everything", role: .destructive) {
                    store.eraseEverything()
                    message = "Everything erased."
                }
            } message: {
                Text("Every item, photo, discount and recorded sale is deleted from this phone. Export a backup first if you might want any of it back.")
            }
            .alert("Tallyroll", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) { message = nil }
            } message: {
                Text(message ?? "")
            }
            .onAppear {
                taxText = store.settings.taxRate == 0
                    ? ""
                    : String(format: "%g", Double(store.settings.taxRate) / 100)
            }
        }
    }

    private func exportCSV() {
        let csv = CSVExport.make(sales: store.sales, symbol: store.symbol)
        guard let url = CSVExport.writeTemporary(csv, named: CSVExport.stampedName("csv")) else { return }
        sharing = ShareItem(url: url)
    }

    private func exportBackup() {
        guard let data = store.backupData() else {
            message = "Couldn't build the backup file."
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(CSVExport.stampedName("json"))
        do {
            try data.write(to: url, options: .atomic)
            sharing = ShareItem(url: url)
        } catch {
            message = "Couldn't write the backup file."
        }
    }

    private func restore(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            message = "Couldn't open that file."
            return
        }
        // A file picked from Files lives outside the app's sandbox.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            message = "Couldn't read that file."
            return
        }
        switch store.restore(from: data) {
        case .restored(let count):
            message = "Restored \(count) sale\(count == 1 ? "" : "s")."
        case .notABackup:
            message = "That file isn't a Tallyroll backup."
        }
    }
}

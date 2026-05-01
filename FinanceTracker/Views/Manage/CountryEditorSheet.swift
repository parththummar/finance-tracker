import SwiftUI
import SwiftData
import AppKit

struct CountryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Country.code) private var allCountries: [Country]
    let existing: Country?

    @State private var code: String = ""
    @State private var name: String = ""
    @State private var flag: String = ""
    @State private var defaultCurrency: Currency = .USD
    @State private var color: Color = .blue
    @State private var errorMessage: String?
    @State private var showingFlagPicker: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Country" : "Edit Country").font(Typo.serifNum(24))
            Form {
                TextField("Code (US, IN)", text: $code).textCase(.uppercase)
                TextField("Name", text: $name)
                HStack(spacing: 8) {
                    TextField("Flag emoji", text: $flag)
                    if !flag.isEmpty {
                        Text(flag).font(.system(size: 22))
                    }
                    Button {
                        showingFlagPicker = true
                    } label: {
                        Label("Pick country…", systemImage: "flag.fill")
                    }
                    .help("Searchable list of all country flags")
                }
                Picker("Default Currency", selection: $defaultCurrency) {
                    ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                ColorPicker("Chart color", selection: $color, supportsOpacity: false)
            }
            .formStyle(.grouped)

            if let err = errorMessage {
                Text(err).foregroundStyle(Color.lLoss).font(Typo.sans(12))
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button { save() } label: { Label("Save", systemImage: "checkmark") }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 480)
        .onAppear(perform: prefill)
        .sheet(isPresented: $showingFlagPicker) {
            FlagPickerSheet(flag: $flag, code: $code)
        }
    }

    private func prefill() {
        guard let c = existing else {
            let taken = allCountries.compactMap { $0.colorHex }
            color = Palette.unusedFallback(taken: taken)
            return
        }
        code = c.code; name = c.name; flag = c.flag; defaultCurrency = c.defaultCurrency
        if let hex = c.colorHex, let col = Color.fromHex(hex) {
            color = col
        } else {
            let taken = allCountries.filter { $0.id != c.id }.compactMap { $0.colorHex }
            color = Palette.unusedFallback(taken: taken)
        }
    }

    private func save() {
        let trimCode = code.uppercased().trimmingCharacters(in: .whitespaces)
        let trimName = name.trimmingCharacters(in: .whitespaces)
        guard !trimCode.isEmpty, !trimName.isEmpty else { errorMessage = "Code and name required."; return }
        let hex = color.toHex()
        if let c = existing {
            c.code = trimCode; c.name = trimName; c.flag = flag; c.defaultCurrency = defaultCurrency
            c.colorHex = hex
        } else {
            let c = Country(code: trimCode, name: trimName, flag: flag, defaultCurrency: defaultCurrency)
            c.colorHex = hex
            context.insert(c)
        }
        do { try context.save(); dismiss() }
        catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }
}

import SwiftUI
import SwiftData

struct AccountEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Country.code) private var countries: [Country]
    @Query(sort: \AssetType.name) private var assetTypes: [AssetType]

    let existing: Account?

    @State private var name: String = ""
    @State private var personID: UUID?
    @State private var countryID: UUID?
    @State private var assetTypeID: UUID?
    @State private var nativeCurrency: Currency = .USD
    @State private var institution: String = ""
    @State private var notes: String = ""
    @State private var isActive: Bool = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Account" : "Edit Account").font(Typo.serifNum(24))

            Form {
                TextField("Name", text: $name)

                Picker("Person", selection: $personID) {
                    Text("—").tag(UUID?.none)
                    ForEach(people) { Text($0.name).tag(UUID?.some($0.id)) }
                }
                Picker("Country", selection: $countryID) {
                    Text("—").tag(UUID?.none)
                    ForEach(countries) { Text("\($0.flag) \($0.name)").tag(UUID?.some($0.id)) }
                }
                .onChange(of: countryID) { _, new in
                    if existing == nil, let c = countries.first(where: { $0.id == new }) {
                        nativeCurrency = c.defaultCurrency
                    }
                }
                Picker("Asset Type", selection: $assetTypeID) {
                    Text("—").tag(UUID?.none)
                    ForEach(assetTypes) { Text("\($0.name) (\($0.category.rawValue))").tag(UUID?.some($0.id)) }
                }

                Picker("Native Currency", selection: $nativeCurrency) {
                    ForEach(Currency.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                TextField("Institution (optional)", text: $institution)
                TextField("Notes (optional)", text: $notes)

                Toggle("Active", isOn: $isActive)
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
        .frame(minWidth: 520)
        .onAppear(perform: prefill)
    }

    private func prefill() {
        guard let a = existing else { return }
        name = a.name
        personID = a.person?.id
        countryID = a.country?.id
        assetTypeID = a.assetType?.id
        nativeCurrency = a.nativeCurrency
        institution = a.institution
        notes = a.notes
        isActive = a.isActive
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Name required."; return }
        guard let p = people.first(where: { $0.id == personID }) else { errorMessage = "Pick person."; return }
        guard let c = countries.first(where: { $0.id == countryID }) else { errorMessage = "Pick country."; return }
        guard let t = assetTypes.first(where: { $0.id == assetTypeID }) else { errorMessage = "Pick asset type."; return }

        if let a = existing {
            a.name = trimmed
            a.person = p
            a.country = c
            a.assetType = t
            a.nativeCurrency = nativeCurrency
            a.institution = institution
            a.notes = notes
            a.isActive = isActive
        } else {
            let a = Account(name: trimmed, person: p, country: c, assetType: t,
                            nativeCurrency: nativeCurrency, institution: institution,
                            notes: notes, isActive: isActive)
            context.insert(a)
        }

        do { try context.save(); dismiss() }
        catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }
}

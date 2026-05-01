import SwiftUI
import SwiftData

struct AccountEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \Country.code) private var countries: [Country]
    @Query(sort: \AssetType.name) private var assetTypes: [AssetType]
    @Query(sort: \Account.name) private var allAccounts: [Account]

    let existing: Account?

    @State private var name: String = ""
    @State private var personID: UUID?
    @State private var countryID: UUID?
    @State private var assetTypeID: UUID?
    @State private var nativeCurrency: Currency = .USD
    @State private var institution: String = ""
    @State private var notes: String = ""
    @State private var isActive: Bool = true
    @State private var groupName: String = ""
    @State private var errorMessage: String?
    @State private var savedToast: String?

    @AppStorage("acct.lastPersonID")    private var lastPersonIDStr: String = ""
    @AppStorage("acct.lastCountryID")   private var lastCountryIDStr: String = ""
    @AppStorage("acct.lastAssetTypeID") private var lastAssetTypeIDStr: String = ""
    @AppStorage("acct.lastCurrency")    private var lastCurrencyRaw: String = Currency.USD.rawValue
    @AppStorage("acct.lastGroup")       private var lastGroup: String = ""
    @AppStorage("acct.lastInstitution") private var lastInstitution: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(existing == nil ? "New Account" : "Edit Account").font(Typo.serifNum(24))

            Form {
                TextField("Name", text: $name)

                if let warn = duplicateWarning {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.lLoss)
                            .font(.system(size: 10))
                        Text(warn)
                            .font(Typo.sans(11))
                            .foregroundStyle(Color.lLoss)
                    }
                }

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

                groupPicker

                Toggle("Active", isOn: $isActive)
            }
            .formStyle(.grouped)

            if let err = errorMessage {
                Text(err).foregroundStyle(Color.lLoss).font(Typo.sans(12))
            }

            HStack {
                if let toast = savedToast {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lGain)
                            .font(.system(size: 11))
                        Text(toast).font(Typo.sans(11)).foregroundStyle(Color.lInk2)
                    }
                    .transition(.opacity)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                if existing == nil {
                    Button { save(continueAdding: true) } label: {
                        Label("Save & Add Next", systemImage: "plus.circle")
                    }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                }
                Button { save(continueAdding: false) } label: {
                    Label(existing == nil ? "Save & Close" : "Save", systemImage: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 560)
        .onAppear(perform: prefill)
        .animation(.easeInOut(duration: 0.2), value: savedToast)
    }

    private var existingGroupNames: [String] {
        let names = allAccounts.map(\.groupName).filter { !$0.isEmpty }
        return Array(Set(names)).sorted()
    }

    @ViewBuilder
    private var groupPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Group")
                Spacer()
                if !existingGroupNames.isEmpty {
                    Menu {
                        Button("None") { groupName = "" }
                        Divider()
                        ForEach(existingGroupNames, id: \.self) { g in
                            Button(g) { groupName = g }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("Pick existing")
                            Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                        }
                        .font(Typo.mono(11))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                TextField("Type group name (or leave empty)", text: $groupName)
                    .frame(width: 220)
            }
            Text("Type a new name to create a group, or pick an existing one. Groups are created on save.")
                .font(Typo.sans(10.5))
                .foregroundStyle(Color.lInk3)
        }
    }

    private var duplicateWarning: String? {
        let trimmed = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 2 else { return nil }
        let dups = allAccounts.filter {
            $0.id != existing?.id && $0.name.lowercased() == trimmed
        }
        guard !dups.isEmpty else { return nil }
        let owners = Array(Set(dups.compactMap { $0.person?.name })).sorted()
        if owners.isEmpty {
            return "Another account already uses this name."
        }
        return "Name already used by: \(owners.joined(separator: ", "))."
    }

    private func prefill() {
        if let a = existing {
            name = a.name
            personID = a.person?.id
            countryID = a.country?.id
            assetTypeID = a.assetType?.id
            nativeCurrency = a.nativeCurrency
            institution = a.institution
            notes = a.notes
            isActive = a.isActive
            groupName = a.groupName
            return
        }
        // New account: prefill from last-saved.
        if personID == nil, let id = UUID(uuidString: lastPersonIDStr),
           people.contains(where: { $0.id == id }) { personID = id }
        if countryID == nil, let id = UUID(uuidString: lastCountryIDStr),
           countries.contains(where: { $0.id == id }) { countryID = id }
        if assetTypeID == nil, let id = UUID(uuidString: lastAssetTypeIDStr),
           assetTypes.contains(where: { $0.id == id }) { assetTypeID = id }
        if let c = Currency(rawValue: lastCurrencyRaw) { nativeCurrency = c }
        if institution.isEmpty { institution = lastInstitution }
        if groupName.isEmpty { groupName = lastGroup }
    }

    private func save(continueAdding: Bool = false) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Name required."; return }
        guard let p = people.first(where: { $0.id == personID }) else { errorMessage = "Pick person."; return }
        guard let c = countries.first(where: { $0.id == countryID }) else { errorMessage = "Pick country."; return }
        guard let t = assetTypes.first(where: { $0.id == assetTypeID }) else { errorMessage = "Pick asset type."; return }

        let hardDup = allAccounts.contains {
            $0.id != existing?.id
                && $0.name.lowercased() == trimmed.lowercased()
                && $0.person?.id == p.id
        }
        if hardDup {
            errorMessage = "\(p.name) already owns an account named “\(trimmed)”."
            return
        }

        let trimmedGroup = groupName.trimmingCharacters(in: .whitespaces)
        if let a = existing {
            a.name = trimmed
            a.person = p
            a.country = c
            a.assetType = t
            a.nativeCurrency = nativeCurrency
            a.institution = institution
            a.notes = notes
            a.isActive = isActive
            a.groupName = trimmedGroup
        } else {
            let a = Account(name: trimmed, person: p, country: c, assetType: t,
                            nativeCurrency: nativeCurrency, institution: institution,
                            notes: notes, isActive: isActive)
            a.groupName = trimmedGroup
            context.insert(a)
        }

        do {
            try context.save()
            errorMessage = nil
            // Remember last selections for next "Save & Add Next" / next sheet open.
            lastPersonIDStr    = p.id.uuidString
            lastCountryIDStr   = c.id.uuidString
            lastAssetTypeIDStr = t.id.uuidString
            lastCurrencyRaw    = nativeCurrency.rawValue
            lastGroup          = trimmedGroup
            lastInstitution    = institution

            if continueAdding {
                savedToast = "Added “\(trimmed)”. Continue adding…"
                // Reset name + notes; keep person/country/type/ccy/inst/group.
                name = ""
                notes = ""
                Task {
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    await MainActor.run { savedToast = nil }
                }
            } else {
                dismiss()
            }
        }
        catch { errorMessage = "Save failed: \(error.localizedDescription)" }
    }
}

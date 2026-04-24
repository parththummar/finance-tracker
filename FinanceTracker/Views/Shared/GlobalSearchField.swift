import SwiftUI
import SwiftData

struct GlobalSearchField: View {
    @EnvironmentObject var app: AppState
    @Query(sort: \Account.name)  private var accounts: [Account]
    @Query(sort: \Person.name)   private var people: [Person]
    @Query(sort: \Country.name)  private var countries: [Country]
    @Query(sort: \AssetType.name) private var assetTypes: [AssetType]

    @State private var query: String = ""
    @FocusState private var focused: Bool
    @State private var showResults: Bool = false

    enum Kind { case account, person, country, assetType }

    struct Result: Identifiable {
        let id = UUID()
        let kind: Kind
        let label: String
        let detail: String
        let screen: Screen
        let color: Color
    }

    private var results: [Result] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var out: [Result] = []
        for a in accounts where a.name.lowercased().contains(q) {
            let detail = [a.person?.name, a.assetType?.name, a.country?.name]
                .compactMap { $0 }.joined(separator: " · ")
            let col = a.assetType.map { Palette.color(for: $0.category) } ?? .lInk3
            out.append(Result(kind: .account, label: a.name, detail: detail,
                              screen: .accounts, color: col))
        }
        for p in people where p.name.lowercased().contains(q) {
            let col = Color.fromHex(p.colorHex) ?? Palette.fallback(for: p.name)
            out.append(Result(kind: .person, label: p.name,
                              detail: "Person · \(p.accounts.count) accounts",
                              screen: .people, color: col))
        }
        for c in countries where c.name.lowercased().contains(q) || c.code.lowercased().contains(q) {
            let col = Color.fromHex(c.colorHex) ?? Palette.fallback(for: c.code)
            out.append(Result(kind: .country, label: "\(c.flag) \(c.name)",
                              detail: "Country · \(c.code)",
                              screen: .countries, color: col))
        }
        for t in assetTypes where t.name.lowercased().contains(q) {
            out.append(Result(kind: .assetType, label: t.name,
                              detail: "Asset type · \(t.category.rawValue)",
                              screen: .assetTypes, color: Palette.color(for: t.category)))
        }
        return Array(out.prefix(24))
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.lInk3)
            TextField("Search accounts, people, countries, types", text: $query)
                .textFieldStyle(.plain)
                .font(Typo.sans(12))
                .foregroundStyle(Color.lInk)
                .focused($focused)
                .frame(minWidth: 220, maxWidth: 340)
                .onSubmit {
                    if let first = results.first { open(first) }
                }
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.lInk3)
                }
                .buttonStyle(.plain)
            } else {
                Text("⌘F")
                    .font(Typo.mono(9, weight: .medium))
                    .foregroundStyle(Color.lInk3)
                    .padding(.horizontal, 4)
                    .overlay(Capsule().stroke(Color.lLine, lineWidth: 1))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.lSunken.opacity(0.6))
        .overlay(Capsule().stroke(focused ? Color.lInk.opacity(0.35) : Color.lLine, lineWidth: 1))
        .clipShape(Capsule())
        .onChange(of: app.globalSearchFocusTick) { _, _ in focused = true }
        .onChange(of: focused) { _, newVal in showResults = newVal && !query.isEmpty }
        .onChange(of: query) { _, newVal in showResults = focused && !newVal.isEmpty }
        .popover(isPresented: $showResults, arrowEdge: .top) {
            resultsList
                .frame(width: 360)
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        let r = results
        VStack(alignment: .leading, spacing: 0) {
            if r.isEmpty {
                Text("No matches.")
                    .font(Typo.serifItalic(12))
                    .foregroundStyle(Color.lInk3)
                    .padding(14)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(r.enumerated()), id: \.element.id) { idx, res in
                            Button { open(res) } label: {
                                HStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(res.color)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(res.label)
                                            .font(Typo.sans(12.5, weight: .medium))
                                            .foregroundStyle(Color.lInk)
                                            .lineLimit(1)
                                        Text(res.detail)
                                            .font(Typo.sans(10.5))
                                            .foregroundStyle(Color.lInk3)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    Text(kindBadge(res.kind))
                                        .font(Typo.eyebrow).tracking(1.0)
                                        .foregroundStyle(Color.lInk3)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if idx < r.count - 1 {
                                Divider().overlay(Color.lLine)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .background(Color.lPanel)
    }

    private func kindBadge(_ k: Kind) -> String {
        switch k {
        case .account:   return "ACCT"
        case .person:    return "PERSON"
        case .country:   return "COUNTRY"
        case .assetType: return "TYPE"
        }
    }

    private func open(_ r: Result) {
        app.selectedScreen = r.screen
        query = ""
        showResults = false
        focused = false
    }
}

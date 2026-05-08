import SwiftUI
import SwiftData
import Combine

struct Sidebar: View {
    @EnvironmentObject var app: AppState
    @Query private var liveAccounts: [Account]
    @Query private var liveSnapshots: [Snapshot]
    @Query private var livePeople: [Person]
    @Query private var liveCountries: [Country]

    private var liveIDs: Set<UUID> {
        var s = Set<UUID>()
        liveAccounts.forEach  { s.insert($0.id) }
        liveSnapshots.forEach { s.insert($0.id) }
        livePeople.forEach    { s.insert($0.id) }
        liveCountries.forEach { s.insert($0.id) }
        return s
    }

    /// Below this width → icon-only mode with hover tooltips.
    static let collapseThreshold: CGFloat = 140
    static let minWidth: CGFloat = 56
    static let maxWidth: CGFloat = 320

    @State private var dragStartWidth: Double?
    @State private var liveWidth: Double?

    private var effectiveWidth: Double { liveWidth ?? app.sidebarWidth }
    private var collapsed: Bool { effectiveWidth < Self.collapseThreshold }

    private struct NavItem: Identifiable {
        let id = UUID()
        let screen: Screen
        let label: String
        let icon: String
    }
    private struct NavGroup { let section: String; let items: [NavItem] }

    private let groups: [NavGroup] = [
        NavGroup(section: "Overview", items: [
            NavItem(screen: .dashboard, label: "Net Worth", icon: "chart.bar.doc.horizontal"),
            NavItem(screen: .trends, label: "Trends", icon: "waveform.path.ecg"),
            NavItem(screen: .snapshots, label: "Historical", icon: "chart.line.uptrend.xyaxis"),
            NavItem(screen: .diff, label: "Diff", icon: "arrow.left.arrow.right"),
            NavItem(screen: .reports, label: "Reports", icon: "doc.text.magnifyingglass"),
        ]),
        NavGroup(section: "Breakdown", items: [
            NavItem(screen: .breakdown, label: "By Allocation", icon: "square.grid.2x2"),
            NavItem(screen: .people, label: "By Person", icon: "person.2"),
            NavItem(screen: .countries, label: "By Country", icon: "globe"),
            NavItem(screen: .assetTypes, label: "By Asset Type", icon: "square.stack.3d.up"),
        ]),
        NavGroup(section: "Data", items: [
            NavItem(screen: .accounts, label: "All Assets", icon: "list.bullet"),
            NavItem(screen: .receivables, label: "Receivables", icon: "hourglass"),
        ]),
    ]

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if collapsed {
                    VStack(spacing: 8) {
                        brand
                        collapseToggle
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
                    .padding(.top, 18)
                    .padding(.bottom, 16)
                } else {
                    HStack(spacing: 8) {
                        brand
                        Spacer(minLength: 0)
                        collapseToggle
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 20)
                    .padding(.bottom, 22)
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: collapsed ? 8 : 18) {
                        ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                            VStack(alignment: .leading, spacing: 2) {
                                if !collapsed {
                                    Text(g.section)
                                        .font(Typo.eyebrow)
                                        .textCase(.uppercase)
                                        .tracking(1.5)
                                        .foregroundStyle(Color.lInk4)
                                        .padding(.horizontal, 18)
                                        .padding(.bottom, 4)
                                } else {
                                    Rectangle().fill(Color.lLine.opacity(0.4))
                                        .frame(height: 1)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 4)
                                }
                                ForEach(g.items) { item in
                                    navRow(item)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                if !collapsed {
                    recentSection
                }

                navRow(NavItem(screen: .settings, label: "Settings", icon: "gearshape"))
                    .padding(.bottom, 14)
            }
            .frame(width: max(Double(Self.minWidth), effectiveWidth - 6),
                   alignment: .leading)
            .background(Color.lBg2)
            .clipped()

            // Drag handle
            resizeHandle
        }
        .frame(width: effectiveWidth)
        .clipped()
        .overlay(Rectangle().frame(width: 1).foregroundStyle(Color.lLine), alignment: .trailing)
    }

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6)
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { gesture in
                        // Drive live updates via local @State so AppStorage
                        // (which writes to disk on every change) isn't pounded
                        // 60×/sec. Persist on release.
                        let base = dragStartWidth ?? app.sidebarWidth
                        if dragStartWidth == nil { dragStartWidth = base }
                        let raw = base + Double(gesture.translation.width)
                        let clamped = max(Double(Self.minWidth),
                                          min(Double(Self.maxWidth), raw))
                        liveWidth = clamped
                    }
                    .onEnded { _ in
                        let raw = liveWidth ?? app.sidebarWidth
                        let snapped: Double
                        if raw < 100 { snapped = Double(Self.minWidth) }
                        else if raw < Double(Self.collapseThreshold) { snapped = Double(Self.collapseThreshold) }
                        else { snapped = raw }
                        withAnimation(.easeOut(duration: 0.15)) {
                            liveWidth = snapped
                        }
                        // Persist after the animation lands.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                            app.sidebarWidth = snapped
                            if snapped >= Double(Self.collapseThreshold) {
                                app.sidebarLastExpandedWidth = snapped
                            }
                            liveWidth = nil
                            dragStartWidth = nil
                        }
                    }
            )
    }

    private var collapseToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                if collapsed {
                    let restore = max(Double(Self.collapseThreshold),
                                      app.sidebarLastExpandedWidth)
                    app.sidebarWidth = restore
                } else {
                    app.sidebarLastExpandedWidth = app.sidebarWidth
                    app.sidebarWidth = Double(Self.minWidth)
                }
            }
        } label: {
            Image(systemName: collapsed
                  ? "chevron.right.2"
                  : "sidebar.left")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.lInk2)
                .frame(width: collapsed ? 36 : 26, height: 24)
                .background(Color.lPanel)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.lLine, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .help(collapsed ? "Expand sidebar" : "Collapse to icons")
    }

    @ViewBuilder
    private var recentSection: some View {
        let recents = app.recentItems
        if !recents.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Recent")
                        .font(Typo.eyebrow)
                        .textCase(.uppercase)
                        .tracking(1.5)
                        .foregroundStyle(Color.lInk4)
                    Spacer()
                    Button {
                        app.recentItemsRaw = ""
                        app.objectWillChange.send()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.lInk4)
                    }
                    .buttonStyle(.plain).pointerStyle(.link)
                    .help("Clear recent")
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 4)

                let alive = liveIDs
                ForEach(recents) { item in
                    let isDeleted = !alive.contains(item.entityID)
                    Button {
                        guard !isDeleted else { return }
                        switch item.kind {
                        case .account:
                            app.pendingFocusAccountID = item.entityID
                            app.selectedScreen = .accounts
                        case .snapshot:
                            app.activeSnapshotID = item.entityID
                            app.selectedScreen = .snapshots
                        case .person:
                            app.pendingFocusPersonID = item.entityID
                            app.selectedScreen = .people
                        case .country:
                            app.pendingFocusCountryID = item.entityID
                            app.selectedScreen = .countries
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: iconFor(item.kind))
                                .font(.system(size: 10))
                                .foregroundStyle(isDeleted ? Color.lInk4 : Color.lInk3)
                                .frame(width: 14)
                            Text(item.label)
                                .font(Typo.sans(11.5))
                                .foregroundStyle(isDeleted ? Color.lInk4 : Color.lInk2)
                                .strikethrough(isDeleted, color: Color.lInk4)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(isDeleted ? .default : .link)
                    .disabled(isDeleted)
                    .help(isDeleted ? "Deleted — restore via Edit ▸ Recently Deleted" : "")
                }
            }
            .padding(.bottom, 10)
        }
    }

    private func iconFor(_ k: AppState.RecentKind) -> String {
        switch k {
        case .account:  return "creditcard"
        case .snapshot: return "calendar"
        case .person:   return "person.crop.circle"
        case .country:  return "flag"
        }
    }

    private var brand: some View {
        HStack(spacing: 12) {
            Image(app.appIconChoice.assetName)
                .resizable()
                .interpolation(.high)
                .frame(width: collapsed ? 30 : 38, height: collapsed ? 30 : 38)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.lLine, lineWidth: 1))
            if !collapsed {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Ledgerly")
                        .font(Typo.serifNum(19))
                        .foregroundStyle(Color.lInk)
                        .lineLimit(1)
                    Text("v\(AppInfo.versionString)")
                        .font(Typo.eyebrow)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Color.lInk3)
                        .lineLimit(1)
                }
            }
        }
    }

    private func navRow(_ item: NavItem) -> some View {
        let active = app.selectedScreen == item.screen
        return Button {
            app.selectedScreen = item.screen
        } label: {
            Group {
                if collapsed {
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(active ? Color.lInk : Color.lInk3)
                        .frame(width: 36, height: 32)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 16)
                            .foregroundStyle(active ? Color.lInk : Color.lInk3)
                        Text(item.label)
                            .font(Typo.sans(12.5, weight: active ? .semibold : .medium))
                            .foregroundStyle(active ? Color.lInk : Color.lInk2)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
            }
            .frame(maxWidth: .infinity, alignment: collapsed ? .center : .leading)
            .background(active ? Color.lPanel : Color.lBg2.opacity(0.001))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(active ? Color.lLine : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .padding(.horizontal, collapsed ? 6 : 10)
        .help(collapsed ? item.label : "")
    }

}

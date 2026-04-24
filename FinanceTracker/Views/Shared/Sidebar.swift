import SwiftUI

struct Sidebar: View {
    @EnvironmentObject var app: AppState

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
        ]),
        NavGroup(section: "Breakdown", items: [
            NavItem(screen: .breakdown, label: "By Allocation", icon: "square.grid.2x2"),
            NavItem(screen: .people, label: "By Person", icon: "person.2"),
            NavItem(screen: .countries, label: "By Country", icon: "globe"),
            NavItem(screen: .assetTypes, label: "By Asset Type", icon: "square.stack.3d.up"),
        ]),
        NavGroup(section: "Data", items: [
            NavItem(screen: .accounts, label: "All Assets", icon: "list.bullet"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.horizontal, 18)
                .padding(.top, 20)
                .padding(.bottom, 22)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, g in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.section)
                                .font(Typo.eyebrow)
                                .textCase(.uppercase)
                                .tracking(1.5)
                                .foregroundStyle(Color.lInk4)
                                .padding(.horizontal, 18)
                                .padding(.bottom, 4)
                            ForEach(g.items) { item in
                                navRow(item)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer(minLength: 0)

            navRow(NavItem(screen: .settings, label: "Settings", icon: "gearshape"))
                .padding(.bottom, 14)
        }
        .frame(width: 240)
        .background(Color.lBg2)
        .overlay(Rectangle().frame(width: 1).foregroundStyle(Color.lLine), alignment: .trailing)
    }

    private var brand: some View {
        HStack(spacing: 12) {
            Text("L")
                .font(.custom(Typo.serif, size: 30))
                .foregroundStyle(Color.lPanel)
                .frame(width: 38, height: 38)
                .background(Color.lInk)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text("Ledgerly")
                    .font(Typo.serifNum(19))
                    .foregroundStyle(Color.lInk)
                Text("Wealth · Offline")
                    .font(Typo.eyebrow)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Color.lInk3)
            }
        }
    }

    private func navRow(_ item: NavItem) -> some View {
        let active = app.selectedScreen == item.screen
        return Button {
            app.selectedScreen = item.screen
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(active ? Color.lInk : Color.lInk3)
                Text(item.label)
                    .font(Typo.sans(12.5, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? Color.lInk : Color.lInk2)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(active ? Color.lPanel : Color.lBg2.opacity(0.001))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(active ? Color.lLine : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }

}

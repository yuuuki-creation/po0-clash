import Po0FFI
import SwiftUI

struct ProxiesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var expanded: Set<String> = []

    var body: some View {
        PageScaffold("Proxies") {
            Button {
                for group in model.groups { model.testDelay(group.name) }
            } label: {
                Label("Test all", systemImage: "speedometer")
            }
            .disabled(model.groups.isEmpty || !model.testing.isEmpty)
        } content: {
            if model.status?.mode == .direct {
                EmptyRow(title: "Direct mode", detail: "Traffic goes out directly, so no proxy is used.").groupedSection()
            } else if model.groups.isEmpty {
                EmptyRow(
                    title: "No proxy groups",
                    detail: "Connect with a subscription to load its proxy groups."
                )
                .groupedSection()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(model.groups, id: \.name) { group in
                        GroupCard(group: group, expanded: Binding(
                            get: { expanded.contains(group.name) },
                            set: { open in
                                if open { expanded.insert(group.name) } else { expanded.remove(group.name) }
                            }
                        ))
                    }
                }
            }
        }
        .background(WindowVisibility { model.setVisible(.proxies, $0) })
        .onDisappear { model.setVisible(.proxies, false) }
        .onAppear {
            if expanded.isEmpty, let first = model.groups.first { expanded.insert(first.name) }
        }
    }
}

private struct GroupCard: View {
    @EnvironmentObject private var model: AppModel
    let group: ProxyGroup
    @Binding var expanded: Bool

    private let columns = [GridItem(.adaptive(minimum: 170), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(group.name).fontWeight(.semibold).lineLimit(1)
                                Text(group.kind).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(group.now ?? "—").font(.callout).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text(verbatim: "\(group.nodes.count)").font(.callout).foregroundStyle(.secondary).monospacedDigit()
                Button {
                    model.testDelay(group.name)
                } label: {
                    if model.testing.contains(group.name) {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "speedometer")
                    }
                }
                .buttonStyle(.borderless)
                .frame(width: 20)
                .help("Test delay")
            }
            if expanded {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(group.nodes, id: \.name) { node in
                        NodeCell(node: node, selected: node.name == group.now, enabled: group.selectable) {
                            model.selectNode(group: group.name, node: node.name)
                        }
                    }
                }
            }
        }
        .groupedSection()
    }
}

private struct NodeCell: View {
    let node: Node
    let selected: Bool
    let enabled: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 6) {
                Text(node.name).lineLimit(1).truncationMode(.middle)
                HStack {
                    Text(node.kind).foregroundStyle(.secondary)
                    Spacer()
                    if let delay = Format.delay(node) {
                        Text(delay).foregroundStyle(delayTint).monospacedDigit()
                    }
                }
                .font(.caption)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var delayTint: Color {
        switch node.delay {
        case 0?: return .red
        case let delay? where delay < 300: return .green
        case .some: return .orange
        case nil: return .secondary
        }
    }
}

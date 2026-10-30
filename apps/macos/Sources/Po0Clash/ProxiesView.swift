import Po0FFI
import SwiftUI

struct ProxiesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var expanded: Set<String> = []

    var body: some View {
        PageScaffold("Proxies", subtitle: model.status?.currentNode) {
            Button {
                for group in model.groups { model.testDelay(group.name) }
            } label: {
                Label("Test all", systemImage: "speedometer")
            }
            .help("Test all")
            .disabled(model.groups.isEmpty || !model.testing.isEmpty)
        } content: {
            if model.status?.mode == .direct {
                EmptyState(
                    title: "Direct mode",
                    symbol: "arrow.right",
                    detail: "Traffic goes out directly, so no proxy is used."
                )
            } else if model.groups.isEmpty {
                EmptyState(
                    title: "No proxy groups",
                    symbol: "globe",
                    detail: "Connect with a subscription to load its proxy groups."
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(model.groups, id: \.name) { group in
                            GroupSection(group: group, expanded: Binding(
                                get: { expanded.contains(group.name) },
                                set: { open in
                                    if open { expanded.insert(group.name) } else { expanded.remove(group.name) }
                                }
                            ))
                        }
                    }
                    .padding(20)
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

private struct GroupSection: View {
    @EnvironmentObject private var model: AppModel
    let group: ProxyGroup
    @Binding var expanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                        Text(group.name).font(.headline).lineLimit(1)
                        Text(group.kind).foregroundStyle(.secondary)
                        Spacer()
                        Text(group.now ?? "—").foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                    ForEach(group.nodes, id: \.name) { node in
                        NodeCell(node: node, selected: node.name == group.now, enabled: group.selectable) {
                            model.selectNode(group: group.name, node: node.name)
                        }
                    }
                }
            }
        }
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.16) : Color.sectionFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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

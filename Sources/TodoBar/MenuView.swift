import SwiftUI

struct MenuView: View {
    let store: TodoStore
    @State private var newTitle = ""
    @State private var launchAtLogin = LoginItem.isEnabled
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Todo")
                .font(.headline)

            TextField("Add a todo…", text: $newTitle)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit {
                    store.add(newTitle)
                    newTitle = ""
                    fieldFocused = true
                }

            if store.items.isEmpty {
                Label("All clear", systemImage: "checkmark.seal")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(store.items) { item in
                        TodoRow(item: item, store: store)
                    }
                }
            }

            Divider()

            HStack {
                Button("Clear Done") { store.clearCompleted() }
                    .disabled(!store.hasCompleted)
                Spacer()
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .disabled(!LoginItem.isSupported)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do { try LoginItem.setEnabled(newValue) } catch {
                            NSLog("LoginItem toggle failed: \(error)")
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
            }
            .controlSize(.small)

            Button("Quit TodoBar") { NSApplication.shared.terminate(nil) }
                .controlSize(.small)
        }
        .padding(14)
        .frame(width: 280)
    }
}

struct TodoRow: View {
    let item: TodoItem
    let store: TodoStore
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.toggle(item)
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.done ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            Text(item.title)
                .strikethrough(item.done)
                .foregroundStyle(item.done ? .secondary : .primary)
                .lineLimit(2)

            Spacer()

            if hovering {
                Button {
                    store.remove(item)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove")
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(hovering ? Color.primary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .onHover { hovering = $0 }
    }
}

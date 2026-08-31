import SwiftUI
import UniformTypeIdentifiers

struct MenuView: View {
    let store: TodoStore
    @State private var newTitle = ""
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var draggingItem: TodoItem?
    @FocusState private var fieldFocused: Bool

    private let rowHeight: CGFloat = 28
    private let rowSpacing: CGFloat = 2

    // Rows have a fixed height, so the list height is plain arithmetic —
    // it grows with content, and only past the screen-height cap does it scroll.
    private var listHeight: CGFloat {
        let count = CGFloat(store.items.count)
        return count * rowHeight + max(0, count - 1) * rowSpacing
    }

    private var maxListHeight: CGFloat {
        max(200, (NSScreen.main?.visibleFrame.height ?? 800) - 180)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Todo")
                    .font(.headline)
                Spacer()
                Text("⌥T")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .help("Press Option-T anywhere to open TodoBar")
            }

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
                ScrollView {
                    VStack(alignment: .leading, spacing: rowSpacing) {
                        ForEach(store.items) { item in
                            TodoRow(item: item, store: store)
                                .frame(height: rowHeight)
                                .onDrag {
                                    draggingItem = item
                                    return NSItemProvider(object: item.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: ReorderDelegate(item: item, store: store, dragging: $draggingItem)
                                )
                        }
                    }
                }
                .frame(height: min(listHeight, maxListHeight))
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
        .onAppear {
            DispatchQueue.main.async { fieldFocused = true }
        }
    }
}

struct ReorderDelegate: DropDelegate {
    let item: TodoItem
    let store: TodoStore
    @Binding var dragging: TodoItem?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging.id != item.id,
              let from = store.items.firstIndex(where: { $0.id == dragging.id }),
              let to = store.items.firstIndex(where: { $0.id == item.id }) else { return }
        store.move(fromIndex: from, toIndex: to)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

struct TodoRow: View {
    let item: TodoItem
    let store: TodoStore
    @State private var hovering = false
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var editFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.toggle(item)
            } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.done ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)

            if isEditing {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($editFocused)
                    .onSubmit {
                        store.rename(item, to: draft)
                        isEditing = false
                    }
                    .onExitCommand { isEditing = false }
                    .onAppear { editFocused = true }
            } else {
                Text(item.title)
                    .strikethrough(item.done)
                    .foregroundStyle(item.done ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onTapGesture(count: 2) {
                        draft = item.title
                        isEditing = true
                    }
                    .help(item.title)
            }

            Spacer()

            if hovering && !isEditing {
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
        .contentShape(Rectangle())
        .background(hovering ? Color.primary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .onHover { hovering = $0 }
    }
}

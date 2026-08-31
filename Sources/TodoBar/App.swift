import SwiftUI

struct TodoBarApp: App {
    @State private var store = TodoStore()

    var body: some Scene {
        MenuBarExtra {
            MenuView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    let store: TodoStore

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: store.remainingCount == 0 ? "checklist.checked" : "checklist")
            if store.remainingCount > 0 {
                Text("\(store.remainingCount)")
            }
        }
    }
}

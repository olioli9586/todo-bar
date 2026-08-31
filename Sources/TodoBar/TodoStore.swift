import Foundation
import Observation

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var done = false
    var createdAt = Date()
}

@Observable
final class TodoStore {
    private(set) var items: [TodoItem] = []

    var remainingCount: Int { items.count(where: { !$0.done }) }
    var hasCompleted: Bool { items.contains(where: \.done) }

    static let fileURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TodoBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("todos.json")
    }()

    init() {
        load()
        clearCompletedIfNewDay()
    }

    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed))
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].done.toggle()
        save()
    }

    func remove(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func rename(_ item: TodoItem, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].title = trimmed
        save()
    }

    func move(fromIndex: Int, toIndex: Int) {
        guard fromIndex != toIndex, items.indices.contains(fromIndex), items.indices.contains(toIndex) else { return }
        let item = items.remove(at: fromIndex)
        items.insert(item, at: toIndex)
        save()
    }

    func clearCompleted() {
        items.removeAll(where: \.done)
        save()
    }

    /// Daily reset: the first time the app is used on a new calendar day,
    /// checked-off items are swept away so the list starts fresh.
    func clearCompletedIfNewDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let key = "lastResetDay"
        if let last = UserDefaults.standard.object(forKey: key) as? Date, last >= today { return }
        UserDefaults.standard.set(today, forKey: key)
        if hasCompleted { clearCompleted() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        items = (try? JSONDecoder().decode([TodoItem].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }
}

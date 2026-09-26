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

    static let defaultFileURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("TodoBar", isDirectory: true)
        .appendingPathComponent("todos.json")

    private let fileURL: URL
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    init(
        fileURL: URL = TodoStore.defaultFileURL,
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
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
    ///
    /// The last reset is stored as a local calendar day ("2026-09-25") and
    /// compared for equality, so a clock that was once set into the future, or
    /// a time zone change, can't block or repeat resets.
    func clearCompletedIfNewDay() {
        let today = dayKey(for: now())
        let key = "lastResetDay"
        let last: String? = switch defaults.object(forKey: key) {
        case let day as String: day
        case let date as Date: dayKey(for: date) // written by 1.0.3 and earlier
        default: nil
        }
        if last == today { return }
        defaults.set(today, forKey: key)
        if hasCompleted { clearCompleted() }
    }

    private func dayKey(for date: Date) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            items = try JSONDecoder().decode([TodoItem].self, from: data)
        } catch {
            // Move the unreadable file aside so the next save can't overwrite
            // the user's todos with an empty list.
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("todos.corrupt-\(Int(now().timeIntervalSince1970)).json")
            do {
                try FileManager.default.moveItem(at: fileURL, to: backup)
                NSLog("TodoBar: couldn't read \(fileURL.path) (\(error)); moved it to \(backup.lastPathComponent)")
            } catch let moveError {
                NSLog("TodoBar: couldn't read \(fileURL.path) (\(error)) or move it aside (\(moveError))")
            }
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
    }
}

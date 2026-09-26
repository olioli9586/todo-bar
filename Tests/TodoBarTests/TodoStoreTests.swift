import Foundation
import Testing
@testable import TodoBar

/// Each test gets its own temp file and UserDefaults suite, so nothing touches
/// the real ~/Library/Application Support/TodoBar data or the app's defaults.
final class Sandbox {
    let dir: URL
    let fileURL: URL
    let suiteName: String
    let defaults: UserDefaults
    var calendar: Calendar
    var now: Date

    init() {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TodoBarTests-\(UUID().uuidString)", isDirectory: true)
        fileURL = dir.appendingPathComponent("todos.json")
        suiteName = "TodoBarTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        now = Sandbox.date("2026-09-25T09:00:00Z")
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: dir)
    }

    func makeStore() -> TodoStore {
        TodoStore(fileURL: fileURL, defaults: defaults, calendar: calendar, now: { [unowned self] in now })
    }

    static func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }
}

@Suite struct TodoStoreEditingTests {
    let sandbox = Sandbox()

    @Test func addTrimsWhitespaceAndIgnoresBlankTitles() {
        let store = sandbox.makeStore()
        store.add("  buy milk \n")
        store.add("   ")
        store.add("\n\t")
        #expect(store.items.map(\.title) == ["buy milk"])
        #expect(store.remainingCount == 1)
    }

    @Test func toggleFlipsDoneAndUpdatesCounts() {
        let store = sandbox.makeStore()
        store.add("a")
        store.add("b")
        store.toggle(store.items[0])
        #expect(store.items[0].done)
        #expect(store.remainingCount == 1)
        #expect(store.hasCompleted)
        store.toggle(store.items[0])
        #expect(!store.items[0].done)
        #expect(!store.hasCompleted)
    }

    @Test func removeDeletesOnlyThatItem() {
        let store = sandbox.makeStore()
        store.add("a")
        store.add("b")
        store.remove(store.items[0])
        #expect(store.items.map(\.title) == ["b"])
    }

    @Test func renameTrimsAndRejectsBlankTitles() {
        let store = sandbox.makeStore()
        store.add("old")
        store.rename(store.items[0], to: "  new  ")
        #expect(store.items[0].title == "new")
        store.rename(store.items[0], to: "   ")
        #expect(store.items[0].title == "new")
    }

    @Test func operationsOnUnknownItemAreNoOps() {
        let store = sandbox.makeStore()
        store.add("a")
        let stranger = TodoItem(title: "not in store")
        store.toggle(stranger)
        store.rename(stranger, to: "x")
        store.remove(stranger)
        #expect(store.items.map(\.title) == ["a"])
        #expect(!store.items[0].done)
    }

    @Test func moveReordersInBothDirectionsAndIgnoresBadIndices() {
        let store = sandbox.makeStore()
        ["a", "b", "c", "d"].forEach(store.add)
        store.move(fromIndex: 0, toIndex: 2)
        #expect(store.items.map(\.title) == ["b", "c", "a", "d"])
        store.move(fromIndex: 3, toIndex: 0)
        #expect(store.items.map(\.title) == ["d", "b", "c", "a"])
        store.move(fromIndex: 1, toIndex: 1)
        store.move(fromIndex: -1, toIndex: 0)
        store.move(fromIndex: 0, toIndex: 4)
        #expect(store.items.map(\.title) == ["d", "b", "c", "a"])
    }

    @Test func clearCompletedKeepsOpenItemsInOrder() {
        let store = sandbox.makeStore()
        ["a", "b", "c"].forEach(store.add)
        store.toggle(store.items[1])
        store.clearCompleted()
        #expect(store.items.map(\.title) == ["a", "c"])
        #expect(!store.hasCompleted)
    }
}

@Suite struct TodoStorePersistenceTests {
    let sandbox = Sandbox()

    @Test func itemsRoundTripThroughDisk() {
        let store = sandbox.makeStore()
        ["a", "b", "c"].forEach(store.add)
        store.toggle(store.items[2])
        store.move(fromIndex: 2, toIndex: 0)
        store.rename(store.items[1], to: "A")

        let reloaded = sandbox.makeStore()
        #expect(reloaded.items == store.items)
        #expect(reloaded.items.map(\.title) == ["c", "A", "b"])
        #expect(reloaded.items[0].done)
    }

    @Test func missingFileStartsEmptyAndSaveCreatesDirectory() {
        let store = sandbox.makeStore()
        #expect(store.items.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: sandbox.fileURL.path))
        store.add("first")
        #expect(FileManager.default.fileExists(atPath: sandbox.fileURL.path))
    }

    @Test func unreadableFileIsBackedUpInsteadOfOverwritten() throws {
        let original = Data("[{\"title\": \"half-written".utf8)
        try FileManager.default.createDirectory(at: sandbox.dir, withIntermediateDirectories: true)
        try original.write(to: sandbox.fileURL)

        let store = sandbox.makeStore()
        #expect(store.items.isEmpty)
        store.add("new item")

        let backups = try FileManager.default.contentsOfDirectory(atPath: sandbox.dir.path)
            .filter { $0.hasPrefix("todos.corrupt-") }
        try #require(backups.count == 1)
        let backup = try Data(contentsOf: sandbox.dir.appendingPathComponent(backups[0]))
        #expect(backup == original)
        #expect(sandbox.makeStore().items.map(\.title) == ["new item"])
    }
}

@Suite struct TodoStoreDailyResetTests {
    let sandbox = Sandbox()

    @Test func completedItemsSurviveTheSameDay() {
        let store = sandbox.makeStore()
        store.add("a")
        store.add("b")
        store.toggle(store.items[0])
        sandbox.now = Sandbox.date("2026-09-25T22:30:00Z")
        store.clearCompletedIfNewDay()
        #expect(store.items.count == 2)
    }

    @Test func completedItemsAreClearedOnANewDay() {
        let store = sandbox.makeStore()
        store.add("a")
        store.add("b")
        store.toggle(store.items[0])
        sandbox.now = Sandbox.date("2026-09-26T07:00:00Z")
        store.clearCompletedIfNewDay()
        #expect(store.items.map(\.title) == ["b"])
    }

    @Test func resetRunsOnLaunchOnANewDay() {
        let store = sandbox.makeStore()
        store.add("a")
        store.add("b")
        store.toggle(store.items[1])
        sandbox.now = Sandbox.date("2026-09-27T12:00:00Z")
        let relaunched = sandbox.makeStore()
        #expect(relaunched.items.map(\.title) == ["a"])
    }

    @Test func itemsCheckedAfterTheResetStayUntilTheNextDay() {
        let store = sandbox.makeStore()
        store.add("a")
        sandbox.now = Sandbox.date("2026-09-26T07:00:00Z")
        store.clearCompletedIfNewDay()
        store.toggle(store.items[0])
        sandbox.now = Sandbox.date("2026-09-26T20:00:00Z")
        store.clearCompletedIfNewDay()
        #expect(store.items.count == 1)
        sandbox.now = Sandbox.date("2026-09-27T00:30:00Z")
        store.clearCompletedIfNewDay()
        #expect(store.items.isEmpty)
    }

    @Test func aFutureResetDateDoesNotBlockResetsForever() {
        // e.g. the clock was briefly set to next year when the app was used.
        sandbox.now = Sandbox.date("2027-06-01T09:00:00Z")
        _ = sandbox.makeStore()
        sandbox.now = Sandbox.date("2026-09-25T09:00:00Z")
        let store = sandbox.makeStore()
        store.add("a")
        store.toggle(store.items[0])
        sandbox.now = Sandbox.date("2026-09-26T09:00:00Z")
        store.clearCompletedIfNewDay()
        #expect(store.items.isEmpty)
    }

    @Test func changingTimeZoneWithinTheSameDayDoesNotResetAgain() {
        sandbox.calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        sandbox.now = Sandbox.date("2026-09-25T01:00:00Z") // 10:00 on the 25th in Tokyo
        let store = sandbox.makeStore()
        store.add("a")
        store.toggle(store.items[0])

        // Fly to Los Angeles: still the 25th locally, so the checked item stays.
        sandbox.calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        sandbox.now = Sandbox.date("2026-09-25T17:00:00Z") // 10:00 on the 25th in LA
        let relaunched = sandbox.makeStore()
        #expect(relaunched.items.count == 1)
    }

    @Test func legacyDateValueIsStillHonoured() {
        let startOfToday = sandbox.calendar.startOfDay(for: sandbox.now)
        sandbox.defaults.set(startOfToday, forKey: "lastResetDay")
        try? FileManager.default.createDirectory(at: sandbox.dir, withIntermediateDirectories: true)
        let seeded = [TodoItem(title: "done today", done: true)]
        try? JSONEncoder().encode(seeded).write(to: sandbox.fileURL)

        #expect(sandbox.makeStore().items.count == 1)

        let startOfYesterday = sandbox.calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        sandbox.defaults.set(startOfYesterday, forKey: "lastResetDay")
        #expect(sandbox.makeStore().items.isEmpty)
    }
}

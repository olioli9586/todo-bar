import AppKit
import Carbon.HIToolbox
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = TodoStore()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)

        let hosting = NSHostingController(rootView: MenuView(store: store))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = false

        updateButton()
        observeStore()

        HotKeyCenter.register(keyCode: UInt32(kVK_ANSI_T), modifiers: UInt32(optionKey)) { [weak self] in
            self?.togglePopover()
        }
    }

    private func observeStore() {
        withObservationTracking {
            _ = store.remainingCount
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.updateButton()
                self?.observeStore()
            }
        }
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let symbol = store.remainingCount == 0 ? "checklist.checked" : "checklist"
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "TodoBar")
        button.imagePosition = .imageLeading
        button.title = store.remainingCount > 0 ? " \(store.remainingCount)" : ""
    }

    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            store.clearCompletedIfNewDay()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

/// Global hotkey via Carbon — works without the Accessibility permission.
enum HotKeyCenter {
    private static var handler: (() -> Void)?
    private static var hotKeyRef: EventHotKeyRef?

    static func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        handler = action
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKeyCenter.handler?() }
            return noErr
        }, 1, &eventType, nil, nil)
        let hotKeyID = EventHotKeyID(signature: OSType(0x5442_4152), id: 1) // "TBAR"
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}

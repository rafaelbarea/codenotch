import AppKit
import Combine
import SwiftUI

/// Where the Brink features plug into Codenotch: the cost models watch the
/// usage store's snapshots, and the Activity window opens from the menu.
@MainActor
enum Brink {
    private static var subscription: AnyCancellable?
    private static var focusTick: AnyCancellable?
    private static var todoTick: AnyCancellable?
    private static var activityWindow: NSWindow?
    private static var focusWindow: NSWindow?
    private static weak var store: UsageStore?
    /// Set by the app once Settings exists: Activity and Focus open there,
    /// as sidebar sections, rather than in windows of their own.
    static var openSettingsSection: ((String) -> Void)?

    static func attach(to store: UsageStore) {
        self.store = store
        _ = PlanCatalog.shared
        _ = PriceTable.shared
        _ = CostAccountStore.shared
        subscription = store.$snapshots
            .receive(on: RunLoop.main)
            .sink { snapshots in
                CostAccountStore.shared.rediscover()
                CostModels.all.forEach { $0.observe(snapshots) }
            }
        // The tasks ring follows the timer and the list without waiting for
        // the next poll: a few seconds while a focus runs, at once on changes.
        focusTick = FocusStore.shared.$now
            .throttle(for: .seconds(5), scheduler: RunLoop.main, latest: true)
            .sink { [weak store] _ in
                guard FocusStore.shared.isActive else { return }
                _ = store?.refresh(providerID: TasksProvider.providerID)
            }
        todoTick = Publishers.Merge3(
            TodoStore.shared.$todos.map { _ in () }.eraseToAnyPublisher(),
            TodoStore.shared.$completedToday.map { _ in () }.eraseToAnyPublisher(),
            FocusStore.shared.$taskID.map { _ in () }.eraseToAnyPublisher())
            .dropFirst(3)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak store] _ in _ = store?.refresh(providerID: TasksProvider.providerID) }
    }

    /// What a double click on a ring opens.
    static func open(snapshot: ProviderSnapshot) {
        if snapshot.id == TasksProvider.providerID {
            let store = TodoStore.shared
            store.source.showList(store.listName(for: store.tab))
            return
        }
        NewSession.launch(account: CostAccountStore.shared.accounts.first { $0.id == snapshot.id })
    }

    static func showFocus() {
        if let openSettingsSection { openSettingsSection("focus"); return }
        if focusWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
            w.title = L10n.t("Focus")
            w.minSize = NSSize(width: 900, height: 560)
            w.contentViewController = NSHostingController(rootView: FocusPane().frame(minWidth: 900, minHeight: 560))
            w.isReleasedWhenClosed = false
            w.center()
            focusWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        focusWindow?.makeKeyAndOrderFront(nil)
    }

    static func showActivity() {
        if let openSettingsSection { openSettingsSection("activity"); return }
        if activityWindow == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable],
                             backing: .buffered, defer: false)
            w.title = L10n.t("Activity")
            w.minSize = NSSize(width: 900, height: 560)
            w.contentViewController = NSHostingController(rootView: TimelinePane().frame(minWidth: 900, minHeight: 560))
            w.isReleasedWhenClosed = false
            w.center()
            activityWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        activityWindow?.makeKeyAndOrderFront(nil)
    }
}


/// Target for the notch's context menu entries (AppKit needs an object).
final class BrinkMenuActions: NSObject {
    @MainActor static let shared = BrinkMenuActions()
    @MainActor @objc func newSession(_ sender: Any?) { NewSession.launch() }
    @MainActor @objc func openActivity(_ sender: Any?) { Brink.showActivity() }
    @MainActor @objc func openFocus(_ sender: Any?) { Brink.showFocus() }
}

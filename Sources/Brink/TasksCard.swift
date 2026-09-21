import SwiftUI
import AppKit

/// Type for the tasks card, sized so that at the medium notch size the card
/// is drawn exactly as Brink drew it (330pt wide, 11.5pt task names). The
/// card is scaled by `NotchViewModel.cardScale`, so every size here is the
/// Brink point size divided by the medium card scale.
enum BrinkType {
    static let unit: CGFloat = 1 / NotchViewModel.cardBase(for: 1)

    static func pt(_ size: CGFloat) -> CGFloat { size * unit }
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: pt(size), weight: weight)
    }
    /// The line box of a font, for the height the card reserves.
    static func line(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> CGFloat {
        let font = NSFont.systemFont(ofSize: pt(size), weight: weight)
        return ceil(font.ascender - font.descender + font.leading)
    }
}

/// The hover card for the Tasks ring: today / tomorrow / one list of yours,
/// complete with a click, add with a line of text ("@" picks the project),
/// and a focus timer per task or free-standing.
struct TasksCard: View {
    @ObservedObject var store: TodoStore = .shared
    @ObservedObject var focus: FocusStore = .shared
    let now: Date
    /// Rows the screen has room for (solved by the view model).
    var rows: Int = TasksCard.maxRows

    static let maxRows = 12

    // Brink's measurements, in its points (scaled by `BrinkType.unit`).
    static let headerBottom = BrinkType.pt(10)
    static let bannerPadH = BrinkType.pt(9)
    static let bannerPadV = BrinkType.pt(7)
    static let bannerBottom = BrinkType.pt(10)
    static let tabPadV = BrinkType.pt(3)
    static let tabsBottom = BrinkType.pt(8)
    static let rowPadV = BrinkType.pt(4)
    static let rowLineGap = BrinkType.pt(1)
    static let emptyPadV = BrinkType.pt(6)
    static let quickAddTop = BrinkType.pt(12)
    static let freeFocusTop = BrinkType.pt(6)
    static let fieldHeight = BrinkType.line(11) + BrinkType.pt(6)

    private var listed: [Todo] { Array((store.todos[store.tab] ?? []).prefix(min(rows, Self.maxRows))) }

    /// Reserved by `NotchLayout` before the card is drawn, so it must count
    /// exactly what `body` lays out.
    @MainActor static func height(rows cap: Int = TasksCard.maxRows) -> CGFloat {
        let store = TodoStore.shared, focus = FocusStore.shared
        let rows = min((store.todos[store.tab] ?? []).count, min(cap, maxRows))
        var h = 2 * NotchLayout.cardPadding
        h += max(BrinkType.line(14, .semibold), BrinkType.line(9, .bold) + BrinkType.pt(4)) + headerBottom
        if focus.isActive {
            h += BrinkType.line(11.5, .semibold) + BrinkType.pt(1) + BrinkType.line(10) + 2 * bannerPadV + bannerBottom
        }
        h += BrinkType.line(10.5, .semibold) + 2 * tabPadV + tabsBottom
        if rows == 0 {
            h += BrinkType.line(11) + 2 * emptyPadV
        } else {
            h += CGFloat(rows) * (BrinkType.line(11.5) + rowLineGap + BrinkType.line(10) + 2 * rowPadV)
        }
        h += quickAddTop + fieldHeight
        if !focus.isActive { h += freeFocusTop + fieldHeight }
        let suggestions = store.suggestionCount
        if suggestions > 0 { h += CGFloat(suggestions) * BrinkType.line(11) + BrinkType.pt(4) }
        return h
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.bottom, Self.headerBottom)
            if focus.isActive { focusBanner.padding(.bottom, Self.bannerBottom) }
            tabs.padding(.bottom, Self.tabsBottom)
            list
            BrinkTaggedField(text: $store.draft, project: $store.draftProject, lists: store.lists,
                             prompt: L10n.t("New task in \(store.title(for: store.tab))"), icon: "plus",
                             accent: Palette.textSecondary, id: "draft", editing: $store.editing) {
                store.create(store.draft, project: store.draftProject.isEmpty ? nil : store.draftProject)
                store.draft = ""; store.draftProject = ""
                store.focusedField = nil; store.editing = false
            }
            .padding(.top, Self.quickAddTop)
            if !focus.isActive {
                BrinkTaggedField(text: $store.freeFocus, project: $store.freeProject, lists: store.lists,
                                 prompt: L10n.t("Focus without a task…"), icon: "timer",
                                 accent: BrinkColors.violet, id: "free", editing: $store.editing) {
                    let name = store.freeFocus.trimmingCharacters(in: .whitespaces)
                    focus.start(id: "free-\(Int(Date().timeIntervalSince1970))", name: name.isEmpty ? L10n.t("Focus") : name,
                                project: store.freeProject.isEmpty ? nil : store.freeProject)
                    store.freeFocus = ""; store.freeProject = ""
                    store.focusedField = nil; store.editing = false
                }
                .padding(.top, Self.freeFocusTop)
            }
        }
        // The shared card chrome already pads the frame's margin; the height
        // formula counts that margin once.
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear { store.refresh() }
        // A card that goes away takes its typing with it: nothing is being
        // edited in a card that is not on screen.
        .onDisappear { store.editing = false }
    }

    private var header: some View {
        HStack(spacing: BrinkType.pt(8)) {
            Image(systemName: "checklist").font(BrinkType.font(13, .semibold))
            Text(L10n.t("Tasks")).font(BrinkType.font(14, .semibold))
            Spacer()
            if store.tab == .today, store.completedToday > 0 {
                Text(L10n.t("\(store.completedToday) done"))
                    .font(BrinkType.font(9, .bold))
                    .padding(.horizontal, BrinkType.pt(5)).padding(.vertical, BrinkType.pt(2))
                    .background(Capsule().fill(BrinkColors.green.opacity(0.85)))
                    .foregroundStyle(.black.opacity(0.85))
            }
            Button { store.source.showList(store.listName(for: store.tab)) } label: {
                Image(systemName: "arrow.up.forward.square").font(BrinkType.font(11)).foregroundStyle(Palette.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Palette.textPrimary)
    }

    private var focusBanner: some View {
        HStack(spacing: BrinkType.pt(8)) {
            Image(systemName: focus.isRunning ? "timer" : "pause.fill")
                .font(BrinkType.font(11, .semibold)).foregroundStyle(BrinkColors.violet)
            VStack(alignment: .leading, spacing: BrinkType.pt(1)) {
                Text(focus.taskName ?? "").font(BrinkType.font(11.5, .semibold)).foregroundStyle(Palette.textPrimary).lineLimit(1)
                Text("\(FocusStore.clock(focus.elapsed)) · \(L10n.t("target \(focus.targetMinutes) min"))" + (focus.project.map { " · \($0)" } ?? ""))
                    .font(BrinkType.font(10)).monospacedDigit().foregroundStyle(Palette.textSecondary).lineLimit(1)
            }
            Spacer()
            Button { focus.isRunning ? focus.pause() : focus.resume() } label: {
                Image(systemName: focus.isRunning ? "pause.circle.fill" : "play.circle.fill").font(BrinkType.font(16))
            }.buttonStyle(.plain).foregroundStyle(Palette.textPrimary)
            Button { focus.stop() } label: { Image(systemName: "stop.circle").font(BrinkType.font(16)) }
                .buttonStyle(.plain).foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, Self.bannerPadH).padding(.vertical, Self.bannerPadV)
        .background(RoundedRectangle(cornerRadius: BrinkType.pt(7), style: .continuous).fill(BrinkColors.violet.opacity(0.14)))
    }

    private var tabs: some View {
        HStack(spacing: BrinkType.pt(10)) {
            ForEach(TodoStore.Tab.allCases) { tab in
                let selected = tab == store.tab
                let count = store.todos[tab]?.count ?? 0
                Button { store.tab = tab } label: {
                    HStack(spacing: BrinkType.pt(4)) {
                        Text(store.title(for: tab)).font(BrinkType.font(10.5, selected ? .semibold : .regular)).lineLimit(1)
                        if count > 0 {
                            Text("\(count)").font(BrinkType.font(9, .semibold)).monospacedDigit()
                        }
                    }
                    .foregroundStyle(selected ? Palette.textPrimary : Palette.textSecondary)
                    .padding(.vertical, Self.tabPadV).padding(.horizontal, BrinkType.pt(7))
                    .background(Capsule().fill(selected ? Palette.ringTrack : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder private var list: some View {
        if listed.isEmpty {
            Text(!store.source.isReady ? store.source.notReadyMessage
                 : store.refreshedAt == nil ? L10n.t("Reading \(store.source.title)…") : L10n.t("Nothing here. Enjoy it."))
                .font(BrinkType.font(11)).foregroundStyle(Palette.textSecondary)
                .padding(.vertical, Self.emptyPadV)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(listed) { todo in
                    TaskRow(todo: todo, busy: store.busy.contains(todo.id), focused: focus.taskID == todo.id,
                            onComplete: { store.complete(todo); if focus.taskID == todo.id { focus.stop() } },
                            onFocus: { focus.taskID == todo.id ? focus.stop() : focus.start(id: todo.id, name: todo.name, project: todo.project) },
                            onOpen: { store.source.show(todo.id, in: store.listName(for: store.tab), name: todo.name) })
                }
            }
        }
    }
}

private struct TaskRow: View {
    let todo: Todo
    let busy: Bool
    let focused: Bool
    let onComplete: () -> Void
    let onFocus: () -> Void
    let onOpen: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(alignment: .top, spacing: BrinkType.pt(8)) {
            Button(action: onComplete) {
                ZStack {
                    Circle().stroke(busy ? BrinkColors.green : Palette.textSecondary, lineWidth: BrinkType.pt(1.2))
                        .frame(width: BrinkType.pt(13), height: BrinkType.pt(13))
                    if busy { Circle().fill(BrinkColors.green).frame(width: BrinkType.pt(13), height: BrinkType.pt(13)) }
                    if busy || hover {
                        Image(systemName: "checkmark").font(BrinkType.font(8, .bold))
                            .foregroundStyle(busy ? .black.opacity(0.8) : Palette.textSecondary)
                    }
                }
                .padding(.top, BrinkType.pt(2))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // The whole row (minus the checkbox and the play button) opens
            // the exact item in the app.
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: TasksCard.rowLineGap) {
                    Text(todo.name).font(BrinkType.font(11.5)).foregroundStyle(busy ? Palette.textSecondary : Palette.textPrimary)
                        .strikethrough(busy).lineLimit(1)
                    HStack(spacing: BrinkType.pt(5)) {
                        if let p = todo.project { Text(p).font(BrinkType.font(10)).foregroundStyle(Palette.textSecondary).lineLimit(1) }
                        if let due = todo.due {
                            Text(todo.overdue ? L10n.t("due \(due)") : due).font(BrinkType.font(10))
                                .foregroundStyle(todo.overdue ? BrinkColors.orange : Palette.textSecondary)
                        }
                        if todo.project == nil && todo.due == nil { Text(" ").font(BrinkType.font(10)) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if focused || hover {
                Button(action: onFocus) {
                    Image(systemName: focused ? "stop.circle.fill" : "play.circle").font(BrinkType.font(13))
                        .foregroundStyle(focused ? BrinkColors.violet : Palette.textSecondary)
                }
                .buttonStyle(.plain).padding(.top, BrinkType.pt(1))
            }
        }
        .padding(.vertical, TasksCard.rowPadV)
        // The focus highlight bleeds outside the row so the text stays
        // aligned with the others.
        .background(RoundedRectangle(cornerRadius: BrinkType.pt(6), style: .continuous)
            .fill(focused ? BrinkColors.violet.opacity(0.10) : .clear).padding(.horizontal, -BrinkType.pt(6)))
        .opacity(busy ? 0.6 : 1)
        .animation(.easeOut(duration: 0.25), value: busy)
        .onHover { hover = $0 }
    }
}

/// A one-line field where "@" lists projects to pick; the pick shows as a chip.
struct BrinkTaggedField: View {
    @Binding var text: String
    @Binding var project: String
    let lists: [String]
    var prompt: String
    var icon: String
    var accent: Color
    var id: String = ""
    @Binding var editing: Bool
    var action: () -> Void
    @FocusState private var focused: Bool

    private var query: String? {
        guard let at = text.lastIndex(of: "@") else { return nil }
        return String(text[text.index(after: at)...])
    }
    private var suggestions: [String] {
        guard let q = query else { return [] }
        let needle = q.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return lists.filter { needle.isEmpty || $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).contains(needle) }.prefix(5).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BrinkType.pt(4)) {
            HStack(spacing: BrinkType.pt(7)) {
                Image(systemName: icon).font(BrinkType.font(11)).foregroundStyle(accent).frame(width: BrinkType.pt(14))
                TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Palette.textSecondary))
                    .textFieldStyle(.plain).font(BrinkType.font(11)).foregroundStyle(Palette.textPrimary)
                    .focused($focused)
                    .onChange(of: focused) { _, on in
                        editing = on
                        if on { TodoStore.shared.focusedField = id }
                    }
                    .onAppear {
                        // Back to the field that was being typed in when the
                        // card last folded, the moment it is on screen again.
                        // Only with unsent text in it: an empty field taking
                        // the keyboard on every open pinned the card shut to
                        // the other rings.
                        if TodoStore.shared.focusedField == id, !text.isEmpty {
                            DispatchQueue.main.async { focused = true }
                        }
                    }
                    // A field that leaves the screen (the free-focus line goes
                    // when a block starts) can no longer be edited, whatever
                    // its focus state last said.
                    .onDisappear { if editing { editing = false } }
                    .onSubmit { if let first = suggestions.first, query != nil { pick(first) } else { action() } }
                Menu {
                    Button(L10n.t("No project")) { project = "" }
                    Divider()
                    ForEach(lists, id: \.self) { l in Button(l) { project = l } }
                } label: {
                    HStack(spacing: BrinkType.pt(3)) {
                        Image(systemName: project.isEmpty ? "folder" : "folder.fill").font(BrinkType.font(11))
                        if !project.isEmpty { Text(project).font(BrinkType.font(10.5)).lineLimit(1).frame(maxWidth: BrinkType.pt(110)) }
                    }
                    .foregroundStyle(project.isEmpty ? Palette.textSecondary : accent)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                Button(action: action) {
                    Image(systemName: icon == "timer" ? "play.circle.fill" : "return").font(BrinkType.font(12)).foregroundStyle(accent)
                        .frame(width: BrinkType.pt(16))
                }
                .buttonStyle(.plain)
            }
            .frame(height: TasksCard.fieldHeight)
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { l in
                        Button { pick(l) } label: {
                            HStack(spacing: BrinkType.pt(6)) {
                                Image(systemName: "folder").font(BrinkType.font(10.5)).foregroundStyle(Palette.textSecondary)
                                Text(l).font(BrinkType.font(11)).foregroundStyle(Palette.textPrimary).lineLimit(1)
                                Spacer()
                            }
                            .frame(height: BrinkType.line(11))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onChange(of: suggestions.count) { _, n in TodoStore.shared.suggestionCount = n; TodoStore.shared.layoutTick += 1 }
        .onChange(of: project) { _, _ in TodoStore.shared.layoutTick += 1 }
    }

    private func pick(_ name: String) {
        project = name
        if let at = text.lastIndex(of: "@") { text = String(text[..<at]).trimmingCharacters(in: .whitespaces) }
        focused = true
    }
}

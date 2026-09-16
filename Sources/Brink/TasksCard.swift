import SwiftUI
import AppKit

/// The hover card for the Tasks ring: today / tomorrow / one list of yours,
/// complete with a click, add with a line of text ("@" picks the project),
/// and a focus timer per task or free-standing.
struct TasksCard: View {
    @ObservedObject var store: TodoStore = .shared
    @ObservedObject var focus: FocusStore = .shared
    let now: Date
    /// Rows the screen has room for (solved by the view model).
    var rows: Int = TasksCard.maxRows

    static let maxRows = 10

    private var listed: [Todo] { Array((store.todos[store.tab] ?? []).prefix(min(rows, Self.maxRows))) }

    /// Reserved by `NotchLayout` before the card is drawn, so it must count
    /// exactly what `body` lays out.
    @MainActor static func height(rows cap: Int = TasksCard.maxRows) -> CGFloat {
        let store = TodoStore.shared, focus = FocusStore.shared
        let rows = min((store.todos[store.tab] ?? []).count, min(cap, maxRows))
        let line = NotchLayout.cardBodyLineHeight
        var h = 2 * NotchLayout.cardPadding
            + max(NotchLayout.glyphSize, NotchLayout.cardTitleLineHeight)   // header
            + NotchLayout.headerToBlock + line                              // tabs
        if focus.isActive { h += NotchLayout.blockSpacing + 2 * line }      // focus banner
        h += NotchLayout.blockSpacing
        h += rows == 0 ? line : CGFloat(rows) * (2 * line + NotchLayout.sessionRowGap)
        h += NotchLayout.blockSpacing + line                                // quick add
        if !focus.isActive { h += NotchLayout.sessionRowGap + line }        // free focus
        let suggestions = store.suggestionCount
        if suggestions > 0 { h += CGFloat(suggestions) * line + NotchLayout.sessionRowGap }
        return h
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            tabs.padding(.top, NotchLayout.headerToBlock)
            if focus.isActive { focusBanner.padding(.top, NotchLayout.blockSpacing) }
            list.padding(.top, NotchLayout.blockSpacing)
            BrinkTaggedField(text: $store.draft, project: $store.draftProject, lists: store.lists,
                             prompt: L10n.t("New task in \(store.title(for: store.tab))"), icon: "plus",
                             accent: Palette.textSecondary, editing: $store.editing) {
                store.create(store.draft, project: store.draftProject.isEmpty ? nil : store.draftProject)
                store.draft = ""; store.draftProject = ""
            }
            .padding(.top, NotchLayout.blockSpacing)
            if !focus.isActive {
                BrinkTaggedField(text: $store.freeFocus, project: $store.freeProject, lists: store.lists,
                                 prompt: L10n.t("Focus without a task…"), icon: "timer",
                                 accent: BrinkColors.violet, editing: $store.editing) {
                    let name = store.freeFocus.trimmingCharacters(in: .whitespaces)
                    focus.start(id: "free-\(Int(Date().timeIntervalSince1970))", name: name.isEmpty ? L10n.t("Focus") : name,
                                project: store.freeProject.isEmpty ? nil : store.freeProject)
                    store.freeFocus = ""; store.freeProject = ""
                }
                .padding(.top, NotchLayout.sessionRowGap)
            }
        }
        .padding(NotchLayout.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear { store.refresh() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: NotchLayout.headerGap) {
            Image(systemName: "checklist")
                .font(.system(size: Design.px(30), weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: NotchLayout.glyphSize, height: NotchLayout.glyphSize)
            Text(L10n.t("Tasks")).font(Typography.cardTitle).foregroundStyle(Palette.textPrimary)
            Spacer(minLength: Design.px(12))
            if store.completedToday > 0 {
                Text(L10n.t("\(store.completedToday) done")).font(Typography.cardBody).foregroundStyle(BrinkColors.green)
            }
            Button { store.source.showList(store.listName(for: store.tab)) } label: {
                Image(systemName: "arrow.up.forward.square").font(Typography.cardBody).foregroundStyle(Palette.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var tabs: some View {
        HStack(spacing: Design.px(18)) {
            ForEach(TodoStore.Tab.allCases) { tab in
                let selected = tab == store.tab
                let count = store.todos[tab]?.count ?? 0
                Button { store.tab = tab } label: {
                    HStack(spacing: Design.px(6)) {
                        Text(store.title(for: tab)).font(Typography.cardBody).lineLimit(1)
                        if count > 0 { Text("\(count)").font(Typography.cardBody).monospacedDigit() }
                    }
                    .foregroundStyle(selected ? Palette.textPrimary : Palette.textSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var focusBanner: some View {
        HStack(spacing: Design.px(10)) {
            Image(systemName: focus.isRunning ? "timer" : "pause.fill").font(Typography.cardBody).foregroundStyle(BrinkColors.violet)
            VStack(alignment: .leading, spacing: 0) {
                Text(focus.taskName ?? "").font(Typography.cardBody).foregroundStyle(Palette.textPrimary).lineLimit(1)
                Text("\(FocusStore.clock(focus.elapsed)) · \(L10n.t("target \(focus.targetMinutes) min"))" + (focus.project.map { " · \($0)" } ?? ""))
                    .font(Typography.cardBody).monospacedDigit().foregroundStyle(Palette.textSecondary).lineLimit(1)
            }
            Spacer()
            Button { focus.isRunning ? focus.pause() : focus.resume() } label: {
                Image(systemName: focus.isRunning ? "pause.circle.fill" : "play.circle.fill").font(Typography.cardTitle)
            }.buttonStyle(.plain).foregroundStyle(Palette.textPrimary)
            Button { focus.stop() } label: { Image(systemName: "stop.circle").font(Typography.cardTitle) }
                .buttonStyle(.plain).foregroundStyle(Palette.textSecondary)
        }
    }

    @ViewBuilder private var list: some View {
        if listed.isEmpty {
            Text(store.refreshedAt == nil ? L10n.t("Reading \(store.source.title)…") : L10n.t("Nothing here. Enjoy it."))
                .font(Typography.cardBody).foregroundStyle(Palette.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: NotchLayout.sessionRowGap) {
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
        HStack(alignment: .top, spacing: Design.px(12)) {
            Button(action: onComplete) {
                ZStack {
                    Circle().stroke(busy ? BrinkColors.green : Palette.textSecondary, lineWidth: 1.2)
                        .frame(width: Design.px(20), height: Design.px(20))
                    if busy { Circle().fill(BrinkColors.green).frame(width: Design.px(20), height: Design.px(20)) }
                    if busy || hover { Image(systemName: "checkmark").font(.system(size: Design.px(12), weight: .bold)).foregroundStyle(busy ? .black : Palette.textSecondary) }
                }
                .padding(.top, Design.px(3))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(todo.name).font(Typography.cardBody).foregroundStyle(busy ? Palette.textSecondary : Palette.textPrimary)
                        .strikethrough(busy).lineLimit(1)
                    HStack(spacing: Design.px(8)) {
                        if let p = todo.project { Text(p).font(Typography.cardBody).foregroundStyle(Palette.textSecondary).lineLimit(1) }
                        if let due = todo.due {
                            Text(todo.overdue ? L10n.t("due \(due)") : due).font(Typography.cardBody)
                                .foregroundStyle(todo.overdue ? BrinkColors.orange : Palette.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if focused || hover {
                Button(action: onFocus) {
                    Image(systemName: focused ? "stop.circle.fill" : "play.circle").font(Typography.cardBody)
                        .foregroundStyle(focused ? BrinkColors.violet : Palette.textSecondary)
                }
                .buttonStyle(.plain).padding(.top, Design.px(2))
            }
        }
        .background(RoundedRectangle(cornerRadius: Design.px(8), style: .continuous)
            .fill(focused ? BrinkColors.violet.opacity(0.12) : .clear).padding(.horizontal, -Design.px(8)))
        .opacity(busy ? 0.6 : 1)
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
        VStack(alignment: .leading, spacing: NotchLayout.sessionRowGap) {
            HStack(spacing: Design.px(10)) {
                Image(systemName: icon).font(Typography.cardBody).foregroundStyle(accent).frame(width: Design.px(20))
                TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Palette.textSecondary))
                    .textFieldStyle(.plain).font(Typography.cardBody).foregroundStyle(Palette.textPrimary)
                    .focused($focused)
                    .onChange(of: focused) { _, on in editing = on }
                    .onSubmit { if let first = suggestions.first, query != nil { pick(first) } else { action() } }
                Menu {
                    Button(L10n.t("No project")) { project = "" }
                    Divider()
                    ForEach(lists, id: \.self) { l in Button(l) { project = l } }
                } label: {
                    HStack(spacing: Design.px(4)) {
                        Image(systemName: project.isEmpty ? "folder" : "folder.fill").font(Typography.cardBody)
                        if !project.isEmpty { Text(project).font(Typography.cardBody).lineLimit(1).frame(maxWidth: Design.px(160)) }
                    }
                    .foregroundStyle(project.isEmpty ? Palette.textSecondary : accent)
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                Button(action: action) {
                    Image(systemName: icon == "timer" ? "play.circle.fill" : "return").font(Typography.cardBody).foregroundStyle(accent)
                        .frame(width: Design.px(24))
                }
                .buttonStyle(.plain)
            }
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { l in
                        Button { pick(l) } label: {
                            HStack(spacing: Design.px(8)) {
                                Image(systemName: "folder").font(Typography.cardBody).foregroundStyle(Palette.textSecondary)
                                Text(l).font(Typography.cardBody).foregroundStyle(Palette.textPrimary).lineLimit(1)
                                Spacer()
                            }
                            .frame(height: NotchLayout.cardBodyLineHeight)
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

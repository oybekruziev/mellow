import SwiftUI

/// Builds a whole plan in one go: how many tasks, how long each, the break between them,
/// a name and length for every task, and what happens when a task's time is up.
/// It edits a draft; nothing changes until Save Plan.
struct PlanEditorView: View {
    @Bindable var model: AppModel
    @State private var rows: [PlanItem]
    @State private var each: Int
    @FocusState private var focusedRow: PlanItem.ID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let maxTasks = 20
    private static let visibleRows = 5
    private static let rowHeight: CGFloat = 34

    init(model: AppModel) {
        self.model = model
        let pending = model.settings.pendingPlan
        let each = pending.first?.minutes ?? model.settings.focusMinutes
        _each = State(initialValue: each)
        _rows = State(initialValue: pending.isEmpty ? (0..<4).map { _ in PlanItem(title: "", minutes: each) } : pending)
    }
    private var settings: Settings { model.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            setup
            taskList
            flow
            footer
        }
        .font(.system(size: 13)).foregroundStyle(Palette.primary)
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 14)
        .frame(width: 300, alignment: .leading)
        .tint(Palette.focus)
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Plan your tasks").font(.system(size: 17, weight: .semibold)).tracking(-0.17)
                Text("Name each task and give it a time. Breaks go in between.")
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            ToolbarButton(icon: .close, title: "Cancel") { model.closePlanEditor() }
        }
    }

    private var setup: some View {
        VStack(spacing: 0) {
            SettingsRow("Tasks") {
                MinuteStepper(title: "Number of tasks", value: countBinding, range: 1...Self.maxTasks, unit: { "\($0)" })
            }
            Palette.separator.frame(height: 0.5)
            SettingsRow("All tasks") {
                MinuteStepper(title: "Length of every task", value: eachBinding, range: 5...120, step: 5)
            }
            Palette.separator.frame(height: 0.5)
            SettingsRow("Break between") {
                MinuteStepper(title: "Break length", value: $model.settings.breakMinutes, range: 1...60)
            }
        }
        .padding(.horizontal, 12)
        .modifier(SectionSurface())
    }

    private var taskList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($rows) { $row in
                        let number = (rows.firstIndex { $0.id == row.id } ?? 0) + 1
                        if number > 1 { Palette.separator.frame(height: 0.5).padding(.leading, 34) }
                        EditorRow(row: $row, number: number, focusedRow: $focusedRow) { focusRow(after: row.id) }
                            .id(row.id)
                    }
                }
            }
            .scrollIndicators(rows.count > Self.visibleRows ? .automatic : .never)
            .frame(height: CGFloat(min(rows.count, Self.visibleRows)) * Self.rowHeight
                   + CGFloat(max(0, min(rows.count, Self.visibleRows) - 1)) * 0.5)
            .modifier(SectionSurface())
            .onChange(of: rows.count) { old, new in
                guard new > old, let last = rows.last else { return }
                withAnimation(.snappy) { proxy.scrollTo(last.id, anchor: .bottom) }
            }
            .onChange(of: focusedRow) { _, id in
                if let id { withAnimation(.snappy) { proxy.scrollTo(id) } }
            }
        }
    }

    private var flow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("When a task's time is up")
            SegmentedPicker(options: [(true, "Start break"), (false, "Let me choose")],
                            selection: $model.settings.planAutoBreak, label: "When a task's time is up")
            Text(settings.planAutoBreak
                 ? "The break starts by itself. Tap Next Task when you're back."
                 : "Pick Break, Next or +\(SessionEngine.extendMinutes) min — for when a task needs more time.")
                .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 12)
        .modifier(SectionSurface())
        .animation(.snappy(duration: 0.2), value: settings.planAutoBreak)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.2), value: summary)
            HStack(spacing: 8) {
                PushButton(title: "Cancel", fill: true) { model.closePlanEditor() }
                PushButton(title: "Save Plan", icon: .check, tint: Palette.focus, fill: true) { save() }
            }
        }
    }

    // MARK: Draft editing

    private var countBinding: Binding<Int> {
        Binding {
            rows.count
        } set: { count in
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                while rows.count < count { rows.append(PlanItem(title: "", minutes: each)) }
                if rows.count > count { rows.removeLast(rows.count - count) }
            }
        }
    }
    private var eachBinding: Binding<Int> {
        Binding {
            each
        } set: { minutes in
            each = minutes
            for index in rows.indices { rows[index].minutes = minutes }
        }
    }
    private var summary: String {
        let focus = rows.reduce(0) { $0 + $1.minutes }
        let total = focus + max(0, rows.count - 1) * settings.breakMinutes
        let duration = total >= 60 ? "\(total / 60)h \(total % 60)m" : "\(total) min"
        let tasks = rows.count == 1 ? "1 task" : "\(rows.count) tasks"
        let breaks = rows.count > 1 ? " · \(rows.count - 1) \(rows.count == 2 ? "break" : "breaks")" : ""
        return "\(tasks)\(breaks) · \(duration) in all"
    }
    private func focusRow(after id: PlanItem.ID) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        if index + 1 < rows.count {
            focusedRow = rows[index + 1].id
        } else if rows.count < Self.maxTasks {
            // Return on the last row adds another task, so a list can be typed straight through.
            let row = PlanItem(title: "", minutes: each)
            withAnimation(.snappy(duration: 0.25)) { rows.append(row) }
            DispatchQueue.main.async { focusedRow = row.id }
        } else {
            focusedRow = nil
        }
    }
    private func save() {
        settings.setPendingPlan(rows)
        model.closePlanEditor()
    }
}

private struct EditorRow: View {
    @Binding var row: PlanItem
    let number: Int
    var focusedRow: FocusState<PlanItem.ID?>.Binding
    let onSubmit: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            Text("\(number)")
                .font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(Palette.secondary)
                .frame(width: 18, height: 18)
                .overlay { Circle().strokeBorder(Palette.secondary.opacity(0.5), lineWidth: 1.2) }
            TextField("Task \(number)", text: $row.title)
                .textFieldStyle(.plain).font(.system(size: 13))
                .focusEffectDisabled()
                .focused(focusedRow, equals: row.id)
                .onSubmit(onSubmit)
                .accessibilityLabel("Name of task \(number)")
            MinuteStepper(title: "Length of task \(number)", value: $row.minutes, range: 5...120, step: 5, unit: { "\($0)m" })
        }
        .padding(.leading, 8).padding(.trailing, 4)
        .frame(height: 34)
    }
}

import SwiftUI

struct PanelRootView: View {
    @Bindable var model: AppModel
    /// Size of the glass. It follows the content with a spring, so every change of shape —
    /// panel ↔ capsule, onboarding pages, a taller state — morphs instead of jumping.
    @State private var glassSize: CGSize = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if glassSize != .zero {
                GlassBackground().frame(width: glassSize.width, height: glassSize.height)
            }
            ZStack(alignment: .topTrailing) { content }
                // Sprites and the equalizer stop drawing while the panel is tucked away.
                .environment(\.panelAnimating, model.panelVisible && !model.dismissing)
                // Content never shows outside the glass while the glass is still growing or shrinking.
                .mask(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .frame(width: glassSize.width, height: glassSize.height)
                }
        }
        .scaleEffect(model.dismissing ? 0.2 : 1, anchor: .top)
        .opacity(model.dismissing ? 0 : 1)
        .blur(radius: model.dismissing && !reduceMotion ? 8 : 0)
        .padding(PanelController.shadowInset)
        // The window is a fixed canvas; the panel lives in its top-right corner.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .foregroundStyle(Palette.primary)
        .tint(Palette.focus)
        .onChange(of: model.settings.appearance) { model.applyAppearance() }
        .onChange(of: model.settings.keepOnTop) { model.panelController?.panel.level = model.settings.keepOnTop ? .floating : .normal }
        .onChange(of: model.settings.soundOn) { _, on in if on { model.playChime() } }
        .onChange(of: model.engine.phase) {
            model.syncMusic()
            // The editor only plans ahead; a session started from the menu bar closes it.
            if !model.canEditPlan { model.closePlanEditor() }
        }
        .onChange(of: model.settings.musicDuringFocus) { if model.engine.phase.isActive { model.syncMusic() } }
        .onChange(of: model.settings.musicVolume) { _, volume in model.music.volume = volume }
    }

    @ViewBuilder private var content: some View {
        if model.onboarding {
            measured(OnboardingView(model: model))
        } else if model.compact {
            measured(CompactView(model: model, glass: false))
        } else if model.planEditing {
            measured(PlanEditorView(model: model))
        } else {
            measured(PanelView(model: model, glass: false))
        }
    }

    private func measured(_ view: some View) -> some View {
        view
            .fixedSize()
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
                model.panelController?.contentSizeChanged(size)
                if glassSize == .zero || reduceMotion {
                    glassSize = size
                } else {
                    withAnimation(.spring(duration: 0.5, bounce: 0.14)) { glassSize = size }
                }
            }
            .transition(contentTransition)
    }

    /// New content blurs in slightly after the glass starts moving; old content leaves quickly.
    private var contentTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: AnyTransition(.blurReplace).combined(with: .scale(scale: 0.96, anchor: .topTrailing))
                .animation(.smooth(duration: 0.32).delay(0.08)),
            removal: AnyTransition(.blurReplace).animation(.easeOut(duration: 0.14)))
    }
}

struct PanelView: View {
    @Bindable var model: AppModel
    /// False inside the live panel, where PanelRootView draws one shared glass.
    var glass = true
    @FocusState private var taskFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var engine: SessionEngine { model.engine }
    private var phase: SessionPhase { engine.phase }
    private var tint: Color { phase.isBreak ? Palette.rest : Palette.focus }
    private var paused: Bool { phase.isActive && !phase.isRunning }

    var body: some View {
        VStack(alignment: .leading, spacing: phase == .ready ? 12 : 10) {
            header
            switch phase {
            case .ready: readyContent
            case .focusing, .onBreak: activeContent
            case .confirmEnd: confirmContent
            case .complete: completeContent
            case .breakOver: breakOverContent
            }
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 14)
        .frame(width: 300, alignment: .leading)
        .background { if glass { GlassBackground() } }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: phase)
        .onChange(of: model.taskFocusRequest) { taskFocused = true }
        .onAppear {
            guard model.pendingTaskFocus else { return }
            model.pendingTaskFocus = false
            DispatchQueue.main.async { taskFocused = true }
        }
    }

    // MARK: Header

    private var headerTitle: String {
        switch phase {
        case .ready: "Mellow"
        case .complete: "Session complete"
        case .onBreak: "Break"
        case .breakOver: "Break's over"
        case .focusing, .confirmEnd: engine.task
        }
    }
    private var status: String {
        switch phase {
        case .ready: "Ready to focus"
        case .complete: engine.task
        case .breakOver: nextTask.map { "Next: \($0.title)" } ?? "Ready when you are"
        case .onBreak(let running):
            running ? (nextTask.map { "Next: \($0.title)" } ?? "Step away for a bit") : "Paused · \(engine.formattedTime) left"
        case .focusing(let running), .confirmEnd(let running):
            running ? "Focusing · \(Int(engine.total / 60)) min\(planSuffix)" : "Paused · \(engine.formattedTime) left"
        }
    }
    private var nextTask: PlanItem? { model.settings.pendingPlan.first }
    private var planSuffix: String { engine.planPosition.map { " · \($0.index) of \($0.count)" } ?? "" }
    private func todayRow(justCompleted: Bool = false) -> some View {
        HStack(spacing: 4) {
            TodayRow(stats: engine.stats, justCompleted: justCompleted, short: model.music.isPlaying)
            MusicControl(music: model.music)
        }
    }
    private func submitTask() {
        let text = model.settings.lastTask.trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.settings.plan.isEmpty && !text.isEmpty {
            addToPlan()
        } else {
            taskFocused = false
            model.act(.startFocus)
        }
    }
    private func addToPlan() {
        withAnimation(.snappy(duration: 0.25)) {
            model.settings.addPlanItem(model.settings.lastTask, minutes: model.settings.focusMinutes)
            model.settings.lastTask = ""
        }
        taskFocused = true
    }

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Group {
                    if phase == .ready {
                        Image("mellow-logo").resizable().scaledToFit().frame(width: 40, height: 40)
                            .accessibilityLabel("Mellow")
                    } else {
                        CompanionView(type: model.settings.companion, phase: phase, progress: engine.progress, completedAt: engine.completedAt,
                                      interactive: true)
                    }
                }
                .contextMenu { CompanionMenu(model: model) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(headerTitle)
                        .font(.system(size: 13, weight: .semibold)).tracking(-0.065)
                        .lineLimit(1).truncationMode(.tail).help(headerTitle)
                    HStack(spacing: 5) {
                        statusMark
                        Text(status).lineLimit(1).truncationMode(.tail)
                    }
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary).help(status)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
            .allowsWindowActivationEvents(true)
            HStack(spacing: 0) {
                ToolbarButton(icon: .settings, title: "Settings") { model.openSettings() }
                    .popover(isPresented: $model.settingsOpen, arrowEdge: .bottom) { SettingsView(model: model) }
                ToolbarButton(icon: .compact, title: "Compact View") { model.toggleCompact() }
                ToolbarButton(icon: .hide, title: "Hide Panel — timer keeps running") { model.hidePanel() }
            }
        }
        .frame(height: phase == .ready ? 40 : 46)
    }
    @ViewBuilder private var statusMark: some View {
        if phase == .complete {
            IconImage(.check, size: 10).foregroundStyle(Palette.focus)
        } else if paused {
            IconImage(.pause, size: 10)
        } else if phase.isActive && phase.isBreak {
            IconImage(.cup, size: 10).foregroundStyle(tint)
        } else if phase.isActive || phase == .breakOver {
            Circle().fill(phase == .breakOver ? Palette.focus : tint).frame(width: 6, height: 6)
        }
    }

    // MARK: States

    private var readyContent: some View {
        Group {
            HStack(spacing: 4) {
                TextField("What are you working on?", text: $model.settings.lastTask, prompt: Text(""))
                    .labelsHidden()
                    .textFieldStyle(.plain).font(.system(size: 13)).tracking(-0.065)
                    .focusEffectDisabled()
                    .focused($taskFocused)
                    .onSubmit(submitTask)
                    .background(alignment: .leading) {
                        if model.settings.lastTask.isEmpty {
                            Text(model.settings.plan.isEmpty ? "What are you working on?" : "Add another task")
                                .font(.system(size: 13)).tracking(-0.065)
                                .foregroundStyle(Palette.secondary).allowsHitTesting(false).accessibilityHidden(true)
                        }
                    }
                Button { model.openPlanEditor() } label: {
                    IconImage(.list, size: 13).frame(width: 22, height: 22)
                }
                .buttonStyle(ToolbarStyle())
                .help("Plan Several Tasks — a name and time for each")
                .accessibilityLabel("Plan Several Tasks")
                Button(action: addToPlan) {
                    IconImage(.plus, size: 12).frame(width: 22, height: 22)
                }
                .buttonStyle(ToolbarStyle())
                .disabled(model.settings.lastTask.trimmingCharacters(in: .whitespaces).isEmpty)
                .help("Add to Plan — give each task its own time")
                .accessibilityLabel("Add to Plan")
            }
                .padding(.leading, 12).padding(.trailing, 4).frame(height: 30)
                .background(Palette.field, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(taskFocused ? Palette.focus : Palette.controlEdge, lineWidth: taskFocused ? 1.5 : 0.5)
                }
                .animation(.easeOut(duration: 0.15), value: taskFocused)
                .help(model.settings.lastTask.isEmpty ? "What are you working on?" : model.settings.lastTask)
            if !model.settings.plan.isEmpty {
                PlanList(settings: model.settings) { model.openPlanEditor() }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                planLink
            }
            HStack(spacing: 10) {
                timerText
                Spacer(minLength: 0)
                PushButton(title: "Start Focus", icon: .play, tint: Palette.focus, height: 36) {
                    if !model.settings.plan.isEmpty && !model.settings.lastTask.trimmingCharacters(in: .whitespaces).isEmpty { addToPlan() }
                    taskFocused = false
                    model.act(.startFocus)
                }
            }
            // With a plan, each task has its own length (± on the row), so the preset picker steps aside.
            if model.settings.pendingPlan.isEmpty {
                SegmentedPicker(options: AppModel.focusPresets.map { ($0, "\($0) min") },
                                selection: $model.settings.focusMinutes, label: "Focus length")
                    .transition(.opacity)
            }
            todayRow()
        }
    }

    /// A plan task can be marked done before its time is up.
    private var canFinishTask: Bool { !phase.isBreak && engine.currentPlanIndex != nil }
    private var activeContent: some View {
        Group {
            HStack(spacing: canFinishTask ? 8 : 10) {
                timerText
                Spacer(minLength: 0)
                if canFinishTask {
                    CircleButton(icon: .check, title: "Task Done", size: 34, tint: nil) { model.act(.finishTask) }
                }
                CircleButton(icon: .stop, title: phase.isBreak ? "End Break" : "End Session", size: 34, tint: nil) { model.endAction() }
                CircleButton(icon: phase.isRunning ? .pause : .play, title: phase.isRunning ? "Pause" : "Resume", size: 44, tint: tint) {
                    model.primaryAction()
                }
                .animation(.easeOut(duration: 0.15), value: phase.isRunning)
            }
            ProgressCapsule(value: engine.progress, tint: paused ? Palette.secondary : tint)
            todayRow()
        }
    }

    private var confirmContent: some View {
        Group {
            timerText(color: Palette.tertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("End this session?").font(.system(size: 13, weight: .semibold))
                Text("It won't grow a flower. Today's flowers stay.")
                    .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                PushButton(title: "Keep Going", tint: Palette.focus, fill: true) { model.act(.keepGoing) }
                PushButton(title: "End Session", fill: true) { model.act(.confirmEnd) }
            }
        }
    }

    private var completeContent: some View {
        let planTask = engine.currentPlanIndex != nil
        return Group {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.settings.companion.completionTitle).font(.system(size: 17, weight: .semibold)).tracking(-0.17)
                Text(planTask ? "Time's up for this task. Need more? Add \(SessionEngine.extendMinutes) minutes."
                              : model.settings.companion.completionDetail)
                    .font(.system(size: 13)).tracking(-0.065).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if planTask {
                // A plan task: a few more minutes, a break, or straight on to the next one.
                HStack(spacing: 8) {
                    PushButton(title: "+\(SessionEngine.extendMinutes) min", fill: true) { model.act(.extend) }
                    if nextTask != nil {
                        PushButton(title: "Break", tint: Palette.rest, fill: true) { model.act(.startBreak) }
                        PushButton(title: "Next", icon: .skip, tint: Palette.focus, fill: true) { model.act(.nextTask) }
                    } else {
                        PushButton(title: "Finish", fill: true) { model.act(.later) }
                        PushButton(title: "Break", tint: Palette.rest, fill: true) { model.act(.startBreak) }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    PushButton(title: "Later", fill: true) { model.act(.later) }
                    PushButton(title: "\(model.settings.breakMinutes)-min Break", icon: .cup, tint: Palette.rest, fill: true) {
                        model.act(.startBreak)
                    }
                }
            }
            todayRow(justCompleted: true)
        }
    }

    private var breakOverContent: some View {
        Group {
            HStack(spacing: 10) {
                timerText
                PushButton(title: nextTask == nil ? "New Session" : "Next Task", icon: .play, tint: Palette.focus) { model.act(.newSession) }
                Spacer(minLength: 0)
            }
            planLink
            todayRow()
        }
    }

    /// The way into the plan editor: "Plan several tasks", or "Edit plan" once there is one.
    private var planLink: some View {
        let editing = !model.settings.pendingPlan.isEmpty
        return Button { model.openPlanEditor() } label: {
            HStack(spacing: 6) {
                IconImage(.list, size: 13)
                Text(editing ? "Edit plan · \(model.settings.pendingPlan.count) left" : "Plan several tasks…")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Palette.focus)
            .padding(.horizontal, 4).frame(height: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .help("Plan several tasks — a name and time for each, breaks in between (⌘P)")
        .transition(.opacity)
    }

    private var timerText: some View { timerText(color: paused ? Palette.secondary : Palette.primary) }
    private func timerText(color: Color) -> some View {
        Text(engine.formattedTime)
            // Long times shrink, more so when a third button (Task Done) shares the row.
            .font(.system(size: engine.formattedTime.count > 5 ? (canFinishTask ? 31 : 36) : 46, weight: .semibold, design: .rounded))
            .monospacedDigit().tracking(-0.69)
            .foregroundStyle(color)
            .lineLimit(1).fixedSize()
            .frame(height: 50)
            .contentTransition(.numericText(countsDown: true))
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: engine.formattedTime)
            .accessibilityLabel(phase.isActive ? "\(engine.formattedTime) remaining" : "Focus length \(engine.formattedTime)")
    }
}

struct CompactView: View {
    @Bindable var model: AppModel
    var glass = true
    private var phase: SessionPhase { model.engine.phase }
    private var caption: String {
        switch phase {
        case .ready: "Ready"
        case .complete: "Complete"
        case .breakOver: "Break's over"
        case .onBreak(let running): running ? "Break" : "Paused"
        case .focusing(let running), .confirmEnd(let running): running ? "Focus" : "Paused"
        }
    }
    private var compactIcon: Icon {
        switch phase {
        case .focusing(true), .onBreak(true): .pause
        case .complete, .confirmEnd: .expand
        default: .play
        }
    }
    private var compactTitle: String {
        switch phase {
        case .ready: "Start Focus"
        case .focusing(true), .onBreak(true): "Pause"
        case .focusing(false), .onBreak(false): "Resume"
        case .confirmEnd, .complete: "Open Panel"
        case .breakOver: model.settings.pendingPlan.isEmpty ? "New Session" : "Next Task"
        }
    }
    var body: some View {
        let paused = phase.isActive && !phase.isRunning
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                CompanionView(type: model.settings.companion, phase: phase, progress: model.engine.progress,
                              completedAt: model.engine.completedAt, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.engine.formattedTime)
                        .font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .foregroundStyle(paused ? Palette.secondary : Palette.primary)
                    Text(caption).font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture { model.setCompact(false) }
            .simultaneousGesture(WindowDragGesture())
            .allowsWindowActivationEvents(true)
            .help("Open Panel")
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { model.setCompact(false) }
            CircleButton(icon: compactIcon, title: compactTitle,
                         size: 34, tint: phase.isBreak ? Palette.rest : Palette.focus) { model.compactAction() }
        }
        .padding(.leading, 8).padding(.trailing, 9)
        .frame(width: 168, height: 52)
        .background { if glass { GlassBackground() } }
        .contextMenu { CompanionMenu(model: model, compact: true) }
    }
}

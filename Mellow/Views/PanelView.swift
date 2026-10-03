import SwiftUI

struct PanelRootView: View {
    @Bindable var model: AppModel
    @Namespace private var glass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if model.compact {
                CompactView(model: model, glass: glass).transition(contentTransition)
            } else {
                PanelView(model: model, glass: glass).transition(contentTransition)
            }
        }
        .scaleEffect(model.dismissing ? 0.12 : 1, anchor: .top)
        .opacity(model.dismissing ? 0 : 1)
        .fixedSize(horizontal: true, vertical: true)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            model.panelController?.resize(contentSize: size)
        }
        .padding(PanelController.shadowInset)
        // The window can be larger than the content while it morphs; keep the content pinned top-right.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .foregroundStyle(Palette.primary)
        .tint(Palette.focus)
        .onChange(of: model.settings.appearance) { model.applyAppearance() }
        .onChange(of: model.settings.keepOnTop) { model.panelController?.panel.level = model.settings.keepOnTop ? .floating : .normal }
        .onChange(of: model.settings.soundOn) { _, on in if on { model.playChime() } }
        .onChange(of: model.engine.phase) { model.syncMusic() }
        .onChange(of: model.settings.musicDuringFocus) { model.syncMusic() }
        .onChange(of: model.settings.musicVolume) { _, volume in model.music.volume = volume }
    }
    private var contentTransition: AnyTransition {
        reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.2).delay(0.12)),
            removal: .opacity.animation(.easeIn(duration: 0.1)))
    }
}

struct PanelView: View {
    @Bindable var model: AppModel
    var glass: Namespace.ID? = nil
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
        .modifier(GlassSurface(namespace: glass))
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: phase.isBreak)
        .onChange(of: model.taskFocusRequest) { taskFocused = true }
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
            TodayRow(stats: engine.stats, justCompleted: justCompleted)
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
                        CompanionView(type: model.settings.companion, phase: phase, progress: engine.progress, completedAt: engine.completedAt)
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
                TextField("", text: $model.settings.lastTask)
                    .textFieldStyle(.plain).font(.system(size: 13)).tracking(-0.065)
                    .focusEffectDisabled()
                    .background(alignment: .leading) {
                        if model.settings.lastTask.isEmpty {
                            Text(model.settings.plan.isEmpty ? "What are you working on?" : "Add another task")
                                .font(.system(size: 13)).tracking(-0.065)
                                .foregroundStyle(Palette.secondary).allowsHitTesting(false).accessibilityHidden(true)
                        }
                    }
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
                .focused($taskFocused)
                .onSubmit(submitTask)
                .help(model.settings.lastTask.isEmpty ? "What are you working on?" : model.settings.lastTask)
                .accessibilityLabel("What are you working on?")
            if !model.settings.plan.isEmpty {
                PlanList(settings: model.settings)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            HStack(spacing: 10) {
                timerText
                Spacer(minLength: 0)
                PushButton(title: "Start Focus", icon: .play, tint: Palette.focus, height: 36) {
                    taskFocused = false
                    if !model.settings.plan.isEmpty && !model.settings.lastTask.trimmingCharacters(in: .whitespaces).isEmpty { addToPlan() }
                    model.act(.startFocus)
                }
            }
            SegmentedPicker(options: [15, 25, 45].map { ($0, "\($0) min") },
                            selection: $model.settings.focusMinutes, label: "Focus length")
            todayRow()
        }
    }

    private var activeContent: some View {
        Group {
            HStack(spacing: 10) {
                timerText
                Spacer(minLength: 0)
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
        Group {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.settings.companion.completionTitle).font(.system(size: 17, weight: .semibold)).tracking(-0.17)
                Text(model.settings.companion.completionDetail)
                    .font(.system(size: 13)).tracking(-0.065).foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                PushButton(title: "Later", fill: true) { model.act(.later) }
                PushButton(title: "\(model.settings.breakMinutes)-min Break", icon: .cup, tint: Palette.rest, fill: true) {
                    model.act(.startBreak)
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
            todayRow()
        }
    }

    private var timerText: some View { timerText(color: paused ? Palette.secondary : Palette.primary) }
    private func timerText(color: Color) -> some View {
        Text(engine.formattedTime)
            .font(.system(size: engine.formattedTime.count > 5 ? 36 : 46, weight: .semibold, design: .rounded))
            .monospacedDigit().tracking(-0.69)
            .foregroundStyle(color)
            .lineLimit(1).fixedSize()
            .frame(height: 50)
            .contentTransition(.numericText(countsDown: true))
            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: engine.formattedTime)
            .accessibilityLabel("\(engine.formattedTime) remaining")
    }
}

struct CompactView: View {
    @Bindable var model: AppModel
    var glass: Namespace.ID? = nil
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
                .lineLimit(1)
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
        .modifier(GlassSurface(namespace: glass))
        .contextMenu { CompanionMenu(model: model, compact: true) }
    }
}

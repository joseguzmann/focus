import SwiftUI

enum Theme {
    static let focus = Color(red: 0.91, green: 0.47, blue: 0.42)
    static let rest = Color(red: 0.36, green: 0.68, blue: 0.56)
    static let track = Color.secondary.opacity(0.45)

    static func color(for phase: Phase) -> Color {
        phase == .focus ? focus : rest
    }
}

enum Screen {
    case timer, tasks, settings
}

struct PopoverView: View {
    @State private var screen: Screen = .timer

    var body: some View {
        Group {
            switch screen {
            case .timer: TimerScreen(screen: $screen)
            case .tasks: TasksScreen(screen: $screen)
            case .settings: SettingsScreen(screen: $screen)
            }
        }
        .frame(width: 280, height: 380)
    }
}

// MARK: - Temporizador

struct TimerScreen: View {
    @Environment(FocusTimer.self) private var timer
    @Binding var screen: Screen

    var body: some View {
        let color = Theme.color(for: timer.phase)
        VStack(spacing: 0) {
            header
                .frame(height: 48)
                .padding(.horizontal, 14)

            Divider()

            ZStack(alignment: .topTrailing) {
                RingView(fraction: timer.remainingFraction, color: color) {
                    VStack(spacing: 10) {
                        Text(timer.timeString)
                            .font(.system(size: 50, weight: .thin))
                            .monospacedDigit()
                            .foregroundStyle(color)
                        Button(action: timer.toggle) {
                            Image(systemName: timer.state == .running ? "pause" : "play")
                                .font(.system(size: 30, weight: .ultraLight))
                                .foregroundStyle(color)
                                .frame(width: 44, height: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.space, modifiers: [])
                        .help(timer.state == .running ? "Pausar" : "Iniciar")
                    }
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 24)

                if timer.hasProgress {
                    Button(action: timer.stop) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(14)
                    .help("Detener y reiniciar la fase")
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            footer
                .frame(height: 44)
                .padding(.horizontal, 14)
        }
    }

    @ViewBuilder private var header: some View {
        if timer.phase == .focus {
            HStack(spacing: 10) {
                Button {
                    if let id = timer.selectedTaskID { timer.toggleDone(id) }
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(timer.selectedTask == nil ? Color.secondary : Theme.rest)
                }
                .buttonStyle(.plain)
                .disabled(timer.selectedTask == nil)
                .help("Marcar la tarea como terminada")

                Menu {
                    let pending = timer.tasks.filter { !$0.done }
                    ForEach(pending) { task in
                        Button {
                            timer.selectedTaskID = task.id
                        } label: {
                            if task.id == timer.selectedTaskID {
                                Label(task.title, systemImage: "checkmark")
                            } else {
                                Text(task.title)
                            }
                        }
                    }
                    if !pending.isEmpty { Divider() }
                    Button("Nueva tarea…") { screen = .tasks }
                    if timer.selectedTaskID != nil {
                        Button("Sin tarea") { timer.selectedTaskID = nil }
                    }
                } label: {
                    HStack {
                        Spacer(minLength: 0)
                        Text(timer.selectedTask?.title ?? "Elegí una tarea")
                            .lineLimit(1)
                            .foregroundStyle(timer.selectedTask == nil ? .secondary : .primary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 15))
                    .contentShape(Rectangle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
            }
        } else {
            HStack {
                Image(systemName: "cup.and.saucer")
                    .foregroundStyle(Theme.rest)
                Text(timer.phase.title)
                    .font(.system(size: 15))
                Spacer()
                Button("Saltar", action: timer.skip)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button { screen = .tasks } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Tareas")

            Spacer()

            (Text("Hoy ").foregroundStyle(.secondary)
                + Text("\(timer.todayCount)/\(timer.prefs.dailyGoal)").foregroundStyle(Theme.focus))
                .font(.system(size: 15))
                .help("Pomodoros completados hoy / meta diaria")

            Spacer()

            Menu {
                Button("Preferencias…") { screen = .settings }
                Button("Saltar a la siguiente fase", action: timer.skip)
                Button("Reiniciar ciclo", action: timer.resetCycle)
                Divider()
                Button("Salir de Focus") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.visible)
            .fixedSize()
        }
    }
}

struct RingView<Content: View>: View {
    var fraction: Double
    var color: Color
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = side / 2 - 8
            // 0 = las 12; avanza en sentido horario con el tiempo restante.
            let angle = Angle.degrees(-90 + 360 * fraction).radians

            ZStack {
                Circle()
                    .stroke(Theme.track, lineWidth: 2)
                    .frame(width: radius * 2, height: radius * 2)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: radius * 2, height: radius * 2)
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(Circle().stroke(color, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .offset(x: radius * cos(angle), y: radius * sin(angle))
                content
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.linear(duration: 0.5), value: fraction)
        }
    }
}

// MARK: - Tareas

struct TasksScreen: View {
    @Environment(FocusTimer.self) private var timer
    @Binding var screen: Screen
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SubHeader(title: "Tareas", screen: $screen)
            Divider()

            if timer.tasks.isEmpty {
                Spacer()
                Text("Todavía no hay tareas.\nEscribí una abajo.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(timer.tasks) { task in
                            TaskRow(task: task)
                        }
                    }
                }
            }

            Divider()
            HStack(spacing: 8) {
                TextField("Nueva tarea", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onSubmit(add)
                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(draft.isEmpty ? Color.secondary : Theme.focus)
                }
                .buttonStyle(.plain)
                .disabled(draft.isEmpty)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
        }
        .onAppear { fieldFocused = true }
    }

    private func add() {
        timer.addTask(draft)
        draft = ""
    }
}

struct TaskRow: View {
    @Environment(FocusTimer.self) private var timer
    let task: FocusTask
    @State private var hovering = false

    var body: some View {
        let selected = task.id == timer.selectedTaskID
        HStack(spacing: 10) {
            Button { timer.toggleDone(task.id) } label: {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(task.done ? Theme.rest : .secondary)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .lineLimit(1)
                .strikethrough(task.done)
                .foregroundStyle(task.done ? .secondary : .primary)
                .fontWeight(selected ? .semibold : .regular)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hovering {
                Button { timer.deleteTask(task.id) } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Borrar")
            } else if task.pomodoros > 0 {
                Text("\(task.pomodoros)")
                    .monospacedDigit()
                    .foregroundStyle(Theme.focus)
                    .help("Pomodoros dedicados")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 34)
        .background(selected ? Theme.focus.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if !task.done { timer.selectedTaskID = task.id }
        }
        .onHover { hovering = $0 }
    }
}

// MARK: - Preferencias

struct SettingsScreen: View {
    @Environment(FocusTimer.self) private var timer
    @Binding var screen: Screen

    var body: some View {
        @Bindable var timer = timer
        VStack(spacing: 0) {
            SubHeader(title: "Preferencias", screen: $screen)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Group {
                        Stepper("Enfoque: \(timer.prefs.focusMinutes) min",
                                value: $timer.prefs.focusMinutes, in: 1...120)
                        Stepper("Descanso corto: \(timer.prefs.shortBreakMinutes) min",
                                value: $timer.prefs.shortBreakMinutes, in: 1...60)
                        Stepper("Descanso largo: \(timer.prefs.longBreakMinutes) min",
                                value: $timer.prefs.longBreakMinutes, in: 1...90)
                        Stepper("Descanso largo cada \(timer.prefs.longBreakEvery)",
                                value: $timer.prefs.longBreakEvery, in: 2...12)
                        Stepper("Meta diaria: \(timer.prefs.dailyGoal)",
                                value: $timer.prefs.dailyGoal, in: 1...30)
                    }
                    Divider()
                    Toggle("Iniciar descansos solos", isOn: $timer.prefs.autoStartBreaks)
                    Toggle("Iniciar enfoque solo", isOn: $timer.prefs.autoStartFocus)
                    Toggle("Sonido al terminar", isOn: $timer.prefs.playSound)
                    Toggle("Tiempo en la barra de menú", isOn: $timer.prefs.showTimeInMenuBar)
                    LaunchAtLoginToggle()
                    if timer.tasks.contains(where: \.done) {
                        Divider()
                        Button("Borrar tareas terminadas", action: timer.clearCompletedTasks)
                    }
                }
                .toggleStyle(.checkbox)
                .padding(14)
            }
        }
    }
}

struct SubHeader: View {
    let title: String
    @Binding var screen: Screen

    var body: some View {
        ZStack {
            Text(title).font(.system(size: 15, weight: .medium))
            HStack {
                Button { screen = .timer } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                Spacer()
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 8)
    }
}

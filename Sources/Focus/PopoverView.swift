import SwiftUI

enum Theme {
    static let focus = Color(red: 0.91, green: 0.42, blue: 0.36)
    static let rest = Color(red: 0.30, green: 0.66, blue: 0.56)

    static func color(for phase: Phase) -> Color {
        phase == .focus ? focus : rest
    }
}

enum TagColor {
    static let palette: [Color] = [
        Color(red: 0.36, green: 0.55, blue: 0.93), // azul
        Color(red: 0.62, green: 0.45, blue: 0.90), // violeta
        Color(red: 0.95, green: 0.62, blue: 0.25), // naranja
        Color(red: 0.30, green: 0.70, blue: 0.50), // verde
        Color(red: 0.90, green: 0.40, blue: 0.62), // rosa
        Color(red: 0.25, green: 0.68, blue: 0.80), // celeste
        Color(red: 0.75, green: 0.62, blue: 0.30), // ocre
    ]

    static func color(_ tag: Tag?) -> Color {
        guard let tag else { return .secondary }
        return palette[tag.colorIndex % palette.count]
    }
}

enum Screen: Hashable {
    case timer, tags, settings
}

struct PopoverView: View {
    @State private var screen: Screen = .timer

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $screen) {
                Text("Timer").tag(Screen.timer)
                Text("Etiquetas").tag(Screen.tags)
                Text("Ajustes").tag(Screen.settings)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            Divider()

            Group {
                switch screen {
                case .timer: TimerScreen(screen: $screen)
                case .tags: TagsScreen()
                case .settings: SettingsScreen()
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 300, height: 400)
    }
}

// MARK: - Timer

struct TimerScreen: View {
    @Environment(FocusTimer.self) private var timer
    @Binding var screen: Screen

    var body: some View {
        let color = Theme.color(for: timer.phase)
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: timer.remainingFraction)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: timer.remainingFraction)
                VStack(spacing: 4) {
                    Text(timer.phase.title.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(color)
                    Text(timer.timeString)
                        .font(.system(size: 46, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    if timer.state == .paused {
                        Text("En pausa")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 190, height: 190)

            Spacer(minLength: 12)

            if timer.phase == .focus {
                TagPicker(screen: $screen)
            } else {
                Text("Respirá, estirate, tomá agua.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(height: 26)
            }

            Spacer(minLength: 12)

            HStack(spacing: 14) {
                RoundIconButton(systemName: "arrow.counterclockwise", help: "Reiniciar") {
                    timer.reset()
                }
                .opacity(timer.hasProgress ? 1 : 0.35)
                .disabled(!timer.hasProgress)

                Button(action: timer.toggle) {
                    Label(primaryTitle, systemImage: timer.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 130, height: 38)
                        .background(Capsule().fill(color))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])

                RoundIconButton(systemName: "forward.end", help: timer.phase == .focus ? "Saltar al descanso" : "Saltar el descanso") {
                    timer.skip()
                }
            }

            Spacer(minLength: 14)
            Divider()

            HStack(spacing: 4) {
                Text("Hoy")
                    .foregroundStyle(.secondary)
                Text("\(timer.todayPomodoros.count) pomodoros")
                    .fontWeight(.medium)
                let minutes = timer.todayPomodoros.reduce(0) { $0 + $1.minutes }
                if minutes > 0 {
                    Text("· \(Self.duration(minutes))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 12))
            .frame(height: 36)
        }
    }

    private var primaryTitle: String {
        switch timer.state {
        case .idle: "Empezar"
        case .running: "Pausar"
        case .paused: "Seguir"
        }
    }

    static func duration(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : "\(minutes / 60) h \(minutes % 60) min"
    }
}

struct TagPicker: View {
    @Environment(FocusTimer.self) private var timer
    @Binding var screen: Screen

    var body: some View {
        Menu {
            ForEach(timer.tags) { tag in
                Button {
                    timer.selectedTagID = tag.id
                } label: {
                    if tag.id == timer.selectedTagID {
                        Label(tag.name, systemImage: "checkmark")
                    } else {
                        Text(tag.name)
                    }
                }
            }
            if !timer.tags.isEmpty {
                Button("Sin etiqueta") { timer.selectedTagID = nil }
                Divider()
            }
            Button("Administrar etiquetas…") { screen = .tags }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(TagColor.color(timer.selectedTag))
                    .frame(width: 8, height: 8)
                Text(timer.selectedTag?.name ?? "Sin etiqueta")
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(Capsule().fill(TagColor.color(timer.selectedTag).opacity(0.14)))
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("¿A qué pertenece este pomodoro?")
    }
}

struct RoundIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.secondary.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Etiquetas

struct TagsScreen: View {
    @Environment(FocusTimer.self) private var timer
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Etiqueta")
                Spacer()
                Text("Hoy").frame(width: 40, alignment: .trailing)
                Text("Total").frame(width: 44, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(timer.tags) { tag in
                        TagRow(tag: tag)
                    }
                    if timer.count(for: nil) > 0 || timer.tags.isEmpty {
                        TagRow(tag: nil)
                    }
                }
            }

            Divider()
            HStack(spacing: 8) {
                TextField("Nueva etiqueta (proyecto, tema…)", text: $draft)
                    .textFieldStyle(.plain)
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
    }

    private func add() {
        timer.addTag(draft)
        draft = ""
    }
}

struct TagRow: View {
    @Environment(FocusTimer.self) private var timer
    let tag: Tag?
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(TagColor.color(tag))
                .frame(width: 8, height: 8)
            Text(tag?.name ?? "Sin etiqueta")
                .lineLimit(1)
                .foregroundStyle(tag == nil ? .secondary : .primary)
            Spacer()
            if hovering, let tag {
                Button { timer.deleteTag(tag.id) } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Borrar etiqueta (sus pomodoros quedan sin etiqueta)")
            }
            Text("\(timer.count(for: tag?.id, todayOnly: true))")
                .frame(width: 40, alignment: .trailing)
            Text("\(timer.count(for: tag?.id))")
                .fontWeight(.medium)
                .frame(width: 44, alignment: .trailing)
        }
        .monospacedDigit()
        .font(.system(size: 13))
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(hovering ? Color.secondary.opacity(0.08) : Color.clear)
        .onHover { hovering = $0 }
    }
}

// MARK: - Ajustes

struct SettingsScreen: View {
    @Environment(FocusTimer.self) private var timer

    var body: some View {
        @Bindable var timer = timer
        VStack(alignment: .leading, spacing: 14) {
            Stepper(value: $timer.prefs.focusMinutes, in: 1...120) {
                SettingLabel(title: "Pomodoro", value: "\(timer.prefs.focusMinutes) min", color: Theme.focus)
            }
            Stepper(value: $timer.prefs.breakMinutes, in: 1...60) {
                SettingLabel(title: "Descanso", value: "\(timer.prefs.breakMinutes) min", color: Theme.rest)
            }
            Divider()
            Toggle("Sonido al terminar", isOn: $timer.prefs.playSound)
                .toggleStyle(.checkbox)
            if timer.hasProgress {
                Text("Los cambios de duración se aplican al reiniciar o en la próxima fase.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack {
                Spacer()
                Button("Salir de Focus") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
    }
}

struct SettingLabel: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

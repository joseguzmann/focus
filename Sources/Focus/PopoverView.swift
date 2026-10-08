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
        Color(red: 0.36, green: 0.55, blue: 0.93), // blue
        Color(red: 0.62, green: 0.45, blue: 0.90), // violet
        Color(red: 0.95, green: 0.62, blue: 0.25), // orange
        Color(red: 0.30, green: 0.70, blue: 0.50), // green
        Color(red: 0.90, green: 0.40, blue: 0.62), // pink
        Color(red: 0.25, green: 0.68, blue: 0.80), // sky
        Color(red: 0.75, green: 0.62, blue: 0.30), // ochre
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
                Text("Tags").tag(Screen.tags)
                Text("Settings").tag(Screen.settings)
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
        .frame(width: 300, height: 440)
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
                        Text("Paused")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 190, height: 190)

            Spacer(minLength: 12)

            if timer.phase == .focus {
                VStack(spacing: 8) {
                    TagPicker(screen: $screen)
                    NoiseControl()
                }
            } else {
                Text("Breathe, stretch, drink some water.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(height: 26)
            }

            Spacer(minLength: 12)

            HStack(spacing: 14) {
                RoundIconButton(systemName: "arrow.counterclockwise", help: "Restart") {
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

                RoundIconButton(systemName: "forward.end", help: timer.phase == .focus ? "Skip to break" : "Skip break") {
                    timer.skip()
                }
            }

            Spacer(minLength: 14)
            Divider()

            HStack(spacing: 4) {
                Text("Today")
                    .foregroundStyle(.secondary)
                Text(Self.pomodoros(timer.todayPomodoros.count))
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
        case .idle: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        }
    }

    static func pomodoros(_ count: Int) -> String {
        count == 1 ? "1 pomodoro" : "\(count) pomodoros"
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
                Button("No tag") { timer.selectedTagID = nil }
                Divider()
            }
            Button("Manage tags…") { screen = .tags }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(TagColor.color(timer.selectedTag))
                    .frame(width: 8, height: 8)
                Text(timer.selectedTag?.name ?? "No tag")
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
        .help("What is this pomodoro for?")
    }
}

struct NoiseControl: View {
    @Environment(FocusTimer.self) private var timer
    @State private var hovering = false
    @State private var showVolume = false

    var body: some View {
        @Bindable var timer = timer
        let on = timer.prefs.noiseEnabled
        VStack(spacing: 0) {
            header
            if showVolume {
                // Color.clear takes the header's width, so the slider never widens the control.
                Color.clear
                    .frame(height: 30)
                    .overlay {
                        HStack(spacing: 8) {
                            Image(systemName: "speaker.fill")
                            Slider(value: $timer.prefs.noiseLevel, in: 0...1)
                                .controlSize(.mini)
                                .tint(Theme.focus)
                            Image(systemName: "speaker.wave.3.fill")
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 4)
                    }
                    .transition(.opacity)
            }
        }
        .font(.system(size: 13))
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(on ? Theme.focus.opacity(0.12) : Color.secondary.opacity(0.1))
        )
        // Opened by hovering the speaker; stays open while the pointer is anywhere on the control.
        .onHover { inside in
            hovering = inside
            guard !inside else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                guard !hovering else { return }
                withAnimation(.easeInOut(duration: 0.15)) { showVolume = false }
            }
        }
    }

    private var header: some View {
        let on = timer.prefs.noiseEnabled
        return HStack(spacing: 0) {
            Menu {
                ForEach(NoiseType.allCases) { type in
                    Button {
                        timer.prefs.noise = type
                    } label: {
                        if type == timer.prefs.noise {
                            Label(type.title, systemImage: "checkmark")
                        } else {
                            Text(type.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative, isActive: timer.isNoisePlaying)
                        .foregroundStyle(on ? Theme.focus : .secondary)
                    Text(timer.prefs.noise.title)
                        .foregroundStyle(on ? .primary : .secondary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 26)
                .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Noise type")

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 8)

            // Clicking mutes/unmutes (the pomodoro keeps running); hovering unfolds the volume below.
            Button { timer.prefs.noiseEnabled.toggle() } label: {
                Image(systemName: speakerSymbol)
                    .foregroundStyle(on ? Theme.focus : .secondary)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(on ? "Mute noise (the pomodoro keeps running)" : "Unmute noise")
            .onHover { inside in
                if inside { withAnimation(.easeInOut(duration: 0.15)) { showVolume = true } }
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
    }

    private var speakerSymbol: String {
        guard timer.prefs.noiseEnabled else { return "speaker.slash" }
        let volume = timer.prefs.noiseLevel
        return volume < 0.34 ? "speaker.wave.1" : volume < 0.67 ? "speaker.wave.2" : "speaker.wave.3"
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

// MARK: - Tags

struct TagsScreen: View {
    @Environment(FocusTimer.self) private var timer
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tag")
                Spacer()
                Text("Today").frame(width: 40, alignment: .trailing)
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
                TextField("New tag (project, topic…)", text: $draft)
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
            Text(tag?.name ?? "No tag")
                .lineLimit(1)
                .foregroundStyle(tag == nil ? .secondary : .primary)
            Spacer()
            if hovering, let tag {
                Button { timer.deleteTag(tag.id) } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete tag (its pomodoros become untagged)")
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

// MARK: - Settings

struct SettingsScreen: View {
    @Environment(FocusTimer.self) private var timer

    var body: some View {
        @Bindable var timer = timer
        VStack(alignment: .leading, spacing: 14) {
            MinutesField(title: "Pomodoro", color: Theme.focus,
                         value: $timer.prefs.focusMinutes, range: 1...120)
            MinutesField(title: "Break", color: Theme.rest,
                         value: $timer.prefs.breakMinutes, range: 1...60)
            Divider()
            Toggle("Play sound when done", isOn: $timer.prefs.playSound)
                .toggleStyle(.checkbox)
            if timer.hasProgress {
                Text("Duration changes apply on restart or in the next phase.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack {
                Spacer()
                Button("Quit Focus") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .padding(16)
    }
}

/// Minutes you can type directly (Return or clicking away applies them), nudge with the
/// arrow keys, or step with the stepper. Out-of-range values are clamped.
struct MinutesField: View {
    let title: String
    let color: Color
    @Binding var value: Int
    let range: ClosedRange<Int>
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
            Spacer()
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 46)
                .focused($focused)
                .onSubmit(commit)
                .onChange(of: focused) { _, isFocused in
                    if !isFocused { commit() }
                }
                .onKeyPress(.upArrow) { step(1) }
                .onKeyPress(.downArrow) { step(-1) }
            Text("min")
                .foregroundStyle(.secondary)
            Stepper("", value: $value, in: range)
                .labelsHidden()
        }
        .onAppear { text = "\(value)" }
        .onChange(of: value) { _, newValue in text = "\(newValue)" }
    }

    private func commit() {
        if let typed = Int(text.trimmingCharacters(in: .whitespaces)) {
            value = min(max(typed, range.lowerBound), range.upperBound)
        }
        text = "\(value)"
    }

    private func step(_ delta: Int) -> KeyPress.Result {
        commit()
        value = min(max(value + delta, range.lowerBound), range.upperBound)
        return .handled
    }
}

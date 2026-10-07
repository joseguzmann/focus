import ServiceManagement
import SwiftUI

/// Abrir al iniciar sesión. Sólo funciona con la app instalada como .app (idealmente en /Applications).
struct LaunchAtLoginToggle: View {
    @State private var enabled = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Abrir al iniciar sesión", isOn: Binding(
                get: { enabled },
                set: { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        error = nil
                    } catch {
                        self.error = "No se pudo: instalá la app en /Applications."
                    }
                    enabled = SMAppService.mainApp.status == .enabled
                }
            ))
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

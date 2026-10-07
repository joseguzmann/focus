# Focus

Temporizador Pomodoro para la barra de menú de macOS.

- Ícono en la barra superior; mientras corre muestra el tiempo restante y el aro del ícono se va vaciando.
- **Timer**: enfoque → descanso (el descanso arranca solo; el siguiente pomodoro lo iniciás vos). Empezar/pausar también con la barra espaciadora.
- **Etiquetas**: cada pomodoro pertenece a una etiqueta (proyecto, tema…). Se crean y borran desde la app, y se ve cuántos pomodoros lleva cada una hoy y en total.
- **Ajustes**: duración del pomodoro y del descanso, sonido al terminar.
- Notificación al terminar cada fase. Sin ícono en el Dock.
- Todo se guarda en `UserDefaults` local; nada sale de la máquina.

## Requisitos

macOS 14 o superior y Swift 5.10+ (Xcode o Command Line Tools).

## Compilar e instalar

```bash
./scripts/build-app.sh            # arma build/Focus.app
./scripts/build-app.sh --install  # además la copia a /Applications y la abre
```

Si Xcode está instalado pero sin la licencia aceptada, los scripts usan las Command Line Tools solos.

Para desarrollar sin armar el `.app`: `swift run` (ahí no hay notificaciones, porque requieren bundle id).

## Ícono

`Resources/AppIcon.icns` se genera con `./scripts/make-icon.sh` a partir de `scripts/make-icon.swift`.

## Estructura

| Archivo | Qué tiene |
| --- | --- |
| `Sources/Focus/FocusApp.swift` | Punto de entrada, `MenuBarExtra` e ícono de la barra |
| `Sources/Focus/FocusTimer.swift` | Estado: temporizador, etiquetas, pomodoros completados, notificaciones |
| `Sources/Focus/PopoverView.swift` | Vistas: Timer, Etiquetas, Ajustes |
